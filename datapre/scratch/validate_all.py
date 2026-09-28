# -*- coding: utf-8 -*-
import json, io, os

base = r'D:\project\nihonAssitant\datapre\language_data'
exp = ['chapter','words','sentences','mul_sentences','dialogue','essay','grammar','warnings']
issues = []
rows = []
for n in range(27, 51):
    p = os.path.join(base, 'chapter_%d.json' % n)
    if not os.path.exists(p):
        issues.append('chapter_%d.json MISSING' % n); continue
    try:
        d = json.load(io.open(p, encoding='utf-8'))
    except Exception as e:
        issues.append('ch%d invalid json: %s' % (n, e)); continue
    if list(d.keys()) != exp:
        issues.append('ch%d keys %s' % (n, list(d.keys())))
    if d['chapter'] != n:
        issues.append('ch%d chapter field=%s' % (n, d['chapter']))
    for w in d['words']:
        if not w.get('kana') or not w.get('chinese'):
            issues.append('ch%d word empty kana/chinese: %r' % (n, w))
        if w.get('chapter') != n:
            issues.append('ch%d word.chapter=%s' % (n, w.get('chapter')))
    for s in d['sentences']:
        if not s.get('chinese'):
            issues.append('ch%d sentence empty chinese: %s' % (n, s.get('sentence','')[:40]))
        if s.get('chapter') != n:
            issues.append('ch%d sentence.chapter' % n)
    for m in d['mul_sentences']:
        if m.get('chapter') != n:
            issues.append('ch%d mul.chapter' % n)
        for s in m['sentences']:
            if s.get('chapter') != n:
                issues.append('ch%d mul.inner chapter' % n)
            if not s.get('chinese'):
                issues.append('ch%d mul empty chinese: %s' % (n, s.get('sentence','')[:40]))
    for blk in ('dialogue','essay'):
        b = d[blk]
        if b is not None:
            if not isinstance(b, dict) or b.get('chapter') != n:
                issues.append('ch%d %s.chapter' % (n, blk))
            for s in b['sentences']:
                if not s.get('chinese'):
                    issues.append('ch%d %s empty chinese: %s' % (n, blk, s.get('sentence','')[:40]))
    for g in d['grammar']:
        for k in ('template','explanation','sentences','mul_sentences'):
            if k not in g:
                issues.append('ch%d grammar missing key %s' % (n, k))
        if g.get('chapter') != n:
            issues.append('ch%d grammar.chapter' % n)
        for s in g['sentences']:
            if s.get('sentence','').startswith('注'):
                continue
            if not s.get('chinese'):
                issues.append('ch%d grammar.s empty chinese: %s' % (n, s.get('sentence','')[:40]))
        for m in g['mul_sentences']:
            for s in m['sentences']:
                if s.get('sentence','').startswith('注'):
                    continue
                if not s.get('chinese'):
                    issues.append('ch%d grammar.m empty chinese: %s' % (n, s.get('sentence','')[:40]))
    rows.append((n, len(d['words']), len(d['sentences']), len(d['mul_sentences']),
                 len(d['dialogue']['sentences']) if d['dialogue'] else 0,
                 len(d['essay']['sentences']) if d['essay'] else 0,
                 len(d['grammar']), len(d['warnings'])))

print('chapter words sentences mul_groups dialogue essay grammar warnings')
for r in rows:
    print('  %d    %3d   %3d      %3d       %3d    %3d   %3d    %3d' % r)
print('TOTAL: %d files, words=%d sentences=%d mul_groups=%d dialogue_lines=%d essay_lines=%d grammar=%d' % (
    len(rows), sum(r[1] for r in rows), sum(r[2] for r in rows), sum(r[3] for r in rows),
    sum(r[4] for r in rows), sum(r[5] for r in rows), sum(r[6] for r in rows)))
print('ISSUES: %d' % len(issues))
for i in issues[:100]:
    print('  -', i)
