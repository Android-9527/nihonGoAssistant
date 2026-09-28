# -*- coding: utf-8 -*-
"""
手工分析标注（不调用任何外部 API）：
逐章读取 grammar 表 + sentence 表，由人工(AI)逐句判断句子中哪些分词
命中本章语法的核心固定成分（助词、接续、活用形等），名词/代词等实词不标。
产出与 grammar_annotate.py 相同的 preview JSON 格式，供 import2setence_word_grammar.py 回填。

用法:
  python manual_annotate.py 27          # 只构建第27章 preview
  python manual_annotate.py 27 28 29    # 构建多章
  python manual_annotate.py             # 构建所有已录入 CHAPTER_MATCHES 的章
"""

import json
import sqlite3
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "nihon_assistant_data.db"
OUTPUT_DIR = BASE_DIR / "grammar_annotate"
MODEL_TAG = "manual-analysis"

# =====================================================================
# 每章标注数据：{ chapter: { sentence_id: [ (grammar_id, [token_indices]), ... ] } }
# token_indices 为 0 基，仅标注语法核心固定成分。
# =====================================================================
CHAPTER_MATCHES = {
    27: {
        5882: [(333, [5]), (334, [2])],                    # 話せます / 日本語が
        5883: [(335, [3]), (334, [1])],                    # 見えます / 山が
        5884: [(336, [7]), (334, [6])],                    # できました / スーパーが
        5885: [(333, [4]), (334, [3])],                    # 読めます / 新聞が
        5886: [(333, [1])],                                # 読めません
        5887: [(335, [4]), (334, [3])],                    # 聞こえます / 声が
        5889: [(336, [3])],                                # できました
        5890: [(336, [3])],                                # できました
        5893: [(337, [9]), (333, [10])],                   # しか / 休めません
        5894: [(333, [5]), (334, [4])],                    # 飼えます / ペットが
        5895: [(333, [5]), (333, [12]), (338, [4]), (338, [11])],  # 飼えます/飼えません / 魚は/猫は(对比)
        5897: [(335, [9]), (334, [8]), (339, [6])],        # 見える / 海が / 日には
        5904: [(333, [5])],                                # 作れる
        5908: [(333, [14]), (333, [33]), (333, [46]), (339, [36])],  # 出せ/飛べ/られ / では
        5909: [(333, [17]), (333, [23])],                  # 行けます / 会え
        5912: [(333, [5]), (334, [4])],                    # 話せます / 日本語が
        5913: [(333, [4])],                                # 行けます
        5914: [(333, [3])],                                # 会えません
        5915: [(333, [5]), (334, [4])],                    # 読めます / 漢字が
        5916: [(333, [6]), (334, [4])],                    # 換えられます(られ) / ドルが
        5917: [(335, [4]), (334, [3])],                    # 見えます / 富士山が
        5918: [(335, [4]), (334, [3])],                    # 聞こえます / 音が
        5919: [(333, [8]), (334, [7])],                    # 見られます(られ) / 映画が
        5920: [(333, [6]), (334, [5])],                    # 聞けます / 予報が
        5921: [(336, [7]), (334, [6])],                    # できました / スーパーが
        5922: [(336, [5])],                                # できます
        5923: [(337, [1]), (333, [2])],                    # しか / 書けません
        5924: [(333, [2])],                                # 書けます
        5925: [(338, [1]), (338, [5])],                    # ワインは/ビールは(对比)
        5926: [(338, [1]), (338, [8]), (335, [4]), (335, [9]), (334, [3])],  # きのうは/きょうは / 見えました/見えません / 山が
        5927: [(336, [7]), (339, [1])],                    # できません / 日本では
        5928: [(335, [8]), (334, [7]), (339, [5])],        # 見える / 海が / 日には
        5929: [(335, [6]), (334, [4]), (339, [2])],        # 見えません / スカイツリーが / ここからは
    },
    28: {
        5930: [(340, [3])],                                # ながら
        5931: [(341, [4]), (341, [5])],                    # ています(し/て/います → て/います)
        5932: [(344, [1]), (340, [5])],                    # とき / ながら
        5934: [(340, [3])],                                # ながら
        5935: [(344, [2])],                                # とき
        5936: [(340, [3]), (341, [8]), (341, [9])],        # ながら / ています
        5938: [(341, [8]), (341, [9])],                    # ています
        5939: [(341, [5]), (341, [6])],                    # ています
        5940: [(342, [5]), (342, [7])],                    # し / し
        5943: [(342, [6]), (342, [10])],                   # し / し
        5945: [(342, [4]), (342, [9])],                    # し / し
        5950: [(343, [1])],                                # それで
        5952: [(342, [11]), (342, [18])],                  # し / し
        5954: [(344, [3]), (340, [7])],                    # とき / ながら
        5955: [(342, [4])],                                # し
        5959: [(340, [7])],                                # ながら
        5960: [(342, [3]), (342, [7])],                    # し / し
        5965: [(340, [4])],                                # ながら
        5966: [(340, [2]), (341, [7]), (341, [8])],        # ながら / ています
        5967: [(341, [5]), (341, [6])],                    # ています
        5968: [(344, [3]), (341, [9]), (341, [10])],       # とき / ていました
        5969: [(342, [7]), (342, [11])],                   # し / し
        5970: [(342, [5]), (342, [11])],                   # し / し
        5971: [(342, [5]), (342, [9])],                    # し / し
        5973: [(342, [5]), (342, [9])],                    # し / し
        5975: [(342, [3])],                                # し
        5976: [(343, [7]), (340, [13]), (341, [17]), (341, [18])],  # それで / ながら / ています
        5977: [(342, [5]), (342, [9])],                    # し / し
        5978: [(343, [0])],                                # それで
        5979: [(344, [1])],                                # とき
        5980: [(344, [2]), (344, [5])],                    # とき / とき
    },
}


def load_grammar_rows(conn: sqlite3.Connection, chapter: int) -> list[dict]:
    cur = conn.cursor()
    cur.execute(
        "SELECT id, template, explanation FROM grammar WHERE chapter = ? ORDER BY id",
        (chapter,),
    )
    result = []
    for grammar_id, template, explanation in cur.fetchall():
        result.append(
            {
                "grammar_id": grammar_id,
                "template": (template or "").strip(),
                "explanation": (explanation or "").strip(),
            }
        )
    return result


def load_sentences(conn: sqlite3.Connection, chapter: int) -> list[dict]:
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, jp_sentence, COALESCE(jp_sentence_seg, '')
        FROM sentence
        WHERE chapter = ?
        ORDER BY id
        """,
        (chapter,),
    )
    result = []
    for sentence_id, jp_sentence, jp_sentence_seg in cur.fetchall():
        tokens = [t for t in (jp_sentence_seg or "").strip("/").split("/") if t]
        if not tokens:
            continue
        result.append(
            {
                "sentence_id": sentence_id,
                "jp_sentence": jp_sentence or "",
                "jp_sentence_seg": jp_sentence_seg or "",
                "tokens": tokens,
            }
        )
    return result


def build_preview(chapter: int) -> None:
    conn = sqlite3.connect(DB_PATH)
    try:
        grammars = load_grammar_rows(conn, chapter)
        gmap = {g["grammar_id"]: g["template"] for g in grammars}
        sentences = load_sentences(conn, chapter)
        chapter_data = CHAPTER_MATCHES.get(chapter, {})

        total_matches = 0
        results = []
        for s in sentences:
            sid = s["sentence_id"]
            token_len = len(s["tokens"])
            matches = []
            for grammar_id, indices in chapter_data.get(sid, []):
                if grammar_id not in gmap:
                    continue
                valid = [i for i in indices if isinstance(i, int) and 0 <= i < token_len]
                if valid:
                    matches.append(
                        {
                            "sentence_id": sid,
                            "grammar_id": grammar_id,
                            "template": gmap[grammar_id],
                            "token_indices": sorted(set(valid)),
                        }
                    )
            total_matches += len(matches)
            results.append({**s, "matches": matches})

        payload = {
            "chapter": chapter,
            "model": MODEL_TAG,
            "grammar_list": grammars,
            "sentence_count": len(sentences),
            "match_count": total_matches,
            "results": results,
        }
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        out_path = OUTPUT_DIR / f"chapter{chapter}_highlight_preview.json"
        out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"✅ 第{chapter}章 preview 构建完成: {len(sentences)}句, {total_matches}匹配 -> {out_path}")
    finally:
        conn.close()


if __name__ == "__main__":
    if len(sys.argv) >= 2:
        chapters = [int(a) for a in sys.argv[1:]]
    else:
        chapters = sorted(CHAPTER_MATCHES.keys())
    for ch in chapters:
        build_preview(ch)
