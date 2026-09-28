# -*- coding: utf-8 -*-
import json, io, sys

base = r"D:\project\nihonAssitant\datapre\language_data\chapter_{}.json"
top_keys = ["chapter","words","sentences","mul_sentences","dialogue","essay","grammar","warnings"]

def check_sc(s):
    return s.get("sentence") and s.get("chinese") != ""  # 注类 chinese 允许空

for n in range(28, 32):
    p = base.format(n)
    d = json.load(io.open(p, encoding="utf-8"))
    errs = []
    if list(d.keys()) != top_keys:
        errs.append("顶层键顺序/内容不符: %s" % list(d.keys()))
    if d["chapter"] != n:
        errs.append("chapter 字段错误: %s" % d["chapter"])
    for i,w_ in enumerate(d["words"]):
        if not w_.get("kana") or not w_.get("chinese"):
            errs.append("words[%d] kana/chinese 空: %s" % (i,w_))
        if list(w_.keys()) != ["chapter","kana","kanji","chinese"]:
            errs.append("words[%d] 键异常" % i)
    for i,sn in enumerate(d["sentences"]):
        if not sn.get("chinese"): errs.append("sentences[%d] chinese空" % i)
    for i,m in enumerate(d["mul_sentences"]):
        for j,x in enumerate(m["sentences"]):
            if not x.get("chinese"): errs.append("mul[%d][%d] chinese空" % (i,j))
    if d["dialogue"]:
        for j,x in enumerate(d["dialogue"]["sentences"]):
            if not x.get("chinese"): errs.append("dialogue[%d] chinese空" % j)
    if d["essay"]:
        for j,x in enumerate(d["essay"]["sentences"]):
            if not x.get("chinese"): errs.append("essay[%d] chinese空" % j)
    for i,g in enumerate(d["grammar"]):
        for k in ["template","explanation","sentences","mul_sentences"]:
            if k not in g: errs.append("grammar[%d] 缺键 %s" % (i,k))
    # 统计
    ds = len(d["dialogue"]["sentences"]) if d["dialogue"] else 0
    es = len(d["essay"]["sentences"]) if d["essay"] else 0
    print("chapter=%d words=%d sentences=%d mul=%d dialogue=%d essay=%d grammar=%d"
          % (d["chapter"], len(d["words"]), len(d["sentences"]), len(d["mul_sentences"]),
             ds, es, len(d["grammar"])))
    if errs:
        print("  !! 错误:")
        for e in errs: print("    -", e)
    else:
        print("  OK 校验通过")
