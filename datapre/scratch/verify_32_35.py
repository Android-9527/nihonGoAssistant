# -*- coding: utf-8 -*-
import json, io, sys

KEYS = ["chapter","words","sentences","mul_sentences","dialogue","essay","grammar","warnings"]
problems = []

def check_item(it, where, allow_empty_chinese=False):
    ch = it.get("chapter"); sent = it.get("sentence"); zh = it.get("chinese")
    if not sent:
        problems.append(f"{where}: empty sentence")
    if not allow_empty_chinese and not zh:
        problems.append(f"{where}: empty chinese (sentence={sent!r})")

for n in range(32,36):
    p = rf"D:\project\nihonAssitant\datapre\language_data\chapter_{n}.json"
    d = json.load(io.open(p, encoding="utf-8"))
    if list(d.keys()) != KEYS:
        problems.append(f"ch{n}: top keys mismatch -> {list(d.keys())}")
    if d["chapter"] != n:
        problems.append(f"ch{n}: chapter field = {d['chapter']}")
    # words
    for i,w in enumerate(d["words"]):
        if set(w.keys()) != {"chapter","kana","kanji","chinese"}:
            problems.append(f"ch{n} word{i}: keys {list(w.keys())}")
        if not w["kana"] or not w["chinese"]:
            problems.append(f"ch{n} word{i}: kana/chinese empty {w}")
    # sentences
    for i,x in enumerate(d["sentences"]):
        check_item(x, f"ch{n} sentences{i}")
    # mul_sentences
    g_total=0
    for i,g in enumerate(d["mul_sentences"]):
        for j,x in enumerate(g["sentences"]):
            check_item(x, f"ch{n} mul{i}.{j}")
    # dialogue
    dlg_n = 0
    if d["dialogue"]:
        assert set(d["dialogue"].keys())=={"chapter","title","sentences"}
        dlg_n = len(d["dialogue"]["sentences"])
        for j,x in enumerate(d["dialogue"]["sentences"]):
            check_item(x, f"ch{n} dialogue{j}")
    # essay
    ess_n=0
    if d["essay"]:
        assert set(d["essay"].keys())=={"chapter","title","sentences"}
        ess_n = len(d["essay"]["sentences"])
        for j,x in enumerate(d["essay"]["sentences"]):
            check_item(x, f"ch{n} essay{j}")
    # grammar
    for i,g in enumerate(d["grammar"]):
        if set(g.keys()) != {"chapter","template","explanation","sentences","mul_sentences"}:
            problems.append(f"ch{n} grammar{i}: keys {list(g.keys())}")
        for j,x in enumerate(g["sentences"]):
            check_item(x, f"ch{n} grammar{i}.sent{j}")
        for j,m in enumerate(g["mul_sentences"]):
            for k,x in enumerate(m["sentences"]):
                allow = x["sentence"].startswith("[注]")
                check_item(x, f"ch{n} grammar{i}.mul{j}.{k}", allow_empty_chinese=allow)
    print(f"ch{n}: words={len(d['words'])} sentences={len(d['sentences'])} mul_groups={len(d['mul_sentences'])} "
          f"dialogue={dlg_n} essay={ess_n} grammar={len(d['grammar'])}")

print("----")
if problems:
    print("PROBLEMS:")
    for x in problems: print(" -", x)
    sys.exit(1)
else:
    print("ALL OK: no problems.")
