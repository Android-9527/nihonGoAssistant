import json
import os
from pathlib import Path

import httpx
from google import genai
from google.genai import types

BASE_DIR = Path(__file__).resolve().parent
MODEL = os.getenv("GENAI_MODEL", "gemini-2.5-flash")
API_VERSION = os.getenv("GENAI_API_VERSION", "v1beta")
SSL_VERIFY = os.getenv("GENAI_SSL_VERIFY", "true").strip().lower() not in {"0", "false", "no", "off"}
HTTP_PROXY = (
    os.getenv("GENAI_HTTP_PROXY")
    or os.getenv("HTTP_PROXY")
    or os.getenv("HTTPS_PROXY")
    or "http://127.0.0.1:7897"
).strip() or None

# 直接改这里测试句子
INPUT_SENTENCE = "これはいくらですか"


def get_api_key() -> str:
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        raise ValueError("Missing GEMINI_API_KEY or GOOGLE_API_KEY in environment variables.")
    return api_key


def get_client() -> genai.Client:
    http_client = httpx.Client(
        verify=SSL_VERIFY,
        trust_env=True,
        proxy=HTTP_PROXY,
        timeout=httpx.Timeout(60.0, connect=20.0),
    )
    http_options = types.HttpOptions(apiVersion=API_VERSION, httpxClient=http_client)
    return genai.Client(api_key=get_api_key(), http_options=http_options)


def build_prompt(sentence: str) -> str:
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
        "1. grammar_pattern 用语法模板形式（如 名詞は場所にあります）。\n"
        "2. grammar_explanation 用中文的一段话解释这个语法\n"
        "3. 若句子语法不明显，也必须返回两个字段，使用最接近语法。\n"
        "\n"
        f"句子：{sentence}"
    )


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
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        data = json.loads(extract_json_block(cleaned))

    if not isinstance(data, dict):
        raise ValueError("Model response is not a JSON object.")

    return {
        "grammar_pattern": str(data.get("grammar_pattern", "")).strip(),
        "grammar_explanation": str(data.get("grammar_explanation", "")).strip(),
    }


def call_gemini(sentence: str) -> dict:
    client = get_client()
    prompt = build_prompt(sentence)

    config_kwargs = {"temperature": 0}
    if API_VERSION.lower() != "v1":
        config_kwargs["responseMimeType"] = "application/json"

    response = client.models.generate_content(
        model=MODEL,
        contents=prompt,
        config=types.GenerateContentConfig(**config_kwargs),
    )
    return parse_json_response(response.text or "")


def main() -> None:
    print(f"Model: {MODEL}")
    print(f"API Version: {API_VERSION}")
    print(f"Sentence: {INPUT_SENTENCE}")

    result = call_gemini(INPUT_SENTENCE)
    print("\n=== LLM JSON Result ===")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
