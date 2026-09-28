# -*- coding: utf-8 -*-
import json, io, sys

BASE = r"D:\project\nihonAssitant\datapre\language_data"
TOP = ["chapter","words","sentences","mul_sentences","dialogue","essay","grammar","warnings"]

def check_sentence(obj, fname, errs, allow_empty_cn=False):
    if not obj.get("sentence"):
        errs.append(f"{fname}: empty sentence text")
    if not allow_empty_cn and not obj.get("chinese"):
        errs.append(f"{fname}: empty chinese for sentence: {obj.get('sentence','')[:30]}")

for n in [44,45,46,47]:
    p = BASE + rf"\chapter_{n}.json"
    errs = []
    d = json.load(io.open(p, encoding="utf-8"))
    # top keys
    if list(d.keys()) != TOP:
        errs.append(f"top keys order/set mismatch: {list(d.keys())}")
    if d["chapter"] != n:
        errs.append(f"chapter field = {d['chapter']}")
    # words
    for wd in d["words"]:
        if not wd.get("kana") or not wd.get("chinese"):
            errs.append(f"word missing kana/chinese: {wd}")
        if list(wd.keys()) != ["chapter","kana","kanji","chinese"]:
            errs.append(f"word key order: {list(wd.keys())}")
    # sentences
    for sd in d["sentences"]:
        check_sentence(sd, f"ch{n} sentences", errs)
    # mul_sentences
    for g in d["mul_sentences"]:
        if list(g.keys()) != ["chapter","sentences"]:
            errs.append(f"mul group keys: {list(g.keys())}")
        for sd in g["sentences"]:
            check_sentence(sd, f"ch{n} mul", errs)
    # dialogue
    if d["dialogue"] is not None:
        if list(d["dialogue"].keys()) != ["chapter","title","sentences"]:
            errs.append(f"dialogue keys: {list(d['dialogue'].keys())}")
        for sd in d["dialogue"]["sentences"]:
            check_sentence(sd, f"ch{n} dialogue", errs)
    # essay
    if d["essay"] is not None:
        if list(d["essay"].keys()) != ["chapter","title","sentences"]:
            errs.append(f"essay keys: {list(d['essay'].keys())}")
        for sd in d["essay"]["sentences"]:
            check_sentence(sd, f"ch{n} essay", errs)
    # grammar
    for gm in d["grammar"]:
        if list(gm.keys()) != ["chapter","template","explanation","sentences","mul_sentences"]:
            errs.append(f"grammar keys: {list(gm.keys())}")
        if not gm.get("explanation"):
            errs.append(f"grammar empty explanation: {gm.get('template')}")
        for sd in gm["sentences"]:
            check_sentence(sd, f"ch{n} grammar.sentences", errs)
        for g in gm["mul_sentences"]:
            for sd in g["sentences"]:
                allow = str(sd.get("sentence","")).startswith("[注]") or str(sd.get("sentence","")).startswith("注")
                check_sentence(sd, f"ch{n} grammar.mul", errs, allow_empty_cn=allow)
    # stats
    dlg_n = len(d["dialogue"]["sentences"]) if d["dialogue"] else 0
    es_n = len(d["essay"]["sentences"]) if d["essay"] else 0
    print(f"ch{n}: words={len(d['words'])} sentences={len(d['sentences'])} "
          f"mul_groups={len(d['mul_sentences'])} dialogue={dlg_n} essay={es_n} grammar={len(d['grammar'])}")
    if errs:
        print("  ERRORS:")
        for e in errs:
            print("   -", e)
    else:
        print("  OK: all checks passed")
