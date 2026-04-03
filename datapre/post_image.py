# 拼接语法1，2，有些不垂直拼接的语法可能导致识别失败

from pathlib import Path

from PIL import Image


def merge_vertical(img1_path: Path, img2_path: Path, out_path: Path) -> None:
	with Image.open(img1_path) as img1, Image.open(img2_path) as img2:
		width = max(img1.width, img2.width)
		height = img1.height + img2.height

		# Keep original images unchanged; pad with white when widths differ.
		merged = Image.new("RGB", (width, height), color="white")
		x1 = (width - img1.width) // 2
		x2 = (width - img2.width) // 2

		merged.paste(img1.convert("RGB"), (x1, 0))
		merged.paste(img2.convert("RGB"), (x2, img1.height))
		merged.save(out_path)


def main() -> None:
	base_dir = Path(__file__).resolve().parent / "extracted_pages"
	if not base_dir.exists():
		raise FileNotFoundError(f"Directory not found: {base_dir}")

	part1_images = sorted(base_dir.glob("*_grammar_1.png"), key=lambda p: int(p.stem.split("_")[0]))

	merged_count = 0
	skipped = []
	for img1_path in part1_images:
		chapter = img1_path.stem.split("_")[0]
		img2_path = base_dir / f"{chapter}_grammar_2.png"
		out_path = base_dir / f"{chapter}_grammar.png"

		if not img2_path.exists():
			skipped.append(chapter)
			continue

		merge_vertical(img1_path, img2_path, out_path)
		merged_count += 1

	print(f"Merged {merged_count} chapter grammar images.")
	if skipped:
		print("Skipped chapters (missing _grammar_2):", ", ".join(skipped))


if __name__ == "__main__":
	main()
