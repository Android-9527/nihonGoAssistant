"""按规则提取 PDF 指定页并保存为图片。"""

from concurrent.futures import ProcessPoolExecutor
import os
from pathlib import Path

import fitz


i_values = [27, 39, 51, 65, 77, 89, 101, 115, 127, 139, 151, 163, 179, 191, 203, 215, 229, 241, 253, 265, 277, 289, 303, 315, 327]
parts = ["sentences", "dialogue", "word_1", "word_2", "grammar_1", "grammar_2", "essay"]
offsets = [0, 1, 2, 3, 4, 5, 11]

pdf_path = Path(r"C:\Users\22106\Downloads\oursnihongo.pdf")
out_dir = Path(__file__).resolve().parent / "extracted_pages"
out_dir.mkdir(exist_ok=True)

tasks = [
	(chapter, part, i + d)
	for chapter, i in enumerate(i_values, 1)
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