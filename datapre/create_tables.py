"""
创建 SQLite 数据库和表结构
表设计：
- word: 单词表
- sentence_group: 句子组表（用于区分单句、多句对话、课文、长对话等）
- sentence: 句子表
- grammar: 语法表
- grammar_group_sentence: 语法与句子组的关系表
- sentence_word_grammar: 句子中的词汇和语法标记表
"""

import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).resolve().parent / "nihon_assistant_data.db"


def create_tables():
    """创建 SQLite 数据库和所有表"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # 1. word 表 - 单词表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS word (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chapter INTEGER NOT NULL,
            kana TEXT NOT NULL,
            kanji TEXT NOT NULL,
            chinese TEXT NOT NULL
        );
    """)

    # 2. sentence_group 表 - 句子组表（用于区分单句、多句对话、课文等）
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS sentence_group (
            group_id INTEGER PRIMARY KEY AUTOINCREMENT,
            chapter INTEGER NOT NULL,
            type TEXT NOT NULL,
            title TEXT
        );
    """)

    # 3. sentence 表 - 句子表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS sentence (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chapter INTEGER NOT NULL,
            group_id INTEGER NOT NULL,
            jp_sentence TEXT NOT NULL,
            jp_sentence_seg TEXT,
            chinese TEXT NOT NULL,
            seq_no INTEGER NOT NULL DEFAULT 1,
            speaker TEXT,
            FOREIGN KEY (group_id) REFERENCES sentence_group(group_id) ON DELETE CASCADE
        );
    """)

    # 4. grammar 表 - 语法表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS grammar (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chapter INTEGER NOT NULL,
            template TEXT NOT NULL,
            explanation TEXT NOT NULL
        );
    """)

    # 5. grammar_group_sentence 表 - 语法与句子组的关系表
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS grammar_group_sentence (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            grammar_id INTEGER NOT NULL,
            group_id INTEGER NOT NULL,
            FOREIGN KEY (grammar_id) REFERENCES grammar(id) ON DELETE CASCADE,
            FOREIGN KEY (group_id) REFERENCES sentence_group(group_id) ON DELETE CASCADE,
            UNIQUE(grammar_id, group_id)
        );
    """)

    # 6. sentence_word_grammar 表 - 句子中的词汇和语法标记表
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
            FOREIGN KEY (grammar_id) REFERENCES grammar(id) ON DELETE SET NULL,
            UNIQUE(sentence_id, token_index)
        );
    """)

    # 创建索引以提高查询性能
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_word_chapter ON word(chapter);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_word_kana ON word(kana);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_word_kanji ON word(kanji);")
    
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_sentence_group_chapter ON sentence_group(chapter);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_sentence_group_type ON sentence_group(type);")
    
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_sentence_chapter ON sentence(chapter);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_sentence_group_id ON sentence(group_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_sentence_group_seq ON sentence(group_id, seq_no);")
    
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_grammar_chapter ON grammar(chapter);")
    
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_sentence_word_grammar_sentence ON sentence_word_grammar(sentence_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_sentence_word_grammar_word ON sentence_word_grammar(word_id);")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_sentence_word_grammar_grammar ON sentence_word_grammar(grammar_id);")

    conn.commit()
    print(f"✓ 数据库创建成功: {DB_PATH}")
    print_table_info(conn)
    conn.close()


def print_table_info(conn):
    """打印所有表的结构信息"""
    cursor = conn.cursor()
    
    tables = [
        "word",
        "sentence_group",
        "sentence",
        "grammar",
        "grammar_group_sentence",
        "sentence_word_grammar"
    ]
    
    print("\n=== 表结构信息 ===\n")
    
    for table in tables:
        print(f"【{table}】")
        cursor.execute(f"PRAGMA table_info({table});")
        columns = cursor.fetchall()
        for col in columns:
            col_id, col_name, col_type, not_null, default_val, pk = col
            pk_mark = "🔑" if pk else "  "
            null_mark = "NOT NULL" if not_null else "NULL"
            print(f"  {pk_mark} {col_name:20s} {col_type:15s} {null_mark}")
        print()


if __name__ == "__main__":
    create_tables()
