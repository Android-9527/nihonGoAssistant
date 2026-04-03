# 提取第三章的jp_sentence_seg和第三章的语法模板以及解释，对jp_sentence_seg进行对应语法标注。
#  结果就是句子中有对应本章语法，然后对应语法的分词高亮
# sentence_word_grammar中给句子的分词标注上本章对应的grammar_id
# 先做第三章我看看效果
# 参考nihonOCR.py方法来实现llm标注


# 对于比较好匹配的语法，使用模板匹配进行标准，对于涉及到语义例句的语法使用LLM批量标注。
#输入是一个章节语法和每个句子，输出是标注结果，粗粒度每次多上次一些句子将10句作为一个batch这样不至于访问太频繁而查询忙碌。 

import json
import os
import sqlite3
import time
from pathlib import Path

from google import genai


BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "nihon_assistant_data.db"
TARGET_CHAPTER = 4
MODEL = os.getenv("GENAI_MODEL", "gemini-2.5-flash")


def get_output_path(chapter: int) -> Path:
	return BASE_DIR / f"chapter{chapter}_highlight_preview.json"


def get_client() -> genai.Client:
	api_key = (
		os.getenv("GEMINI_API_KEY")
		or os.getenv("GOOGLE_API_KEY")
		or "AIzaSyCthY-uXtLJ8GdqYz-towq28MP1LwBO6v4"
	)
	if not api_key:
		raise ValueError("No API key found. Set GEMINI_API_KEY or GOOGLE_API_KEY.")
	return genai.Client(api_key=api_key)


def strip_code_fence(text: str) -> str:
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


def extract_json_block(text: str) -> str:
	start = text.find("{")
	end = text.rfind("}")
	if start == -1 or end == -1 or end <= start:
		return text
	return text[start : end + 1]


def parse_json_response(text: str) -> dict:
	cleaned = strip_code_fence(text)
	try:
		return json.loads(cleaned)
	except json.JSONDecodeError:
		return json.loads(extract_json_block(cleaned))


def normalize_matches_payload(payload) -> list[dict]:
	"""Normalize model output to a flat list of match dicts."""
	if isinstance(payload, dict):
		matches = payload.get("matches", [])
	elif isinstance(payload, list):
		matches = payload
	else:
		return []

	flat: list[dict] = []
	stack = [matches]
	while stack:
		item = stack.pop()
		if isinstance(item, dict):
			flat.append(item)
		elif isinstance(item, list):
			stack.extend(item)

	return flat


def load_grammar_rows(conn: sqlite3.Connection, chapter: int) -> list[dict]:
	cursor = conn.cursor()
	cursor.execute(
		"SELECT id, template, explanation FROM grammar WHERE chapter = ? ORDER BY id",
		(chapter,),
	)
	rows = cursor.fetchall()
	result = []
	for grammar_id, template, explanation in rows:
		result.append(
			{
				"grammar_id": grammar_id,
				"template": (template or "").strip(),
				"explanation": (explanation or "").strip(),
			}
		)
	return result


def load_sentences(conn: sqlite3.Connection, chapter: int) -> list[dict]:
	cursor = conn.cursor()
	cursor.execute(
		"""
		SELECT id, jp_sentence, COALESCE(jp_sentence_seg, '')
		FROM sentence
		WHERE chapter = ?
		ORDER BY id
		""",
		(chapter,),
	)
	rows = cursor.fetchall()

	result = []
	for sentence_id, jp_sentence, jp_sentence_seg in rows:
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


def build_prompt_batch(chapter: int, sentences: list[dict], grammars: list[dict]) -> str:
	"""为一批句子构建prompt，语法规则只发一次"""
	grammar_json = json.dumps(grammars, ensure_ascii=False)
	sentences_data = [
		{
			"sentence_id": s["sentence_id"],
			"jp_sentence_seg": s["jp_sentence_seg"],
			"tokens": s["tokens"],
		}
		for s in sentences
	]
	sentences_json = json.dumps(sentences_data, ensure_ascii=False)

	return (
		"你是日语语法分词标注助手。\n"
		"任务: 根据给定语法信息(含grammar_id/template/explanation)，判断多个句子中哪些token应高亮。\n"
		"输出必须是严格JSON，不要markdown，不要解释。\n"
		"\n"
		f"chapter={chapter}\n"
		f"sentences_batch={sentences_json}\n"
		"\n"
		"grammar_list_json:\n"
		+ grammar_json
		+ "\n\n"
		"返回格式:\n"
		"{\n"
		"  \"matches\": [\n"
		"    {\"sentence_id\": 123, \"grammar_id\": 9, \"token_indices\": [2,4], \"template\": \"...\"}\n"
		"  ]\n"
		"}\n"
		"要求:\n"
		"1) token_indices 必须是0基索引。\n"
		"2) 只返回实际命中的语法。\n"
		"3) grammar_id 必须来自给定 grammar_list_json。\n"
		"4) 不确定时宁可不标。\n"
	)


def infer_batch_matches(client: genai.Client, chapter: int, sentences: list[dict], grammars: list[dict]) -> list[dict]:
	"""批量推理，一次API调用处理多个句子"""
	prompt = build_prompt_batch(chapter, sentences, grammars)
	max_retries = 5
	base_wait = 2
	
	for attempt in range(max_retries):
		try:
			response = client.models.generate_content(model=MODEL, contents=prompt)
			parsed = parse_json_response(response.text or "")
			time.sleep(0.5)  # 请求间延迟
			return normalize_matches_payload(parsed)
		except Exception as e:
			error_str = str(e)
			# Check for rate limiting or service unavailable errors
			if "503" in error_str or "UNAVAILABLE" in error_str:
				if attempt < max_retries - 1:
					wait_time = base_wait * (2 ** attempt)
					print(f"⏳ API触发限流 (503 UNAVAILABLE)，等待 {wait_time}s 后重试... [尝试 {attempt + 1}/{max_retries}]")
					time.sleep(wait_time)
					continue
			# For other errors or final retry, raise
			raise


def keep_valid_matches(matches: list[dict], sentence_id: int, token_len: int, grammar_id_set: set[int]) -> list[dict]:
	result = []
	for match in matches:
		if int(match.get("sentence_id", -1)) != sentence_id:
			continue
		grammar_id = match.get("grammar_id")
		if not isinstance(grammar_id, int) or grammar_id not in grammar_id_set:
			continue
		token_indices = match.get("token_indices", [])
		if not isinstance(token_indices, list):
			continue
		valid_indices = []
		for idx in token_indices:
			if isinstance(idx, int) and 0 <= idx < token_len:
				valid_indices.append(idx)
		if not valid_indices:
			continue
		result.append(
			{
				"sentence_id": sentence_id,
				"grammar_id": grammar_id,
				"template": match.get("template", ""),
				"token_indices": sorted(set(valid_indices)),
			}
		)
	return result


def annotate_chapter_with_llm(chapter: int = TARGET_CHAPTER, batch_size: int = 10) -> None:
	"""批量处理章节标注，减少API请求次数"""
	if not DB_PATH.exists():
		raise FileNotFoundError(f"DB not found: {DB_PATH}")

	client = get_client()
	conn = sqlite3.connect(DB_PATH)
	try:
		grammars = load_grammar_rows(conn, chapter)
		if not grammars:
			raise RuntimeError(f"No grammar rows found in DB for chapter {chapter}")
		grammar_id_set = {g["grammar_id"] for g in grammars}

		sentences = load_sentences(conn, chapter)
		total_matches = 0
		preview_rows = []

		# 按 batch_size 分批处理
		for batch_start in range(0, len(sentences), batch_size):
			batch_end = min(batch_start + batch_size, len(sentences))
			batch_sentences = sentences[batch_start:batch_end]

			print(f"  处理第 {batch_start + 1}-{batch_end} 句...", end=" ", flush=True)

			raw_matches = infer_batch_matches(client, chapter, batch_sentences, grammars)
			if raw_matches and not all(isinstance(m, dict) for m in raw_matches):
				raw_matches = normalize_matches_payload(raw_matches)

			# 为每个句子处理匹配结果
			for sentence in batch_sentences:
				sentence_matches = [m for m in raw_matches if int(m.get("sentence_id", -1)) == sentence["sentence_id"]]
				valid_matches = keep_valid_matches(
					sentence_matches,
					sentence_id=sentence["sentence_id"],
					token_len=len(sentence["tokens"]),
					grammar_id_set=grammar_id_set,
				)
				total_matches += len(valid_matches)
				preview_rows.append(
					{
						"sentence_id": sentence["sentence_id"],
						"jp_sentence": sentence["jp_sentence"],
						"jp_sentence_seg": sentence["jp_sentence_seg"],
						"tokens": sentence["tokens"],
						"matches": valid_matches,
					}
				)
			print("✓")

		payload = {
			"chapter": chapter,
			"model": MODEL,
			"grammar_list": grammars,
			"sentence_count": len(sentences),
			"match_count": total_matches,
			"results": preview_rows,
		}
		output_path = get_output_path(chapter)
		output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
		print(f"✅ 第{chapter}章完成。匹配={total_matches}，输出={output_path}")
	finally:
		conn.close()


if __name__ == "__main__":
	print("开始标注第16-25章...")
	for chapter in range(16, 26):
		try:
			print(f"\n📖 处理第{chapter}章...")
			annotate_chapter_with_llm(chapter)
		except Exception as e:
			print(f"❌ 第{chapter}章出错: {e}")
			continue
	print("\n🎉 第16-25章处理完成！")






