# 对json保存的数据库的数据库数据进行后处理
# 从数据库中sentence中读取jp_sentence 然后分词用这个分词 from fugashi import Tagger，只保留去除符号，结果保留在jp_sentence_seg
# 清洗word的kana的内容，去除符号，存在括号(Jakarta) (大阪)去掉括号以及括号内的内容
#　建立sentence和word之间的关系，关系在sentence_word_grammar表中，读取sentence的分词检测每个分词是否在word表中出现(优先匹配同一chapter的word)，token_index是当前分词在句子中的分词index
# 先用分词器分词
# 再做一轮“按词表合并”（同章词表优先，最长匹配优先）
# 用合并后的 token 去写 sentence_word_grammar，然后把sentence_seg再写会sentence表中。改一下这个代码

import sqlite3
import re
from pathlib import Path

try:
	from fugashi import Tagger
except ImportError:
	Tagger = None


DB_PATH = Path(__file__).resolve().parent / "nihon_assistant_data.db"


def clean_kana_text(text: str) -> str:
	"""清洗 kana：去掉括号内容并去除常见符号。"""
	cleaned = (text or "").strip()
	# 去掉半角/全角括号及其内部内容
	cleaned = re.sub(r"\([^)]*\)", "", cleaned)
	cleaned = re.sub(r"（[^）]*）", "", cleaned)
	# 去掉方括号，仅保留正文
	cleaned = cleaned.replace("[", "").replace("]", "")
	# 去掉常见符号和空白
	cleaned = re.sub(r"[~〜～\-一－—・･/\\.,?!！？。、「」『』【】〈〉《》…]+", "", cleaned)
	cleaned = re.sub(r"\s+", "", cleaned)
	return cleaned


def clean_word_kana(conn: sqlite3.Connection):
	"""清洗 word 表中的 kana 字段。"""
	cursor = conn.cursor()
	cursor.execute("SELECT id, kana FROM word ORDER BY id")
	rows = cursor.fetchall()

	updated_count = 0
	for word_id, kana in rows:
		new_kana = clean_kana_text(kana)
		if new_kana and new_kana != (kana or ""):
			cursor.execute("UPDATE word SET kana = ? WHERE id = ?", (new_kana, word_id))
			updated_count += 1

	conn.commit()
	print(f"✓ 已清洗 {updated_count} 条 word.kana")


def normalized_forms(text: str):
	"""返回可用于匹配的文本形式（原文+清洗后）。"""
	forms = []
	raw = (text or "").strip()
	if raw:
		forms.append(raw)
	cleaned = clean_kana_text(raw)
	if cleaned and cleaned not in forms:
		forms.append(cleaned)
	return forms


def build_word_lookup(conn: sqlite3.Connection):
	"""构建单词查找表：优先同章匹配，其次全库匹配。"""
	cursor = conn.cursor()
	cursor.execute("SELECT id, chapter, kana, kanji FROM word ORDER BY id")
	rows = cursor.fetchall()

	by_chapter = {}
	global_map = {}

	for word_id, chapter, kana, kanji in rows:
		chapter_map = by_chapter.setdefault(chapter, {})
		for text in (kana, kanji):
			for form in normalized_forms(text):
				if form and form not in chapter_map:
					chapter_map[form] = word_id
				if form and form not in global_map:
					global_map[form] = word_id

	return by_chapter, global_map


def find_word_id(token: str, chapter: int, by_chapter, global_map):
	"""按同章优先规则查找 token 对应的 word_id。"""
	chapter_map = by_chapter.get(chapter, {})
	for form in normalized_forms(token):
		if form in chapter_map:
			return chapter_map[form]
	for form in normalized_forms(token):
		if form in global_map:
			return global_map[form]
	return None


def contains_form(text: str, form_map) -> bool:
	"""判断文本的任一标准形是否在词表映射中。"""
	for form in normalized_forms(text):
		if form in form_map:
			return True
	return False


def merge_tokens_by_wordlist(tokens, chapter: int, by_chapter, global_map):
	"""按词表合并分词结果：同章优先，且最长匹配优先。"""
	chapter_map = by_chapter.get(chapter, {})
	merged = []
	i = 0
	n = len(tokens)

	while i < n:
		best_chapter = None
		best_global = None

		for j in range(n, i, -1):
			candidate = "".join(tokens[i:j])
			if not candidate:
				continue
			if best_chapter is None and contains_form(candidate, chapter_map):
				best_chapter = (j, candidate)
				break
			if best_global is None and contains_form(candidate, global_map):
				best_global = (j, candidate)

		if best_chapter is not None:
			j, candidate = best_chapter
			merged.append(candidate)
			i = j
			continue

		if best_global is not None:
			j, candidate = best_global
			merged.append(candidate)
			i = j
			continue

		merged.append(tokens[i])
		i += 1

	return merged


def rebuild_sentence_word_relations(conn: sqlite3.Connection):
	"""重建 sentence 和 word 的关系，写入 sentence_word_grammar。"""
	by_chapter, global_map = build_word_lookup(conn)
	cursor = conn.cursor()
	cursor.execute("SELECT id, chapter, jp_sentence_seg FROM sentence ORDER BY id")
	sentence_rows = cursor.fetchall()

	inserted_count = 0
	for sentence_id, chapter, jp_sentence_seg in sentence_rows:
		# 仅重建词汇关系，避免残留旧 token。
		cursor.execute(
			"DELETE FROM sentence_word_grammar WHERE sentence_id = ?",
			(sentence_id,),
		)

		seg = (jp_sentence_seg or "").strip("/")
		if not seg:
			continue

		tokens = [t for t in seg.split("/") if t]
		for token_index, token_surface in enumerate(tokens):
			word_id = find_word_id(token_surface, chapter, by_chapter, global_map)
			cursor.execute(
				"""
				INSERT INTO sentence_word_grammar (sentence_id, word_id, grammar_id, surface, token_index)
				VALUES (?, ?, NULL, ?, ?)
				""",
				(sentence_id, word_id, token_surface, token_index),
			)
			inserted_count += 1

	conn.commit()
	print(f"✓ 已重建 {inserted_count} 条 sentence_word_grammar 关系")


def should_keep_token(token) -> bool:
	"""判断分词结果是否需要保留。"""
	surface = token.surface.strip().strip("[]")
	if not surface:
		return False

	pos1 = getattr(token.feature, "pos1", "") or ""
	if pos1 == "補助記号":
		return False

	return True


def tokenize_sentence(sentence: str, tagger: Tagger):
	"""先使用分词器得到原始 token 列表（已去符号）。"""
	tokens = []
	for token in tagger(sentence):
		if should_keep_token(token):
			tokens.append(token.surface.strip().strip("[]"))
	return tokens


def build_segmented_text(tokens) -> str:
	"""将 token 列表拼接成 jp_sentence_seg。"""
	return "/".join(tokens)


def update_sentence_segments():
	"""读取 sentence 表中的 jp_sentence，并回写 jp_sentence_seg。"""
	if Tagger is None:
		raise RuntimeError("缺少 fugashi，请先安装: pip install fugashi[unidic-lite]")

	tagger = Tagger()
	conn = sqlite3.connect(DB_PATH)
	cursor = conn.cursor()

	clean_word_kana(conn)
	by_chapter, global_map = build_word_lookup(conn)

	cursor.execute("SELECT id, chapter, jp_sentence FROM sentence ORDER BY id")
	rows = cursor.fetchall()

	updated_count = 0
	for sentence_id, chapter, jp_sentence in rows:
		jp_sentence = jp_sentence or ""
		raw_tokens = tokenize_sentence(jp_sentence, tagger)
		merged_tokens = merge_tokens_by_wordlist(raw_tokens, chapter, by_chapter, global_map)
		jp_sentence_seg = build_segmented_text(merged_tokens)
		cursor.execute(
			"UPDATE sentence SET jp_sentence_seg = ? WHERE id = ?",
			(jp_sentence_seg, sentence_id),
		)
		updated_count += 1

	conn.commit()
	print(f"✓ 已更新 {updated_count} 条句子的 jp_sentence_seg")

	rebuild_sentence_word_relations(conn)
	conn.close()


if __name__ == "__main__":
	update_sentence_segments()