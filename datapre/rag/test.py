import json
import re
from difflib import SequenceMatcher
from pathlib import Path

from llm_test import call_gemini

BASE_DIR = Path(__file__).resolve().parent
ROOT_DIR = BASE_DIR.parents[1]
ANNO_DIR = ROOT_DIR / "datapre" / "grammar_annotate"

DEFAULT_SENTENCE = ""


# 检索参数
TOP_K = 10
TEMPLATE_WEIGHT = 0.6
EXPLANATION_WEIGHT = 0.4
TEMPLATE_MIN_SCORE = 0.2
EXPLANATION_MIN_SCORE = 0.1


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


def prompt_input(label: str, default_value: str) -> str:
    value = input(f"{label} [{default_value}]: ").strip()
    return value or default_value


def load_grammar_index(chapters: range = range(1, 26)) -> list[dict]:
    rows = []
    for chapter in chapters:
        file_path = ANNO_DIR / f"chapter{chapter}_highlight_preview.json"
        if not file_path.exists():
            continue
        data = json.loads(file_path.read_text(encoding="utf-8"))
        for item in data.get("grammar_list", []):
            gid = item.get("grammar_id")
            if not isinstance(gid, int):
                continue
            rows.append(
                {
                    "unique_id": f"{chapter}:{gid}",
                    "chapter": chapter,
                    "grammar_id": gid,
                    "template": str(item.get("template", "")).strip(),
                    "explanation": str(item.get("explanation", "")).strip(),
                }
            )
    return rows


def score_template(input_pattern: str, template: str) -> float:
    return score_text_pair(input_pattern, template)


def score_explanation(input_explanation: str, explanation: str) -> float:
    return score_text_pair(input_explanation, explanation)


def retrieve(grammar_pattern: str, grammar_explanation: str, top_k: int = TOP_K) -> list[dict]:
    index = load_grammar_index()
    results = []

    for item in index:
        t_score = score_template(grammar_pattern, item["template"])
        e_score = score_explanation(grammar_explanation, item["explanation"])

        # 至少有一路达标才纳入候选
        if t_score < TEMPLATE_MIN_SCORE and e_score < EXPLANATION_MIN_SCORE:
            continue

        final_score = t_score * TEMPLATE_WEIGHT + e_score * EXPLANATION_WEIGHT
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


def main() -> None:
    print("请输入句子，程序会调用 LLM 返回语法模板和语法解释，然后执行检索。")
    input_sentence = prompt_input("句子", DEFAULT_SENTENCE)

    print("\n[INFO] 正在请求 LLM 生成语法模板和语法解释...")
    try:
        llm_result = call_gemini(input_sentence)
    except Exception as exc:
        print(f"[ERROR] LLM 调用失败: {exc}")
        return

    grammar_pattern = str(llm_result.get("grammar_pattern", "")).strip()
    grammar_explanation = str(llm_result.get("grammar_explanation", "")).strip()

    if not grammar_pattern and not grammar_explanation:
        print("[WARN] LLM 没有返回有效的 grammar_pattern / grammar_explanation")
        return

    print(f"\n句子: {input_sentence}")
    print(f"输入模板: {grammar_pattern}")
    print(f"输入解释: {grammar_explanation}")
    print(f"模板检索权重: {TEMPLATE_WEIGHT}, 解释检索权重: {EXPLANATION_WEIGHT}")
    print("\n=== 检索结果 (模板+解释) ===\n")

    matches = retrieve(
        grammar_pattern=grammar_pattern,
        grammar_explanation=grammar_explanation,
        top_k=TOP_K,
    )

    if not matches:
        print("无候选结果（可尝试降低 TEMPLATE_MIN_SCORE / EXPLANATION_MIN_SCORE）")
        return

    for i, m in enumerate(matches, 1):
        print(f"{i}. Chapter: {m['chapter']}, Grammar ID: {m['grammar_id']}")
        print(f"   模板: {m['template']}")
        print(f"   综合分: {m['final_score']:.2%}")
        print(
            "   得分拆解: "
            f"template={m['template_score']:.2%}*{TEMPLATE_WEIGHT}, "
            f"explanation={m['explanation_score']:.2%}*{EXPLANATION_WEIGHT}"
        )
        print(f"   解释: {m['explanation'][:120]}...")
        print()


if __name__ == "__main__":
    main()
