import sqlite3
from pathlib import Path
from flask import Flask, abort, jsonify, request, send_file
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

DB_PATH = Path(__file__).resolve().parent / "datapre" / "nihon_assistant_data.db"


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


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
        sentence["tokens"] = [dict(row) for row in cur.fetchall()]
    
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
        sentence["tokens"] = [dict(row) for row in cur.fetchall()]

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
            example["tokens"] = [dict(row) for row in cur.fetchall()]
        
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


if __name__ == "__main__":
    app.run(debug=True, port=5000)
