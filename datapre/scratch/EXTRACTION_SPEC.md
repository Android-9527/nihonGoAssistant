# 第27~50课 JSON 提取规则（EXTRACTION SPEC）

## 1. 任务与模板
- 源文件：`D:\project\nihonAssitant\datapre\26to50data.md`（OCR 质量差的 markdown，共 5268 行，日文为假名注音混排、含 HTML table、部分章节标题缺失）。
- 输出：`D:\project\nihonAssitant\datapre\language_data\chapter_{n}.json`（UTF-8）。
- **硬参考模板（必须逐字段对齐，二者缺一不可）**：
  - `D:\project\nihonAssitant\datapre\language_data\chapter_26.json` —— 用户已确认的权威模板。
  - `D:\project\nihonAssitant\datapre\language_data\chapter_27.json` —— 组织者按 26 课规则亲手完成的种子，解析风格照它。
- 顶层键（顺序一致）：`chapter, words, sentences, mul_sentences, dialogue, essay, grammar, warnings`。warnings 一般留 `[]`；仅当遇到无法合理解读的 OCR 内容时写入说明。
- 子对象键顺序：word=`chapter,kana,kanji,chinese`；单句=`chapter,sentence,chinese`；dialogue/essay=`chapter,title,sentences`；grammar=`chapter,template,explanation,sentences,mul_sentences`。

## 2. 章节板块与标记（OCR 标记可能缺失/损坏，需自行核验）
- 文型：`## ぶん けい 文 型`（部分课缺失，直接从例文开始）。
- 例文：`## れい ぶん 例 文` / `## れい ふん 例 文`。
- 对话标题：`## <注音假名> <汉字标题>`（如 `## なん つく 何でも 作れるんですね`）。
- 单词：`## たんご 単語` / `## たん ご 単語`。
- 文法：`## ぶんぽう 文法` / `## ぶんぼう 文法`。
- 短文/读解文：位于文法之后的练习区，无固定标记（第26课形态：`## ほしであきひこさま 星出彰彦様`；第27课形态：`7.` 编号后的 `ドラえもん` 段落）。
- 缺失板块：dialogue/essay 缺失 → `null`；其余板块缺失 → 空数组。

## 3. words（单词）
- 词条形态：A) 文本两栏（左栏词条、右栏释义，词性在释义前）；B) `<table>`，td 为 `词条|〈词性〉|释义`。两种都要解析。
- 词条构成：注音假名 或 汉字/片假名本体 + `（括号内容：汉字/英文/←原形）` + 声调数字(0-6)。
- 规则：
  - `kana`：词条本体。注音假名形式取假名（如 `とり(鳥)1` → `とり`）；汉字/片假名本体形式取本体（如 `見えます(←見える2)` → `見えます`、`エドヤストア④` → `エドヤストア`）。行首 `▲` 去掉；`~` 符号：词条有括号汉字时归 kanji（如 `~べん（～弁）` → kana=`べん`），无括号时 kana 保留 `~`（如 `~しか` → `~しか`）。括号内注音不进 kana。
  - `kanji`：括号内内容原样保留（汉字/英文/←原形），并追加声调圈号（数字→圈号：0→⓪ 1→① 2→② 3→③ 4→④ 5→⑤ 6→⑥）。无括号且无声调 → `"/"`。
    - 例：`見えます(←見える2)` → kanji=`←見える②`；`とり(鳥)1` → `鳥①`；`いつか1` → `①`。
    - 多位数字声调（如 24、12、10）为 OCR 损坏，原样保留数字、不转圈号。
    - 明显 OCR 假名错误可修正（如 `ドラエもん` → `ドラえもん`，与正文一致为准）。
    - 括号内英文保留原文（如 `マンション(mansion)1` → kanji=`mansion①`）。
  - `chinese`：中文释义，**不含词性标签**（〈副〉〈動II〉〈名〉等一律去掉）。例句类词条（如 `山が見えます。`）按其释义翻译。
  - 词条前单独的注音残留行忽略（如 `おく` / `遅れます（←遅れる①）` 只取后者）。
  - 「単語」中的符号说明段（~、-、[ ]、▲、* 的含义说明）不要进 words。
  - OCR 挤行：多个词条挤在同一行/同一 td 时，按释义列数量拆开一一对齐（参照 chapter_26.json 中 `気分がいい*きぶん わる気分が悪い…` 的拆解）。
  - 例句行作词条时：`kana`=整句（去行内空格），`kanji`=`/`，`chinese`=释义或翻译。

## 4. sentences / mul_sentences（文型/例文）
- 文型（`ぶん けい 文 型` 下 `1. 2. 3.…`）：每条一句 → `sentences`。**源无中文，必须翻译**为自然中文。
- 例文（`れい ぶん 例 文` 下 `1. 2.…`）：问答（日文行 + `……`应答行）→ 每组一个 `mul_sentences` 元素，组内按序多条。应答句保留 `……` 前缀。源无中文 → 翻译。多轮（一问+多答/追加陈述）放同一组。
- 日文句子统一：去掉行内空格、合并断行，只保留正文；行内注音残留（正文前的注音行、句中的注音夹字）全部去掉。

## 5. dialogue / essay
- dialogue：标题行下正文。`title`=汉字标题（去注音假名、去空格）。每条 sentence 带 `说话人: ` 前缀（**全角冒号**），chinese 翻译。注音行忽略，断行合并。图片行（`![](...)`）忽略。
- essay：文法后练习区中的读解短文。`title` 取短文标题（无标题行时取首行主题词，如 `ドラえもん`）。sentences=正文按源文分条（一行一条；一行内多句合并一条），无说话人前缀。**排除**练习题元素：判断/选择（`1）（）…`）、示例（`例：（〇）…`）、写作指令（`8. …`）。短文署名（如 `山田太郎`）保留为一条。若该课练习区没有成段的读解短文 → essay=`null`。
- 缺失 → `null`。

## 6. grammar（文法）
- 每个 `## N. 标题` 一个条目。`template`=标题原文（去掉 `## N.` 前缀与空格）；`explanation`=源中文解释（同一条目下多段解释可合并，保持通顺、保留原意）；例句：
  - 带编号（①-⑳）的日文例句 → `sentences`（sentence 保留编号前缀）。日文与中文同处一行/相邻行时拆开：日文进 sentence、中文进 chinese。
  - 问答型（例句 + `……`应答）→ `mul_sentences`（保留编号与 `……`）。
  - `注`/`[注]` 开头的说明句 → `mul_sentences`，chinese 留空。
  - 活用表格（如可能动词活用表）不进例句；`例如：…` 类活用示例可进 sentences 并给说明性 chinese（如“(可能动词的活用变化示例)”）。
  - 该条目无例句 → `sentences:[]`、`mul_sentences:[]`。
- 条目边界：下一个 `## N.` 或练习区开始（出现 `1）2）3）` 带空括号填空、`例：`、`（ ）` 等练习标记，或从 `2）` 开头的练习题）即止。文法之后紧跟的练习题一律排除。
- 语法 explanation 里源自带中文直接采用；例句行源无中文的必须翻译（如 27 课 `① わたしは日本語を話します。` → `我说日语。`）。

## 7. 翻译与 OCR 修正
- 例文/对话/短文/文型源无中文 → 必须准确翻译为自然中文（参照 chapter_27.json 的翻译风格：口语自然、`「」`引用保留）。
- 单词、语法中文源自带 → 直接采用，可轻微整理。
- 所有 sentence/word 的 chinese 不得为空（语法中 `注` 类说明句可留空）。
- 明显 OCR 错误结合上下文修正：如 `たと例えば` → `たとえば`；`元元` 按 `元々（もともと）` 理解翻译。正文日文以合理读法为准。

## 8. 每章验证（必须执行，返回结果）
用 `D:\anaconda3\envs\agenthugging\python.exe` 逐章验证：
- 合法 JSON（`json.load` 成功，`io.open(...,encoding='utf-8')`）；
- 顶层 8 键齐全、`chapter` 字段正确；
- words 全部 `kana`、`chinese` 非空；sentences/mul_sentences/dialogue/essay 的 `chinese` 非空（语法中 `注` 类除外）；
- grammar 每条含 `template/explanation/sentences/mul_sentences`。
参考命令：
`D:\anaconda3\envs\agenthugging\python.exe -c "import json,io; d=json.load(io.open(r'<json路径>',encoding='utf-8')); print(d['chapter'], len(d['words']), len(d['sentences']), len(d['mul_sentences']), len(d['dialogue']['sentences']) if d['dialogue'] else 0, len(d['essay']['sentences']) if d['essay'] else 0, len(d['grammar']))"`

## 9. 交付报告（返回给组织者）
- 每个 chapter 文件的**绝对路径**；
- 每章统计：words 数 / sentences 数 / mul_sentences 组数 / dialogue 句数 / essay 句数 / grammar 条数；
- 遇到的异常与处理（若有）。
