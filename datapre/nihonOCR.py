import json
import os
import re
import time
from pathlib import Path

from google import genai


MODEL = os.getenv("GENAI_MODEL", "gemini-2.5-flash")
MAX_RETRIES = int(os.getenv("MAX_RETRIES", "4"))
RETRY_BASE_SECONDS = float(os.getenv("RETRY_BASE_SECONDS", "2"))


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


def try_parse_json(text: str) -> dict:
    return json.loads(text)


def extract_json_block(text: str) -> str:
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        return text
    return text[start : end + 1]


def repair_json_with_model(client: genai.Client, broken_text: str) -> str:
    repair_prompt = (
        "请将下面内容修复为严格合法JSON。"
        "要求: 只输出JSON本体，不要markdown，不要解释，不要额外文字。\n\n"
        "待修复内容:\n"
        f"{broken_text}"
    )
    response = client.models.generate_content(
        model=MODEL,
        contents=repair_prompt,
    )
    return strip_code_fence(response.text or "")


def parse_with_repair(client: genai.Client, text: str) -> dict:
    cleaned = strip_code_fence(text)

    try:
        return try_parse_json(cleaned)
    except json.JSONDecodeError:
        pass

    extracted = extract_json_block(cleaned)
    try:
        return try_parse_json(extracted)
    except json.JSONDecodeError:
        pass

    repaired = repair_json_with_model(client, extracted)
    return try_parse_json(repaired)


def is_retryable_error(msg: str) -> bool:
    upper_msg = (msg or "").upper()
    return (
        "503" in upper_msg
        or "UNAVAILABLE" in upper_msg
        or "429" in upper_msg
        or "RESOURCE_EXHAUSTED" in upper_msg
        or "RATE LIMIT" in upper_msg
    )


def extract_retry_delay_seconds(msg: str) -> float | None:
    patterns = [
        r"retry in\s+([0-9]+(?:\.[0-9]+)?)s",
        r"retryDelay'?:\s*'([0-9]+)s'",
    ]
    for pattern in patterns:
        matched = re.search(pattern, msg or "", flags=re.IGNORECASE)
        if matched:
            try:
                return float(matched.group(1))
            except ValueError:
                return None
    return None


def build_chapter_files(extracted_dir: Path, chapter: int) -> dict[str, list[Path]]:
    return {
        "dialogue": [extracted_dir / f"{chapter}_dialogue.png"],
        "grammar": [extracted_dir / f"{chapter}_grammar.png"],
        "words": [
            extracted_dir / f"{chapter}_word_1.png",
            extracted_dir / f"{chapter}_word_2.png",
        ],
        "sentences": [extracted_dir / f"{chapter}_sentences.png"],
        "essay": [extracted_dir / f"{chapter}_essay.png"],
    }


def collect_failed_images(warnings: list[str]) -> set[str]:
    failed_images = set()
    for warning in warnings:
        if not isinstance(warning, str) or not warning.startswith("Failed "):
            continue
        # Example: Failed 2_word_2.png: 503 UNAVAILABLE ...
        image_name = warning.split(":", 1)[0].replace("Failed ", "", 1).strip()
        if image_name.endswith(".png"):
            failed_images.add(image_name)
    return failed_images


def build_prompt(task_name: str, chapter: int) -> str:
    common_rules = (
        "你是日语教材OCR结构化助手。"
        "严格识别图片中的日文与中文，不要凭空编造。"
        "返回严格JSON，不要markdown，不要解释。"
        "所有字段名必须与要求一致。"
    )

    prompts = {
        "words": (
            f"{common_rules}"
            f"当前是第{chapter}章词汇页。"
            "输出格式:"
            '{"words":[{"chapter":3,"kana":"","kanji":"/或汉字或片假名英文","chinese":""}]}'
            "kana字段只写日语本体，不要写括号内容、，严禁输出'/'。"
            "括号里的英文或汉字(不能是←左箭头加上日语)如果存在，归入kanji字段，如果没有，kanji填'/'。"
            
            
        ),
        "sentences": (
            f"{common_rules}"
            f"当前是第{chapter}章例句页，包含文型单句和例文多句。"
            "输出格式:"
            '{"sentences":[{"chapter":3,"sentence":"","chinese":""}],'
            '"mul_sentences":[{"chapter":3,"sentences":[{"chapter":3,"sentence":"","chinese":""}]}]}'
            "单句进sentences，多句段落进mul_sentences。"
            "每个sentence都必须填写chinese中文翻译；若图片中没有中文，按日文句子准确翻译为自然中文后填入chinese。"
        ),
        "dialogue": (
            f"{common_rules}"
            f"当前是第{chapter}章长对话页。"
            "输出格式:"
            '{"dialogue":{"chapter":3,"title":"长对话的标题","sentences":[{"chapter":3,"sentence":"说话人:日语句子","chinese":""}]}}'
            "保留说话人姓名在sentence中。"
            "每句都必须填写chinese中文翻译；若图中无中文，请根据日文对话翻译后写入。"
        ),
        "essay": (
            f"{common_rules}"
            f"当前是第{chapter}章短文页。"
            "输出格式:"
            '{"essay":{"chapter":3,"title":"","sentences":[{"chapter":3,"sentence":"","chinese":""}]}}'
            "每句sentence都必须有chinese中文翻译；若图中无中文，请翻译后填入。"
        ),
        "grammar": (
            f"{common_rules}"
            f"当前是第{chapter}章语法页。"
            "输出格式:"
            '{"grammar":[{"chapter":3,"template":"","explanation":"",'
            '"sentences":[{"chapter":3,"sentence":"","chinese":""}],'
            '"mul_sentences":[{"chapter":3,"sentences":[{"chapter":3,"sentence":"","chinese":""}]}]}]}'
            "grammar中的所有例句都必须提供chinese中文翻译；若图中无中文，请按日文语义翻译后填写。"
        ),
    }
    return prompts[task_name]


def extract_from_image(client: genai.Client, image_path: Path, task_name: str, chapter: int) -> dict:
    prompt = build_prompt(task_name, chapter)
    with image_path.open("rb") as f:
        image_bytes = f.read()

    last_error = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = client.models.generate_content(
                model=MODEL,
                contents=[
                    {
                        "role": "user",
                        "parts": [
                            {"text": prompt},
                            {
                                "inline_data": {
                                    "mime_type": "image/png",
                                    "data": image_bytes,
                                }
                            },
                        ],
                    }
                ],
            )
            return parse_with_repair(client, response.text or "")
        except Exception as e:
            last_error = e
            err_msg = str(e)
            if attempt >= MAX_RETRIES or not is_retryable_error(err_msg):
                break

            retry_after = extract_retry_delay_seconds(err_msg)
            wait_seconds = retry_after if retry_after is not None else RETRY_BASE_SECONDS * attempt
            time.sleep(max(wait_seconds, 1.0))

    raise last_error


def normalize_words(words: list[dict], chapter: int, warnings: list[str], image_name: str) -> list[dict]:
    normalized = []
    for item in words:
        if not isinstance(item, dict):
            continue

        row = dict(item)
        row["chapter"] = chapter

        kana = str(row.get("kana", "")).strip()
        kanji = str(row.get("kanji", "")).strip()

        if "(" in kana:
            cleaned_kana = kana.split("(", 1)[0].strip()
            if cleaned_kana:
                row["kana"] = cleaned_kana
                warnings.append(
                    f"{image_name}: stripped parenthetical text from kana '{kana}' -> '{cleaned_kana}'"
                )
                kana = cleaned_kana

        if not kana or kana == "/":
            if kanji and kanji != "/":
                row["kana"] = kanji
                warnings.append(
                    f"{image_name}: detected missing kana, auto-filled from kanji='{kanji}'"
                )
            else:
                row["kana"] = ""
                warnings.append(
                    f"{image_name}: missing kana remains empty, please manual-check this row"
                )

        normalized.append(row)

    return normalized


def process_chapter(client: genai.Client, extracted_dir: Path, output_dir: Path, chapter: int) -> None:
    output_path = output_dir / f"chapter_{chapter}.json"
    chapter_files = build_chapter_files(extracted_dir, chapter)

    result = None
    failed_image_names = set()
    if output_path.exists():
        try:
            existing = json.loads(output_path.read_text(encoding="utf-8"))
            failed_image_names = collect_failed_images(existing.get("warnings", []))
            if not failed_image_names:
                print(f"Skip chapter {chapter}: output already exists -> {output_path.name}")
                return

            print(
                f"Retry chapter {chapter}: {len(failed_image_names)} failed image(s) in {output_path.name}"
            )
            existing_warnings = existing.get("warnings", [])
            cleaned_warnings = [
                w for w in existing_warnings if not (isinstance(w, str) and w.startswith("Failed "))
            ]
            existing["warnings"] = cleaned_warnings
            result = existing
        except Exception:
            # If existing output is broken, fall back to full chapter rebuild.
            failed_image_names = set()

    if result is None:
        result = {
            "chapter": chapter,
            "words": [],
            "sentences": [],
            "mul_sentences": [],
            "dialogue": None,
            "essay": None,
            "grammar": [],
            "warnings": [],
        }

    for task_name, image_paths in chapter_files.items():
        for image_path in image_paths:
            if failed_image_names and image_path.name not in failed_image_names:
                continue

            if not image_path.exists():
                result["warnings"].append(f"Missing image: {image_path.name}")
                continue

            try:
                parsed = extract_from_image(client, image_path, task_name, chapter)
            except Exception as e:
                result["warnings"].append(f"Failed {image_path.name}: {e}")
                continue

            if task_name == "words":
                normalized_words = normalize_words(
                    parsed.get("words", []),
                    chapter,
                    result["warnings"],
                    image_path.name,
                )
                result["words"].extend(normalized_words)
            elif task_name == "sentences":
                result["sentences"].extend(parsed.get("sentences", []))
                result["mul_sentences"].extend(parsed.get("mul_sentences", []))
            elif task_name == "dialogue":
                result["dialogue"] = parsed.get("dialogue")
            elif task_name == "essay":
                result["essay"] = parsed.get("essay")
            elif task_name == "grammar":
                result["grammar"].extend(parsed.get("grammar", []))

    output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Done. Output written to: {output_path}")
    if result["warnings"]:
        print("Warnings:")
        for msg in result["warnings"]:
            print(f"- {msg}")


def main() -> None:
    base_dir = Path(__file__).resolve().parent
    extracted_dir = base_dir / "extracted_pages"
    output_dir = base_dir / "language_data"
    output_dir.mkdir(parents=True, exist_ok=True)

    client = get_client()

    skip_chapters = {3, 7}
    for chapter in range(1, 26):
        if chapter in skip_chapters:
            print(f"Skip chapter {chapter}: excluded by rule")
            continue

        process_chapter(client, extracted_dir, output_dir, chapter)


if __name__ == "__main__":
    main()