"""按规则提取 PDF 指定页并保存为图片。"""

from concurrent.futures import ProcessPoolExecutor
import os
from pathlib import Path

import pymupdf


i_values = [23, 35, 47, 59, 71, 85, 97, 109, 121, 133, 149, 161, 173, 185, 197, 211, 223, 235, 247, 259, 273, 285, 297, 309, 321]
parts = ["sentences", "dialogue", "word_1", "word_2", "grammar_1", "grammar_2", "essay"]
offsets = [0, 1, 2, 3, 4, 5, 11]

# 初始章节号：前 1~24 章的图片已提取，本批从该章节开始编号
START_CHAPTER = 26
# 结束章节号（含）：超过该章节的条目不生成
END_CHAPTER = 50

# pdf_path = Path(r"C:\Users\22106\Downloads\oursnihongo.pdf")
pdf_path = Path(r"C:\Users\22106\Downloads\大家的日语初级2（第二版）.pdf")

out_dir = Path(__file__).resolve().parent / "extracted_pages"
out_dir.mkdir(exist_ok=True)

tasks = [
	(chapter, part, i + d)
	for chapter, i in enumerate(i_values, START_CHAPTER)
	if chapter <= END_CHAPTER
	for part, d in zip(parts, offsets)
]


def export_one(task):
	chapter, part, page_no = task
	with fitz.open(pdf_path) as doc:
		pix = doc.load_page(page_no - 1).get_pixmap(dpi=220)
		outfile = out_dir / f"{chapter}_{part}.png"
		pix.save(outfile)
	return f"saved: {outfile.name} <- page {page_no}"


if __name__ == "__main__":
	workers = min(8, (os.cpu_count() or 4))
	with ProcessPoolExecutor(max_workers=workers) as executor:
		for message in executor.map(export_one, tasks, chunksize=4):
			print(message)