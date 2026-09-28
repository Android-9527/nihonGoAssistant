

# 读取每一章的json数据，将他们存储到sqlite数据库中
# 读取words单词，创建word表{id,chapter,kana,kanji,chinese},将json的words的数据存储到word表中
# 创建sentence表{id,chapter，group_id,jp_sentence,jp_sentence_seg,chinese},
# 创建sentence_group表{group_id,chapter,type} type为{single_sentence,mul_sentences,dialogue,essay}
# 创建grammar表{id,chapter,template,explanation}
# 创建grammar_group_sentence表{id,grammar_id,group_id}
# 创建sentence_word_grammar表{id,sentence_id,word_id,grammar_id,surface,token_index} surface是分词的日语，不包含符号，token_index是分词日语的序号
# from fugashi import Tagger

# tagger = Tagger() 分词用这个


import sqlite3
import json
from pathlib import Path
from typing import Optional, Dict, List, Tuple



DB_PATH = Path(__file__).resolve().parent / "nihon_assistant_data.db"
LANGUAGE_DATA_PATH = Path(__file__).resolve().parent / "language_data"


def init_database():
    """初始化数据库，创建所有表"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # 创建word表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS word (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chapter INTEGER NOT NULL,
            kana TEXT NOT NULL,
            kanji TEXT NOT NULL,
            chinese TEXT NOT NULL
        )
    """)
    
    # 创建sentence_group表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS sentence_group (
            group_id INTEGER PRIMARY KEY AUTOINCREMENT,
            chapter INTEGER NOT NULL,
            type TEXT NOT NULL,
            title TEXT
        )
    """)
    
    # 创建sentence表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS sentence (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chapter INTEGER NOT NULL,
            group_id INTEGER NOT NULL,
            jp_sentence TEXT NOT NULL,
            jp_sentence_seg TEXT,
            chinese TEXT NOT NULL,
            seq_no INTEGER,
            speaker TEXT,
            FOREIGN KEY (group_id) REFERENCES sentence_group(group_id) ON DELETE CASCADE
        )
    """)
    
    # 创建grammar表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS grammar (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chapter INTEGER NOT NULL,
            template TEXT NOT NULL,
            explanation TEXT NOT NULL
        )
    """)
    
    # 创建grammar_group_sentence表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS grammar_group_sentence (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            grammar_id INTEGER NOT NULL,
            group_id INTEGER NOT NULL,
            FOREIGN KEY (grammar_id) REFERENCES grammar(id) ON DELETE CASCADE,
            FOREIGN KEY (group_id) REFERENCES sentence_group(group_id) ON DELETE CASCADE
        )
    """)
    
    # 创建sentence_word_grammar表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS sentence_word_grammar (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sentence_id INTEGER NOT NULL,
            word_id INTEGER,
            grammar_id INTEGER,
            surface TEXT NOT NULL,
            token_index INTEGER NOT NULL,
            FOREIGN KEY (sentence_id) REFERENCES sentence(id) ON DELETE CASCADE,
            FOREIGN KEY (word_id) REFERENCES word(id) ON DELETE SET NULL,
            FOREIGN KEY (grammar_id) REFERENCES grammar(id) ON DELETE SET NULL
        )
    """)
    
    conn.commit()
    conn.close()
    print("✓ 数据库和表创建成功")


def load_json_chapter(chapter_num: int) -> Optional[Dict]:
    """加载指定章节的JSON文件"""
    json_path = LANGUAGE_DATA_PATH / f"chapter_{chapter_num}.json"
    if not json_path.exists():
        print(f"⚠ 章节文件不存在: {json_path}")
        return None
    
    with open(json_path, "r", encoding="utf-8") as f:
        return json.load(f)


def insert_words(conn: sqlite3.Connection, words_data: List[Dict], chapter: int):
    """插入word数据"""
    cursor = conn.cursor()
    for word in words_data:
        cursor.execute("""
            INSERT INTO word (chapter, kana, kanji, chinese)
            VALUES (?, ?, ?, ?)
        """, (chapter, word.get("kana"), word.get("kanji"), word.get("chinese")))
    conn.commit()


def insert_sentences(conn: sqlite3.Connection, sentences_data: List[Dict], chapter: int) -> List[int]:
    """插入单句并创建对应的group，返回sentence的id列表"""
    cursor = conn.cursor()
    sentence_ids = []
    
    for sent in sentences_data:
        # 为每个单句创建一个group
        cursor.execute("""
            INSERT INTO sentence_group (chapter, type, title)
            VALUES (?, ?, NULL)
        """, (chapter, "single_sentence"))
        group_id = cursor.lastrowid
        
        # 插入sentence
        cursor.execute("""
            INSERT INTO sentence (chapter, group_id, jp_sentence, jp_sentence_seg, chinese, seq_no, speaker)
            VALUES (?, ?, ?, NULL, ?, 1, NULL)
        """, (chapter, group_id, sent.get("sentence"), sent.get("chinese")))
        sentence_ids.append(cursor.lastrowid)
    
    conn.commit()
    return sentence_ids


def insert_mul_sentences(conn: sqlite3.Connection, mul_sentences_data: List[Dict], chapter: int) -> List[int]:
    """插入多句段落"""
    cursor = conn.cursor()
    group_ids = []
    
    for mul_sent_group in mul_sentences_data:
        # 为每个多句组创建一个group
        cursor.execute("""
            INSERT INTO sentence_group (chapter, type, title)
            VALUES (?, ?, NULL)
        """, (chapter, "mul_sentences"))
        group_id = cursor.lastrowid
        group_ids.append(group_id)
        
        # 插入该组内的每一句
        for seq_no, sent in enumerate(mul_sent_group.get("sentences", []), start=1):
            cursor.execute("""
                INSERT INTO sentence (chapter, group_id, jp_sentence, jp_sentence_seg, chinese, seq_no, speaker)
                VALUES (?, ?, ?, NULL, ?, ?, NULL)
            """, (chapter, group_id, sent.get("sentence"), sent.get("chinese"), seq_no))
    
    conn.commit()
    return group_ids


def insert_dialogue(conn: sqlite3.Connection, dialogue_data: Dict, chapter: int) -> Optional[int]:
    """插入长对话"""
    if dialogue_data is None:
        return None
    
    cursor = conn.cursor()
    title = dialogue_data.get("title", "")
    
    # 创建dialogue group
    cursor.execute("""
        INSERT INTO sentence_group (chapter, type, title)
        VALUES (?, ?, ?)
    """, (chapter, "dialogue", title))
    group_id = cursor.lastrowid
    
    # 插入对话中的每一句
    for seq_no, sent in enumerate(dialogue_data.get("sentences", []), start=1):
        sentence_text = sent.get("sentence", "")
        speaker = None
        
        # 从"说话人:内容"格式中提取说话人
        if ":" in sentence_text:
            parts = sentence_text.split(":", 1)
            speaker = parts[0].replace("说话人", "").strip()
            sentence_text = parts[1].strip()
        
        cursor.execute("""
            INSERT INTO sentence (chapter, group_id, jp_sentence, jp_sentence_seg, chinese, seq_no, speaker)
            VALUES (?, ?, ?, NULL, ?, ?, ?)
        """, (chapter, group_id, sentence_text, sent.get("chinese"), seq_no, speaker))
    
    conn.commit()
    return group_id


def insert_essay(conn: sqlite3.Connection, essay_data: Optional[Dict], chapter: int) -> Optional[int]:
    """插入文章"""
    if essay_data is None:
        return None
    
    cursor = conn.cursor()
    title = essay_data.get("title", "")
    
    # 创建essay group
    cursor.execute("""
        INSERT INTO sentence_group (chapter, type, title)
        VALUES (?, ?, ?)
    """, (chapter, "essay", title))
    group_id = cursor.lastrowid
    
    # 插入文章中的每一句
    for seq_no, sent in enumerate(essay_data.get("sentences", []), start=1):
        cursor.execute("""
            INSERT INTO sentence (chapter, group_id, jp_sentence, jp_sentence_seg, chinese, seq_no, speaker)
            VALUES (?, ?, ?, NULL, ?, ?, NULL)
        """, (chapter, group_id, sent.get("sentence"), sent.get("chinese"), seq_no))
    
    conn.commit()
    return group_id


def insert_grammar(conn: sqlite3.Connection, grammar_data: List[Dict], chapter: int):
    """插入语法及其例句关联"""
    cursor = conn.cursor()
    
    for grammar in grammar_data:
        # 插入grammar
        cursor.execute("""
            INSERT INTO grammar (chapter, template, explanation)
            VALUES (?, ?, ?)
        """, (chapter, grammar.get("template"), grammar.get("explanation")))
        grammar_id = cursor.lastrowid
        
        # 处理grammar的sentences（单句例子）
        for sent in grammar.get("sentences", []):
            # 为每个单句创建group
            cursor.execute("""
                INSERT INTO sentence_group (chapter, type, title)
                VALUES (?, ?, NULL)
            """, (chapter, "grammar_example"))
            group_id = cursor.lastrowid
            
            # 插入sentence
            cursor.execute("""
                INSERT INTO sentence (chapter, group_id, jp_sentence, jp_sentence_seg, chinese, seq_no)
                VALUES (?, ?, ?, NULL, ?, 1)
            """, (chapter, group_id, sent.get("sentence"), sent.get("chinese")))
            
            # 关联到grammar
            cursor.execute("""
                INSERT INTO grammar_group_sentence (grammar_id, group_id)
                VALUES (?, ?)
            """, (grammar_id, group_id))
        
        # 处理grammar的mul_sentences（多句例子）
        for mul_sent_group in grammar.get("mul_sentences", []):
            # 为每个多句组创建group
            cursor.execute("""
                INSERT INTO sentence_group (chapter, type, title)
                VALUES (?, ?, NULL)
            """, (chapter, "grammar_example"))
            group_id = cursor.lastrowid
            
            # 插入该组内的每一句
            for seq_no, sent in enumerate(mul_sent_group.get("sentences", []), start=1):
                cursor.execute("""
                    INSERT INTO sentence (chapter, group_id, jp_sentence, jp_sentence_seg, chinese, seq_no)
                    VALUES (?, ?, ?, NULL, ?, ?)
                """, (chapter, group_id, sent.get("sentence"), sent.get("chinese"), seq_no))
            
            # 关联到grammar
            cursor.execute("""
                INSERT INTO grammar_group_sentence (grammar_id, group_id)
                VALUES (?, ?)
            """, (grammar_id, group_id))
    
    conn.commit()


def import_all_chapters(start: int = 1, end: int = 25):
    """导入指定范围的章节数据（默认 1~25）。"""
    init_database()
    conn = sqlite3.connect(DB_PATH)
    
    for chapter_num in range(start, end + 1):
        print(f"\n正在导入第 {chapter_num} 章...")
        data = load_json_chapter(chapter_num)
        
        if data is None:
            continue
        
        try:
            # 导入words
            if "words" in data:
                insert_words(conn, data["words"], chapter_num)
                print(f"  ✓ 导入 {len(data['words'])} 个单词")
            
            # 导入sentences (单句)
            if "sentences" in data and data["sentences"]:
                insert_sentences(conn, data["sentences"], chapter_num)
                print(f"  ✓ 导入 {len(data['sentences'])} 个单句")
            
            # 导入mul_sentences (多句段落)
            if "mul_sentences" in data and data["mul_sentences"]:
                insert_mul_sentences(conn, data["mul_sentences"], chapter_num)
                print(f"  ✓ 导入 {len(data['mul_sentences'])} 个多句段落")
            
            # 导入dialogue (长对话)
            if "dialogue" in data and data["dialogue"]:
                insert_dialogue(conn, data["dialogue"], chapter_num)
                print(f"  ✓ 导入长对话")
            
            # 导入essay (文章)
            if "essay" in data and data["essay"]:
                insert_essay(conn, data["essay"], chapter_num)
                print(f"  ✓ 导入文章")
            
            # 导入grammar (语法)
            if "grammar" in data and data["grammar"]:
                insert_grammar(conn, data["grammar"], chapter_num)
                print(f"  ✓ 导入 {len(data['grammar'])} 个语法点")
        
        except Exception as e:
            print(f"  ✗ 导入第 {chapter_num} 章失败: {e}")
            conn.rollback()
            continue
    
    conn.close()
    print(f"\n✓ 所有数据导入完成！数据库位置: {DB_PATH}")


if __name__ == "__main__":
    import sys

    if len(sys.argv) >= 3:
        import_all_chapters(int(sys.argv[1]), int(sys.argv[2]))
    elif len(sys.argv) == 2:
        import_all_chapters(int(sys.argv[1]), int(sys.argv[1]))
    else:
        import_all_chapters()