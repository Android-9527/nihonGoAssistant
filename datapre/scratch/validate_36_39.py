# -*- coding: utf-8 -*-
import json, io, sys

KEYS = ["chapter","words","sentences","mul_sentences","dialogue","essay","grammar","warnings"]
base = r"D:\project\nihonAssitant\datapre\language_data"

for n in [36,37,38,39]:
    p = base + ("\\chapter_%d.json" % n)
    d = json.load(io.open(p, encoding="utf-8"))
    errs = []
    if list(d.keys()) != KEYS:
        errs.append("top keys mismatch: %s" % list(d.keys()))
    if d["chapter"] != n:
        errs.append("chapter field=%s" % d["chapter"])
    for wd in d["words"]:
        if not wd.get("kana") or not wd.get("chinese"):
            errs.append("word empty kana/chinese: %s" % wd)
        if set(wd.keys()) != {"chapter","kana","kanji","chinese"}:
            errs.append("word keys: %s" % list(wd.keys()))
    for it in d["sentences"]:
        if not it.get("chinese"): errs.append("sentence empty zh: %s" % it)
    for m in d["mul_sentences"]:
        for it in m["sentences"]:
            # 注类 chinese 可空
            if not it.get("chinese") and not (it["sentence"].startswith("[注]") or "注" in it["sentence"][:3] or it["sentence"].startswith("×")):
                errs.append("mul sentence empty zh: %s" % it)
    for g in d["grammar"]:
        for k in ["template","explanation","sentences","mul_sentences"]:
            if k not in g: errs.append("grammar missing %s" % k)
    dg = d["dialogue"]; es = d["essay"]
    print("ch%d | words=%d sentences=%d mul_groups=%d dialogue=%d essay=%d grammar=%d warn=%d" % (
        n, len(d["words"]), len(d["sentences"]), len(d["mul_sentences"]),
        len(dg["sentences"]) if dg else -1,
        len(es["sentences"]) if es else -1,
        len(d["grammar"]), len(d["warnings"])))
    if errs:
        print("  ERRORS:")
        for e in errs: print("   -", e)
    else:
        print("  OK")
