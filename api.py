import sqlite3
import json
import os
import re
import secrets
import threading
import time
from datetime import datetime, timedelta
from difflib import SequenceMatcher
from functools import wraps
from pathlib import Path
from flask import Flask, abort, g, jsonify, request, send_file
from flask_cors import CORS
from werkzeug.security import check_password_hash, generate_password_hash
import httpx
from google import genai
from google.genai import types

app = Flask(__name__)
CORS(app)

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "datapre" / "nihon_assistant_data.db"
ANNO_DIR = BASE_DIR / "datapre" / "grammar_annotate"


def load_local_env_file(path: Path) -> None:
    if not path.exists() or not path.is_file():
        return

    try:
        content = path.read_text(encoding="utf-8")
    except OSError:
        return

    for raw_line in content.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key or key in os.environ:
            continue

        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]

        os.environ[key] = value


def load_local_env() -> None:
    for candidate in (BASE_DIR / ".env", BASE_DIR / ".env.local"):
        load_local_env_file(candidate)


load_local_env()

GENAI_MODEL = os.getenv("GENAI_MODEL", "gemini-2.5-flash")
GENAI_API_VERSION = os.getenv("GENAI_API_VERSION", "v1beta")
GENAI_SSL_VERIFY = os.getenv("GENAI_SSL_VERIFY", "true").strip().lower() not in {"0", "false", "no", "off"}
GENAI_HTTP_PROXY = (
    os.getenv("GENAI_HTTP_PROXY")
    or os.getenv("HTTP_PROXY")
    or os.getenv("HTTPS_PROXY")
    or ""
).strip() or None

GRAMMAR_SEARCH_CACHE_TTL_SECONDS = int(os.getenv("GRAMMAR_SEARCH_CACHE_TTL_SECONDS", "900"))
GRAMMAR_SEARCH_CACHE_MAX_SIZE = int(os.getenv("GRAMMAR_SEARCH_CACHE_MAX_SIZE", "300"))
GRAMMAR_SEARCH_CACHE: dict[str, dict] = {}
GRAMMAR_SEARCH_CACHE_LOCK = threading.Lock()


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    nickname TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);
CREATE TABLE IF NOT EXISTS sessions (
    token TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    expires_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS user_answer_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    element_type TEXT NOT NULL,
    element_id INTEGER NOT NULL,
    chapter INTEGER,
    correct INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);
CREATE TABLE IF NOT EXISTS user_element_mastery (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    element_type TEXT NOT NULL,
    element_id INTEGER NOT NULL,
    mastery REAL NOT NULL DEFAULT 50,
    correct_count INTEGER NOT NULL DEFAULT 0,
    wrong_count INTEGER NOT NULL DEFAULT 0,
    total_attempts INTEGER NOT NULL DEFAULT 0,
    streak INTEGER NOT NULL DEFAULT 0,
    last_reviewed_at TEXT,
    next_review_at TEXT,
    UNIQUE(user_id, element_type, element_id)
);
CREATE TABLE IF NOT EXISTS user_review_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    element_type TEXT NOT NULL,
    element_id INTEGER NOT NULL,
    source TEXT NOT NULL DEFAULT 'wrong',
    priority REAL NOT NULL DEFAULT 0,
    due_at TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_answer_log_user ON user_answer_log(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_mastery_user ON user_element_mastery(user_id);
CREATE INDEX IF NOT EXISTS idx_review_queue_user ON user_review_queue(user_id, status);
"""


def ensure_schema() -> None:
    """Create auth / learning-behavior tables idempotently at startup."""
    conn = get_db()
    try:
        conn.executescript(SCHEMA_SQL)
        conn.commit()
    finally:
        conn.close()


def table_exists(conn, table_name: str) -> bool:
    cur = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
        (table_name,),
    )
    return cur.fetchone() is not None


def column_exists(conn, table_name: str, col_name: str) -> bool:
    cur = conn.execute(f"PRAGMA table_info({table_name})")
    return any(row[1] == col_name for row in cur.fetchall())


def pick_table(conn, primary: str, fallback: str | None = None) -> str:
    if table_exists(conn, primary):
        return primary
    if fallback and table_exists(conn, fallback):
        return fallback
    return primary


def sentence_cols(conn):
    table = "sentence"
    jp_col = "jp_sentence" if column_exists(conn, table, "jp_sentence") else "japanese"
    seg_col = "jp_sentence_seg" if column_exists(conn, table, "jp_sentence_seg") else "japanese_segmented"
    group_col = "group_id" if column_exists(conn, table, "group_id") else "grid"
    return jp_col, seg_col, group_col


def sentence_meta_select(conn, alias: str = "s"):
    jp_col, _, group_col = sentence_cols(conn)
    has_group_type = column_exists(conn, "sentence", "group_type")
    has_group_title = column_exists(conn, "sentence", "group_title")
    has_speaker = column_exists(conn, "sentence", "speaker")
    has_content = column_exists(conn, "sentence", "content")
    has_sentence_group_table = table_exists(conn, "sentence_group")
    sentence_group_key_col = (
        "group_id"
        if has_sentence_group_table and column_exists(conn, "sentence_group", "group_id")
        else "id"
    )
    has_sentence_group_title = has_sentence_group_table and column_exists(conn, "sentence_group", "title")
    has_sentence_group_type = has_sentence_group_table and column_exists(conn, "sentence_group", "type")

    speaker_case = (
        f"CASE "
        f"WHEN INSTR({alias}.{jp_col}, ':') > 0 THEN TRIM(SUBSTR({alias}.{jp_col}, 1, INSTR({alias}.{jp_col}, ':') - 1)) "
        f"WHEN INSTR({alias}.{jp_col}, '：') > 0 THEN TRIM(SUBSTR({alias}.{jp_col}, 1, INSTR({alias}.{jp_col}, '：') - 1)) "
        f"ELSE '' END"
    )
    content_case = (
        f"CASE "
        f"WHEN INSTR({alias}.{jp_col}, ':') > 0 THEN TRIM(SUBSTR({alias}.{jp_col}, INSTR({alias}.{jp_col}, ':') + 1)) "
        f"WHEN INSTR({alias}.{jp_col}, '：') > 0 THEN TRIM(SUBSTR({alias}.{jp_col}, INSTR({alias}.{jp_col}, '：') + 1)) "
        f"ELSE {alias}.{jp_col} END"
    )
    inferred_type = (
        f"CASE "
        f"WHEN INSTR({alias}.{jp_col}, ':') > 0 OR INSTR({alias}.{jp_col}, '：') > 0 THEN 'dialogue' "
        f"ELSE 'single' END"
    )

    sentence_type_expr = f"NULLIF({alias}.group_type, '')" if has_group_type else "NULL"
    group_table_type_expr = (
        f"(SELECT NULLIF(sg.type, '') FROM sentence_group sg WHERE sg.{sentence_group_key_col} = {alias}.{group_col} LIMIT 1)"
        if has_sentence_group_type
        else "NULL"
    )
    type_expr = f"COALESCE({group_table_type_expr}, {sentence_type_expr}, {inferred_type})"
    default_title_expr = f"CASE WHEN {type_expr} = 'dialogue' THEN '对话' WHEN {type_expr} = 'essay' THEN '短文' ELSE '例句' END"
    sentence_title_expr = f"NULLIF({alias}.group_title, '')" if has_group_title else "NULL"
    group_table_title_expr = (
        f"(SELECT NULLIF(sg.title, '') FROM sentence_group sg WHERE sg.{sentence_group_key_col} = {alias}.{group_col} LIMIT 1)"
        if has_sentence_group_title
        else "NULL"
    )
    title_expr = f"COALESCE({group_table_title_expr}, {sentence_title_expr}, {default_title_expr})"
    speaker_expr = f"COALESCE(NULLIF({alias}.speaker, ''), {speaker_case})" if has_speaker else speaker_case
    content_expr = f"COALESCE(NULLIF({alias}.content, ''), {content_case})" if has_content else content_case

    return (
        f"{alias}.{group_col} AS group_id",
        f"{type_expr} AS group_type",
        f"{title_expr} AS group_title",
        f"{speaker_expr} AS speaker",
        f"{content_expr} AS content",
    )


def token_select_sql(conn, word_table: str) -> str:
    has_pos = column_exists(conn, "sentence_word_grammar", "pos")
    pos_expr = "st.pos" if has_pos else "'' AS pos"
    return f"""
        SELECT st.token_index, st.surface, {pos_expr}, st.word_id, st.grammar_id,
               COALESCE(w.kana, '') as kana, COALESCE(w.kanji, '') as kanji, COALESCE(w.chinese, '') as chinese
        FROM sentence_word_grammar st
        LEFT JOIN {word_table} w ON st.word_id = w.id
        WHERE st.sentence_id = ?
        ORDER BY st.token_index
    """


def split_segmented_tokens(segmented_text: str | None, fallback_text: str | None = None) -> list[str]:
    segmented = (segmented_text or "").replace("\u3000", " ")
    segmented = segmented.replace("/", " ").replace("／", " ")
    segmented = segmented.replace("|", " ").strip()
    if segmented:
        tokens = [part for part in segmented.split() if part]
        if tokens:
            return tokens
    fallback = (fallback_text or "").strip()
    return [fallback] if fallback else []


def build_sentence_tokens(segmented_text: str | None, japanese_text: str | None, mapped_rows: list[dict]) -> list[dict]:
    full_surfaces = split_segmented_tokens(segmented_text, japanese_text)
    mapped_by_index: dict[int, dict] = {}
    for row in mapped_rows:
        idx = row.get("token_index")
        if isinstance(idx, int):
            mapped_by_index[idx] = row

    if full_surfaces:
        merged = []
        for idx, surface in enumerate(full_surfaces):
            mapped = mapped_by_index.get(idx, {})
            merged.append(
                {
                    "token_index": idx,
                    "surface": mapped.get("surface") or surface,
                    "pos": mapped.get("pos", ""),
                    "word_id": mapped.get("word_id"),
                    "grammar_id": mapped.get("grammar_id"),
                    "kana": mapped.get("kana", ""),
                    "kanji": mapped.get("kanji", ""),
                    "chinese": mapped.get("chinese", ""),
                }
            )
        return merged

    return mapped_rows


def tts_audio_id_expr(conn, entity_type: str, entity_id_expr: str) -> str:
    if not table_exists(conn, "tts_audio"):
        return "NULL"
    if not column_exists(conn, "tts_audio", "id"):
        return "NULL"
    return (
        "(SELECT ta.id FROM tts_audio ta "
        f"WHERE ta.entity_type = '{entity_type}' "
        f"AND ta.entity_id = {entity_id_expr} "
        "AND COALESCE(ta.status, 'done') = 'done' "
        "ORDER BY ta.updated_at DESC, ta.id DESC LIMIT 1)"
    )


def resolve_tts_file_path(raw_path: str | None, entity_type: str | None = None, entity_id: int | None = None) -> Path | None:
    base_audio_dir = DB_PATH.parent / "text2speech" / "audio"
    candidates: list[Path] = []

    if raw_path:
        p = Path(raw_path)
        candidates.append(p)

        normalized = str(raw_path).replace("\\", "/").strip()
        if normalized:
            if normalized.startswith("audio/"):
                candidates.append(base_audio_dir / normalized[len("audio/") :])

            normalized_lc = normalized.lower()
            marker_full = "datapre/text2speech/audio/"
            marker_full_lc = marker_full.lower()
            if marker_full_lc in normalized_lc:
                idx = normalized_lc.index(marker_full_lc)
                rel = normalized[idx + len(marker_full) :]
                candidates.append(base_audio_dir / rel)

            marker_audio = "/audio/"
            if marker_audio in normalized_lc:
                idx = normalized_lc.index(marker_audio)
                rel = normalized[idx + len(marker_audio) :]
                candidates.append(base_audio_dir / rel)

    if entity_type and entity_id and (base_audio_dir / entity_type).exists():
        pattern = f"{entity_type}_{entity_id}.mp3"
        candidates.extend(sorted((base_audio_dir / entity_type).glob(f"chapter_*/{pattern}")))

    seen = set()
    for cand in candidates:
        key = str(cand)
        if key in seen:
            continue
        seen.add(key)
        if cand.exists() and cand.is_file():
            return cand

    return None


def llm_get_api_key() -> str:
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        raise ValueError("Missing GEMINI_API_KEY or GOOGLE_API_KEY. Set it in your environment or .env file.")
    return api_key


def llm_get_client() -> genai.Client:
    http_client_kwargs = {
        "verify": GENAI_SSL_VERIFY,
        "trust_env": True,
        "timeout": httpx.Timeout(60.0, connect=20.0),
    }
    if GENAI_HTTP_PROXY:
        http_client_kwargs["proxy"] = GENAI_HTTP_PROXY

    http_client = httpx.Client(**http_client_kwargs)
    http_options = types.HttpOptions(apiVersion=GENAI_API_VERSION, httpxClient=http_client)
    return genai.Client(api_key=llm_get_api_key(), http_options=http_options)


def llm_build_prompt(sentence: str) -> str:
    return (
        "你是日语语法分析助手。\n"
        "请根据输入句子，输出最核心的语法模板和语法解释。\n"
        "只输出严格 JSON，不要 markdown，不要额外文本。\n"
        "\n"
        "输出格式必须是：\n"
        "{\n"
        '  "grammar_pattern": "...",\n'
        '  "grammar_explanation": "..."\n'
        "}\n"
        "\n"
        "要求：\n"
        "1. grammar_pattern 用语法模板形式。\n"
        "2. grammar_explanation 用中文简洁解释。\n"
        "3. 若句子语法不明显，也必须返回两个字段。\n"
        "\n"
        f"句子：{sentence}"
    )


def llm_strip_code_fence(text: str) -> str:
    text = (text or "").strip()
    if not text.startswith("```"):
        return text

    lines = text.splitlines()
    if lines and lines[0].startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].strip() == "```":
        lines = lines[:-1]
    if lines and lines[0].strip().lower() == "json":
        lines = lines[1:]
    return "\n".join(lines).strip()


def llm_extract_json_block(text: str) -> str:
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        return text
    return text[start : end + 1]


def llm_parse_json_response(text: str) -> dict:
    cleaned = llm_strip_code_fence(text)
    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        data = json.loads(llm_extract_json_block(cleaned))

    if not isinstance(data, dict):
        raise ValueError("Model response is not a JSON object")

    return {
        "grammar_pattern": str(data.get("grammar_pattern", "")).strip(),
        "grammar_explanation": str(data.get("grammar_explanation", "")).strip(),
    }


def llm_call(sentence: str) -> dict:
    client = llm_get_client()
    prompt = llm_build_prompt(sentence)
    config_kwargs = {"temperature": 0}
    if GENAI_API_VERSION.lower() != "v1":
        config_kwargs["responseMimeType"] = "application/json"

    response = client.models.generate_content(
        model=GENAI_MODEL,
        contents=prompt,
        config=types.GenerateContentConfig(**config_kwargs),
    )
    return llm_parse_json_response(response.text or "")


def normalize_text(text: str) -> str:
    text = (text or "").strip()
    text = re.sub(r"[₁₂₃]", "", text)
    text = re.sub(r"[()（）\[\]【】{}〈〉《》]", "", text)
    text = re.sub(r"[〜~～]", "", text)
    text = re.sub(r"\s+", "", text)
    return text


def score_text_pair(left_text: str, right_text: str) -> float:
    left = normalize_text(left_text)
    right = normalize_text(right_text)
    if not left or not right:
        return 0.0
    return SequenceMatcher(None, left, right).ratio()


# 《大家的日语》原书单词表带音调核标注（アクセント核），如「飛ぶ10」「pamphlet14」
# 「体育館43」「目が覚める1-2」，显示时去除，保留干净词形。
# 数字块前不能是数字（保护多位数字词「10」）或「の」（保护分数词「4分の1」）。
WORD_TONE_RE = re.compile(r"(?<![0-9の])(?<=\S)[0-9]+(?:-[0-9]+)*$")


def clean_word_display(kanji: str | None, chinese: str | None) -> tuple[str, str]:
    kanji = (kanji or "").strip()
    chinese = (chinese or "").strip()

    # kanji 整条为纯数字且释义不含数字 → 音调标注（如 すると→'10'），
    # 而非数字词本身（きゅう→'9'、とお→'10、10个'）
    if re.fullmatch(r"[0-9]+", kanji) and not re.search(r"[0-9]", chinese):
        kanji = "/"
    else:
        kanji = WORD_TONE_RE.sub("", kanji)

    # 去掉词形（kanji）首尾的波浪标记：原书用「～弁」「～てもらう」「国際～」等
    # 表示接头/接尾词占位；中文释义里的 ～/~ 是语法占位符（如「～和～」「~左右」），保留。
    # U+FF5E 全角波浪、U+301C 波形 dash、U+007E 半角波浪均覆盖。
    kanji = kanji.strip("\uff5e\u301c\u007e")
    if not kanji:
        kanji = "/"
    return kanji, chinese


def clean_word_tokens(tokens: list[dict]) -> list[dict]:
    for token in tokens:
        token["kanji"], token["chinese"] = clean_word_display(
            token.get("kanji"), token.get("chinese")
        )
    return tokens


def load_grammar_index(chapters=range(1, 51)) -> list[dict]:
    conn = get_db()
    try:
        grammar_table = pick_table(conn, "grammar")
        if not table_exists(conn, grammar_table):
            return []

        if not column_exists(conn, grammar_table, "template") or not column_exists(conn, grammar_table, "explanation"):
            return []

        has_chapter = column_exists(conn, grammar_table, "chapter")
        chapter_values = list(chapters) if chapters is not None else []

        if has_chapter and chapter_values:
            placeholders = ",".join(["?"] * len(chapter_values))
            cur = conn.execute(
                f"""
                SELECT id, chapter, template, explanation
                FROM {grammar_table}
                WHERE chapter IN ({placeholders})
                ORDER BY chapter, id
                """,
                tuple(chapter_values),
            )
        elif has_chapter:
            cur = conn.execute(
                f"""
                SELECT id, chapter, template, explanation
                FROM {grammar_table}
                ORDER BY chapter, id
                """
            )
        else:
            cur = conn.execute(
                f"""
                SELECT id, NULL AS chapter, template, explanation
                FROM {grammar_table}
                ORDER BY id
                """
            )

        rows = []
        for row in cur.fetchall():
            grammar_id = row["id"]
            chapter = row["chapter"] if row["chapter"] is not None else 0
            template = str(row["template"] or "").strip()
            explanation = str(row["explanation"] or "").strip()

            if not template and not explanation:
                continue

            rows.append(
                {
                    "unique_id": f"{chapter}:{grammar_id}",
                    "chapter": chapter,
                    "grammar_id": grammar_id,
                    "template": template,
                    "explanation": explanation,
                }
            )
        return rows
    finally:
        conn.close()


def retrieve_top_grammar(grammar_pattern: str, grammar_explanation: str, top_k: int = 3) -> list[dict]:
    template_weight = 0.6
    explanation_weight = 0.4
    template_min = 0.2
    explanation_min = 0.1

    index = load_grammar_index()
    results = []
    for item in index:
        t_score = score_text_pair(grammar_pattern, item["template"])
        e_score = score_text_pair(grammar_explanation, item["explanation"])

        if t_score < template_min and e_score < explanation_min:
            continue

        final_score = t_score * template_weight + e_score * explanation_weight
        results.append(
            {
                "unique_id": item["unique_id"],
                "chapter": item["chapter"],
                "grammar_id": item["grammar_id"],
                "template": item["template"],
                "explanation": item["explanation"],
                "template_score": t_score,
                "explanation_score": e_score,
                "final_score": final_score,
            }
        )

    results.sort(key=lambda x: x["final_score"], reverse=True)
    return results[:top_k]


def grammar_search_cache_key(sentence: str) -> str:
    return re.sub(r"\s+", " ", (sentence or "").strip())


def grammar_search_cache_get(sentence: str) -> dict | None:
    key = grammar_search_cache_key(sentence)
    now = time.time()
    with GRAMMAR_SEARCH_CACHE_LOCK:
        entry = GRAMMAR_SEARCH_CACHE.get(key)
        if not entry:
            return None
        if entry["expires_at"] <= now:
            GRAMMAR_SEARCH_CACHE.pop(key, None)
            return None

        # Keep recently used entries newer in insertion order.
        GRAMMAR_SEARCH_CACHE.pop(key, None)
        GRAMMAR_SEARCH_CACHE[key] = entry
        return entry["value"]


def grammar_search_cache_set(sentence: str, value: dict) -> None:
    key = grammar_search_cache_key(sentence)
    now = time.time()
    expires_at = now + max(1, GRAMMAR_SEARCH_CACHE_TTL_SECONDS)

    with GRAMMAR_SEARCH_CACHE_LOCK:
        # Drop expired entries first.
        expired_keys = [
            cache_key for cache_key, cache_entry in GRAMMAR_SEARCH_CACHE.items() if cache_entry["expires_at"] <= now
        ]
        for expired_key in expired_keys:
            GRAMMAR_SEARCH_CACHE.pop(expired_key, None)

        GRAMMAR_SEARCH_CACHE.pop(key, None)
        GRAMMAR_SEARCH_CACHE[key] = {
            "expires_at": expires_at,
            "value": value,
        }

        while len(GRAMMAR_SEARCH_CACHE) > max(1, GRAMMAR_SEARCH_CACHE_MAX_SIZE):
            oldest_key = next(iter(GRAMMAR_SEARCH_CACHE), None)
            if oldest_key is None:
                break
            GRAMMAR_SEARCH_CACHE.pop(oldest_key, None)


@app.route("/api/words", methods=["GET"])
def get_words():
    """Get all words"""
    conn = get_db()
    chapter = request.args.get("chapter", type=int)
    word_table = pick_table(conn, "words", "word")
    has_chapter = column_exists(conn, word_table, "chapter")
    tts_expr = tts_audio_id_expr(conn, "word", f"{word_table}.id")

    if chapter and has_chapter:
        cur = conn.execute(
            f"SELECT id, kana, kanji, chinese, chapter, {tts_expr} AS tts_audio_id FROM {word_table} WHERE chapter = ? ORDER BY id",
            (chapter,),
        )
    elif has_chapter:
        cur = conn.execute(f"SELECT id, kana, kanji, chinese, chapter, {tts_expr} AS tts_audio_id FROM {word_table} ORDER BY id")
    else:
        cur = conn.execute(f"SELECT id, kana, kanji, chinese, {tts_expr} AS tts_audio_id FROM {word_table} ORDER BY id")
    words = [dict(row) for row in cur.fetchall()]
    for word in words:
        word["kanji"], word["chinese"] = clean_word_display(word.get("kanji"), word.get("chinese"))
    conn.close()
    return jsonify(words)


@app.route("/api/word/<int:word_id>/sentences", methods=["GET"])
def get_word_sentences(word_id):
    """Get sentences containing a specific word"""
    conn = get_db()
    jp_col, seg_col, group_col = sentence_cols(conn)
    group_id_expr, group_type_expr, group_title_expr, speaker_expr, content_expr = sentence_meta_select(conn, "s")
    sentence_tts_expr = tts_audio_id_expr(conn, "sentence", "s.id")
    word_table = pick_table(conn, "words", "word")
    
    # Get sentences where this word appears in tokens
    cur = conn.execute(
        f"""
         SELECT DISTINCT s.id, s.chapter, s.{group_col} AS grid,
             {group_id_expr}, {group_type_expr}, {group_title_expr}, {speaker_expr}, {content_expr}, {sentence_tts_expr} AS tts_audio_id,
             s.{jp_col} AS japanese, s.{seg_col} AS japanese_segmented, s.chinese
        FROM sentence s
        JOIN sentence_word_grammar st ON s.id = st.sentence_id
        WHERE st.word_id = ?
        ORDER BY s.id
        """,
        (word_id,),
    )
    sentences = [dict(row) for row in cur.fetchall()]
    
    # For each sentence, get all tokens with word details
    for sentence in sentences:
        cur = conn.execute(token_select_sql(conn, word_table), (sentence["id"],))
        mapped_tokens = [dict(row) for row in cur.fetchall()]
        sentence["tokens"] = clean_word_tokens(
            build_sentence_tokens(
                sentence.get("japanese_segmented"),
                sentence.get("japanese"),
                mapped_tokens,
            )
        )
    
    conn.close()
    return jsonify(sentences)


@app.route("/api/sentences", methods=["GET"])
def get_sentences():
    """Get all sentences with their tokens"""
    chapter = request.args.get("chapter", type=int)
    
    conn = get_db()
    jp_col, seg_col, group_col = sentence_cols(conn)
    group_id_expr, group_type_expr, group_title_expr, speaker_expr, content_expr = sentence_meta_select(conn, "sentence")
    sentence_tts_expr = tts_audio_id_expr(conn, "sentence", "sentence.id")
    word_table = pick_table(conn, "words", "word")
    
    if chapter:
        cur = conn.execute(
            f"SELECT id, chapter, {group_col} AS grid, {group_id_expr}, {group_type_expr}, {group_title_expr}, {speaker_expr}, {content_expr}, {sentence_tts_expr} AS tts_audio_id, {jp_col} AS japanese, {seg_col} AS japanese_segmented, chinese FROM sentence WHERE chapter = ? ORDER BY id",
            (chapter,),
        )
    else:
        cur = conn.execute(
            f"SELECT id, chapter, {group_col} AS grid, {group_id_expr}, {group_type_expr}, {group_title_expr}, {speaker_expr}, {content_expr}, {sentence_tts_expr} AS tts_audio_id, {jp_col} AS japanese, {seg_col} AS japanese_segmented, chinese FROM sentence ORDER BY id"
        )
    
    sentences = [dict(row) for row in cur.fetchall()]
    
    has_sentence_grammar = table_exists(conn, "sentence_grammar")

    # Get tokens and grammar matches for each sentence
    for sentence in sentences:
        cur = conn.execute(token_select_sql(conn, word_table), (sentence["id"],))
        mapped_tokens = [dict(row) for row in cur.fetchall()]
        sentence["tokens"] = clean_word_tokens(
            build_sentence_tokens(
                sentence.get("japanese_segmented"),
                sentence.get("japanese"),
                mapped_tokens,
            )
        )

        if has_sentence_grammar:
            cur = conn.execute(
                """
                SELECT sg.grammar_id, sg.start_char, sg.end_char, sg.start_token_index, sg.end_token_index,
                       sg.matched_text, sg.source, sg.confidence, sg.reason,
                       g.template AS grammar_template
                FROM sentence_grammar sg
                LEFT JOIN grammar g ON g.id = sg.grammar_id
                WHERE sg.sentence_id = ?
                ORDER BY sg.start_char, sg.end_char
                """,
                (sentence["id"],),
            )
            sentence["grammar_matches"] = [dict(row) for row in cur.fetchall()]
        else:
            sentence["grammar_matches"] = []
    
    conn.close()
    return jsonify(sentences)


@app.route("/api/grammar", methods=["GET"])
def get_grammar():
    """Get all grammar points with their example sentences"""
    chapter = request.args.get("chapter", type=int)
    
    conn = get_db()
    jp_col, seg_col, group_col = sentence_cols(conn)
    sentence_tts_expr = tts_audio_id_expr(conn, "sentence", "s.id")
    word_table = pick_table(conn, "words", "word")
    
    if chapter:
        cur = conn.execute(
            "SELECT id, chapter, template, explanation FROM grammar WHERE chapter = ? ORDER BY id",
            (chapter,),
        )
    else:
        cur = conn.execute(
            "SELECT id, chapter, template, explanation FROM grammar ORDER BY id"
        )
    
    grammar_points = [dict(row) for row in cur.fetchall()]
    
    # Get example sentences for each grammar point
    for point in grammar_points:
        group_id_expr, group_type_expr, group_title_expr, speaker_expr, content_expr = sentence_meta_select(conn, "s")
        if table_exists(conn, "grammar_examples"):
            cur = conn.execute(
                f"""
                SELECT s.id, s.chapter, s.{group_col} AS grid,
                      {group_id_expr}, {group_type_expr}, {group_title_expr}, {speaker_expr}, {content_expr}, {sentence_tts_expr} AS tts_audio_id,
                       s.{jp_col} AS japanese, s.{seg_col} AS japanese_segmented, s.chinese
                FROM sentence s
                JOIN grammar_examples ge ON s.id = ge.sentence_id
                WHERE ge.grammar_id = ?
                ORDER BY s.id
                """,
                (point["id"],),
            )
        else:
            cur = conn.execute(
                f"""
                  SELECT s.id, s.chapter, s.{group_col} AS grid,
                      {group_id_expr}, {group_type_expr}, {group_title_expr}, {speaker_expr}, {content_expr}, {sentence_tts_expr} AS tts_audio_id,
                       s.{jp_col} AS japanese, s.{seg_col} AS japanese_segmented, s.chinese
                FROM sentence s
                JOIN grammar_group_sentence ggs ON s.group_id = ggs.group_id
                WHERE ggs.grammar_id = ?
                ORDER BY s.id
                """,
                (point["id"],),
            )
        
        examples = [dict(row) for row in cur.fetchall()]
        
        # Get tokens for each example sentence
        for example in examples:
            cur = conn.execute(token_select_sql(conn, word_table), (example["id"],))
            mapped_tokens = [dict(row) for row in cur.fetchall()]
            example["tokens"] = clean_word_tokens(
                build_sentence_tokens(
                    example.get("japanese_segmented"),
                    example.get("japanese"),
                    mapped_tokens,
                )
            )
        
        point["examples"] = examples
    
    conn.close()
    return jsonify(grammar_points)


@app.route("/api/tts/audio", methods=["GET"])
def get_tts_audio():
    """Stream TTS audio by tts_audio_id or by (entity_type, entity_id)."""
    conn = get_db()
    try:
        if not table_exists(conn, "tts_audio"):
            abort(404, description="tts_audio table not found")

        tts_audio_id = request.args.get("tts_audio_id", type=int)
        entity_type = request.args.get("entity_type", default="", type=str).strip().lower()
        entity_id = request.args.get("entity_id", type=int)

        if tts_audio_id:
            row = conn.execute(
                """
                SELECT id, file_path, audio_encoding, status, entity_type, entity_id
                FROM tts_audio
                WHERE id = ?
                LIMIT 1
                """,
                (tts_audio_id,),
            ).fetchone()
        elif entity_type and entity_id is not None:
            row = conn.execute(
                """
                SELECT id, file_path, audio_encoding, status, entity_type, entity_id
                FROM tts_audio
                WHERE entity_type = ? AND entity_id = ?
                ORDER BY updated_at DESC, id DESC
                LIMIT 1
                """,
                (entity_type, entity_id),
            ).fetchone()
        else:
            abort(400, description="Provide tts_audio_id or (entity_type and entity_id)")

        if not row:
            abort(404, description="TTS audio not found")

        if row["status"] and row["status"] != "done":
            abort(404, description="TTS audio is not ready")

        file_path = resolve_tts_file_path(
            row["file_path"],
            row["entity_type"],
            row["entity_id"],
        )
        if not file_path:
            abort(404, description="Audio file not found")

        audio_encoding = (row["audio_encoding"] or "MP3").upper()
        mimetype = "audio/mpeg" if audio_encoding == "MP3" else "application/octet-stream"
        return send_file(file_path, mimetype=mimetype, conditional=True)
    finally:
        conn.close()


@app.route("/api/grammar-search", methods=["POST"])
def grammar_search():
    payload = request.get_json(silent=True) or {}
    sentence = str(payload.get("sentence", "")).strip()
    if not sentence:
        return jsonify({"error": "sentence is required"}), 400

    try:
        cached_value = grammar_search_cache_get(sentence)
        if cached_value is not None:
            return jsonify(cached_value)

        llm_result = llm_call(sentence)
        grammar_pattern = llm_result.get("grammar_pattern", "")
        grammar_explanation = llm_result.get("grammar_explanation", "")
        matches = retrieve_top_grammar(grammar_pattern, grammar_explanation, top_k=3)
        response_data = {
            "sentence": sentence,
            "llm": llm_result,
            "results": matches,
        }
        grammar_search_cache_set(sentence, response_data)
        return jsonify(response_data)
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


# ---------- 认证（邮箱登录注册，游客可浏览公开内容） ----------
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
SESSION_TTL_DAYS = 30


def now_str() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def get_current_user() -> dict | None:
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    token = auth[len("Bearer "):].strip()
    if not token:
        return None
    conn = get_db()
    try:
        row = conn.execute(
            "SELECT u.id, u.email, u.nickname, u.created_at, s.expires_at "
            "FROM sessions s JOIN users u ON u.id = s.user_id "
            "WHERE s.token = ? LIMIT 1",
            (token,),
        ).fetchone()
    finally:
        conn.close()
    if not row:
        return None
    if row["expires_at"] and row["expires_at"] <= now_str():
        return None
    return {
        "id": row["id"],
        "email": row["email"],
        "nickname": row["nickname"],
        "created_at": row["created_at"],
    }


def require_auth(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        user = get_current_user()
        if not user:
            return jsonify({"error": "请先登录后再使用该功能"}), 401
        g.user = user
        return f(*args, **kwargs)
    return wrapper


def create_session(conn, user_id: int) -> str:
    token = secrets.token_hex(32)
    expires = (datetime.now() + timedelta(days=SESSION_TTL_DAYS)).strftime("%Y-%m-%d %H:%M:%S")
    conn.execute(
        "INSERT INTO sessions (token, user_id, created_at, expires_at) VALUES (?,?,?,?)",
        (token, user_id, now_str(), expires),
    )
    return token


@app.route("/api/auth/register", methods=["POST"])
def auth_register():
    payload = request.get_json(silent=True) or {}
    email = str(payload.get("email", "")).strip().lower()
    password = str(payload.get("password", ""))
    nickname = str(payload.get("nickname", "")).strip()

    if not EMAIL_RE.match(email):
        return jsonify({"error": "邮箱格式不正确"}), 400
    if len(password) < 6:
        return jsonify({"error": "密码至少 6 位"}), 400
    if not nickname:
        nickname = email.split("@")[0]

    conn = get_db()
    try:
        if conn.execute("SELECT 1 FROM users WHERE email = ?", (email,)).fetchone():
            return jsonify({"error": "该邮箱已注册，请直接登录"}), 409
        conn.execute(
            "INSERT INTO users (email, password_hash, nickname, created_at, updated_at) VALUES (?,?,?,?,?)",
            (email, generate_password_hash(password), nickname, now_str(), now_str()),
        )
        user_id = conn.execute("SELECT id FROM users WHERE email = ?", (email,)).fetchone()["id"]
        token = create_session(conn, user_id)
        conn.commit()
        return jsonify({
            "token": token,
            "user": {"id": user_id, "email": email, "nickname": nickname, "created_at": now_str()},
        }), 201
    finally:
        conn.close()


@app.route("/api/auth/login", methods=["POST"])
def auth_login():
    payload = request.get_json(silent=True) or {}
    email = str(payload.get("email", "")).strip().lower()
    password = str(payload.get("password", ""))

    conn = get_db()
    try:
        row = conn.execute(
            "SELECT id, email, nickname, password_hash, created_at FROM users WHERE email = ?",
            (email,),
        ).fetchone()
        if not row or not check_password_hash(row["password_hash"], password):
            return jsonify({"error": "邮箱或密码错误"}), 401
        conn.execute("DELETE FROM sessions WHERE expires_at <= ?", (now_str(),))
        token = create_session(conn, row["id"])
        conn.commit()
        return jsonify({
            "token": token,
            "user": {"id": row["id"], "email": row["email"], "nickname": row["nickname"], "created_at": row["created_at"]},
        })
    finally:
        conn.close()


@app.route("/api/auth/logout", methods=["POST"])
@require_auth
def auth_logout():
    auth = request.headers.get("Authorization", "")
    token = auth[len("Bearer "):].strip()
    conn = get_db()
    try:
        conn.execute("DELETE FROM sessions WHERE token = ?", (token,))
        conn.commit()
    finally:
        conn.close()
    return jsonify({"ok": True})


@app.route("/api/auth/me", methods=["GET"])
@require_auth
def auth_me():
    return jsonify({"user": g.user})


@app.route("/api/auth/me", methods=["PUT"])
@require_auth
def auth_update_me():
    payload = request.get_json(silent=True) or {}
    conn = get_db()
    try:
        if "nickname" in payload:
            nickname = str(payload.get("nickname", "")).strip()
            if not nickname or len(nickname) > 30:
                return jsonify({"error": "昵称长度需在 1-30 个字符内"}), 400
            conn.execute(
                "UPDATE users SET nickname = ?, updated_at = ? WHERE id = ?",
                (nickname, now_str(), g.user["id"]),
            )
            g.user["nickname"] = nickname
        if payload.get("new_password"):
            old_password = str(payload.get("old_password", ""))
            new_password = str(payload.get("new_password", ""))
            if len(new_password) < 6:
                return jsonify({"error": "新密码至少 6 位"}), 400
            row = conn.execute("SELECT password_hash FROM users WHERE id = ?", (g.user["id"],)).fetchone()
            if not row or not check_password_hash(row["password_hash"], old_password):
                return jsonify({"error": "原密码错误"}), 400
            conn.execute(
                "UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?",
                (generate_password_hash(new_password), now_str(), g.user["id"]),
            )
        conn.commit()
        return jsonify({"user": g.user})
    finally:
        conn.close()


# ---------- 测试与复习（掌握度闭环） ----------

MASTERY_INIT = 50.0
MASTERY_GAIN = 10.0
MASTERY_GAIN_STREAK = 15.0
MASTERY_PENALTY = 25.0
MASTERY_LOW = 60.0


def review_days_for_mastery(mastery: float) -> int:
    if mastery < 60:
        return 1
    if mastery < 80:
        return 3
    return 7


@app.route("/api/test/submit", methods=["POST"])
@require_auth
def test_submit():
    payload = request.get_json(silent=True) or {}
    element_type = str(payload.get("element_type", "")).strip().lower()
    element_id = payload.get("element_id")
    correct_raw = payload.get("correct")
    duration_ms = payload.get("duration_ms", 0)
    chapter = payload.get("chapter")

    if element_type not in ("word", "grammar"):
        return jsonify({"error": "element_type 只能是 word 或 grammar"}), 400
    if not isinstance(element_id, int) or element_id <= 0:
        return jsonify({"error": "element_id 无效"}), 400
    if correct_raw not in (True, False, 0, 1):
        return jsonify({"error": "correct 必须是布尔值"}), 400
    correct_flag = 1 if correct_raw in (True, 1) else 0

    conn = get_db()
    try:
        table = "word" if element_type == "word" else "grammar"
        if not table_exists(conn, table):
            return jsonify({"error": f"数据表 {table} 不存在"}), 500
        if not conn.execute(f"SELECT 1 FROM {table} WHERE id = ?", (element_id,)).fetchone():
            return jsonify({"error": "元素不存在"}), 404

        now = now_str()
        conn.execute(
            "INSERT INTO user_answer_log (user_id, element_type, element_id, chapter, correct, duration_ms, created_at) VALUES (?,?,?,?,?,?,?)",
            (g.user["id"], element_type, element_id, chapter, correct_flag, duration_ms, now),
        )

        mrow = conn.execute(
            "SELECT * FROM user_element_mastery WHERE user_id=? AND element_type=? AND element_id=?",
            (g.user["id"], element_type, element_id),
        ).fetchone()

        if mrow:
            mastery = float(mrow["mastery"])
            streak = int(mrow["streak"])
            correct_count = int(mrow["correct_count"])
            wrong_count = int(mrow["wrong_count"])
            total = int(mrow["total_attempts"])
        else:
            mastery, streak, correct_count, wrong_count, total = MASTERY_INIT, 0, 0, 0, 0

        if correct_flag:
            new_streak = streak + 1
            gain = MASTERY_GAIN_STREAK if new_streak >= 3 else MASTERY_GAIN
            new_mastery = min(100.0, mastery + gain)
            correct_count += 1
        else:
            new_streak = 0
            new_mastery = max(0.0, mastery - MASTERY_PENALTY)
            wrong_count += 1
        total += 1

        if correct_flag:
            next_review = (datetime.now() + timedelta(days=review_days_for_mastery(new_mastery))).strftime("%Y-%m-%d %H:%M:%S")
        else:
            next_review = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d %H:%M:%S")

        if mrow:
            conn.execute(
                "UPDATE user_element_mastery SET mastery=?, correct_count=?, wrong_count=?, total_attempts=?, streak=?, last_reviewed_at=?, next_review_at=? WHERE id=?",
                (new_mastery, correct_count, wrong_count, total, new_streak, now, next_review, mrow["id"]),
            )
        else:
            conn.execute(
                "INSERT INTO user_element_mastery (user_id, element_type, element_id, mastery, correct_count, wrong_count, total_attempts, streak, last_reviewed_at, next_review_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
                (g.user["id"], element_type, element_id, new_mastery, correct_count, wrong_count, total, new_streak, now, next_review),
            )

        # 任何一次作答都会把该元素的活动队列项标记为已完成（复习闭环）；
        # 若本次为“忘记”，则重新入队，次日优先复习。
        conn.execute(
            "UPDATE user_review_queue SET status='done' WHERE user_id=? AND element_type=? AND element_id=? AND status='active'",
            (g.user["id"], element_type, element_id),
        )
        if not correct_flag:
            conn.execute(
                "INSERT INTO user_review_queue (user_id, element_type, element_id, source, priority, due_at, status, created_at) VALUES (?,?,?,?,?,?,?,?)",
                (g.user["id"], element_type, element_id, "wrong", 100.0, next_review, "active", now),
            )

        conn.commit()
        return jsonify({
            "mastery": round(new_mastery, 1),
            "correct_count": correct_count,
            "wrong_count": wrong_count,
            "total_attempts": total,
            "streak": new_streak,
            "next_review_at": next_review,
        })
    finally:
        conn.close()


@app.route("/api/review/recommendations", methods=["GET"])
@require_auth
def review_recommendations():
    limit = request.args.get("limit", type=int) or 30
    conn = get_db()
    try:
        now = now_str()
        items = []

        rows = conn.execute(
            "SELECT element_type, element_id, source FROM user_review_queue "
            "WHERE user_id=? AND status='active' AND due_at<=? ORDER BY priority DESC",
            (g.user["id"], now),
        ).fetchall()
        for r in rows:
            items.append({
                "element_type": r["element_type"],
                "element_id": r["element_id"],
                "source": "wrong",
                "reason": "上次忘记，优先复习",
            })

        mrows = conn.execute(
            "SELECT element_type, element_id, mastery, next_review_at FROM user_element_mastery "
            "WHERE user_id=? AND (mastery<? OR next_review_at<=?)",
            (g.user["id"], MASTERY_LOW, now),
        ).fetchall()
        seen = {(i["element_type"], i["element_id"]) for i in items}
        for r in mrows:
            key = (r["element_type"], r["element_id"])
            if key in seen:
                continue
            reason = "掌握度较低" if r["mastery"] < MASTERY_LOW else "到期复习"
            items.append({
                "element_type": r["element_type"],
                "element_id": r["element_id"],
                "source": "due",
                "reason": reason,
                "mastery": round(float(r["mastery"]), 1),
            })
            seen.add(key)

        return jsonify(items[:limit])
    finally:
        conn.close()


if __name__ == "__main__":
    ensure_schema()
    app.run(debug=True, port=5000)
