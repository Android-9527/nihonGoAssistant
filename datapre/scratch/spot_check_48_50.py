# -*- coding: utf-8 -*-
import io, json

f = io.open(r'D:\project\nihonAssitant\datapre\26to50data.md', encoding='utf-8')
ls = f.readlines()

print('=== 源文 4784 (48课单词表1) ===')
print(ls[4783].rstrip())
print('=== 源文 4786 (48课单词表2) ===')
print(ls[4785].rstrip()[:1200])
print('=== 源文 4934 (49课单词表) ===')
print(ls[4933].rstrip()[:1200])

for n in (48, 49, 50):
    d = json.load(io.open(r'D:\project\nihonAssitant\datapre\language_data\chapter_%d.json' % n, encoding='utf-8'))
    print('\n=== chapter_%d words (%d) ===' % (n, len(d['words'])))
    print(' | '.join(w['kana'] for w in d['words']))
    print('dialogue.title:', d['dialogue']['title'])
    print('essay.title:', d['essay']['title'])
    print('warnings:', d['warnings'])
