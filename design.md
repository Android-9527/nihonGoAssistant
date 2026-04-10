


数据获取:[模板识别] [LLM-OCR] [数据清洗]
input：{课本图片或扫描PDF:大家的日语.pdf}
output：{序列化languageJSON数据}
[模板识别]：使用图片块以及图片的标注，训练目标检测网络自动识别书本中的grammar/word/sentence/dialogue/essay的{内容图片块:datapre/extracted_blocks}
[LLM-OCR]：使用Google Gemini 2.5 Flash Api识别图片块中的内容。自动化识别脚本，编写不同模块的识别prompt得到规范化的输出grammar/word/sentence/dialogue/essay的文本内容{文本数据language_dataJSON}。
[数据清洗]：去除单词模块假名中不需要的符号，去除括号的解释。等。。。看到什么异常就写脚本清洗纠正。然后优化OCR以及序列化的prompt。

数据处理：[数据入库] [发音TTS] [句子分词] [语法标注] [单词标注]
input：{序列化languageJSON数据}
output：{数据库表：}
[数据入库]：将JSON数据保存到数据库中。{grammar,sentence,word,grammar_group_sentence,sentence_group}
[发音TTS]：使用Google Text2Speech模型，脚本批量计算word和sentence的发音。{tts_audio}
[句子分词]：使用fugashi将日语句子分词为多个词块(token),根据本章单词，合并一些细粒度分词做最长匹配优先，以便句子的分词可以和本章单词表的单词匹配.{sentence}
[语法标注]：根据语法模板关键词，模板匹配本章包含此语法的句子。对于偏语义理解的语法，使用LLM输入语法解释和例句，以及匹配prompt输出句子分词中匹配的语法。建立语法和例句分词的关系，将例句中的语法高亮。{sentence_word_grammar}
[单词标注]：建立本章中单词和句子的联系，将句子分词与单词表单词匹配，高亮句子中单词。{sentence_word_grammar}

前端vue：[主页] [关于] [捐赠]
[关于]：[关于项目] [关于作者]
[捐赠]：【[Alipay打赏作者]
[主页]：[我的课本] [我的单词] [我的语法] [我的复习]
[我的课本]：[课本列表]->[章节页]->[学习路径也页]->[单词] [语法] [课文] [测试]
[我的单词]：[搜索框] [隐藏/显示：假名、汉字、中文] [乱序] [单词列表项]
[我的语法]：[搜索框] [语法卡片]

后端djongo api


后端djongo api



1. 数据表（核心）
    1.1 内容数据
        word, grammar, sentence, sentence_group, sentence_word_grammar, grammar_group_sentence
    1.2 音频数据
        tts_audio（word/sentence 音频路径、时长、生成时间）
    1.3 学习行为
        user_answer_log（用户答题日志）
        user_element_mastery（用户元素掌握度）
        user_review_queue（用户待复习队列）

2. 内容接口（只读）
    2.1 GET /api/words?chapter=
    2.2 GET /api/word/{id}/sentences
    2.3 GET /api/grammar?chapter=
    2.4 GET /api/sentences?chapter=
    2.5 GET /api/audio/word/{id}
    2.6 GET /api/audio/sentence/{id}
    要求：句子接口返回 group_id/group_type/group_title/speaker/content/tokens。

3. 学习行为接口（写入）
    3.1 POST /api/review/unknown-tokens
        输入：sentence_id, token_index列表, chapter, timestamp
        作用：记录不懂分词，触发掌握度下降。
    3.2 POST /api/test/submit
        输入：题目结果、用时、正确率
        作用：更新 word/grammar/sentence 的掌握度。
    3.3 GET /api/review/recommendations
        输出：推荐复习单词、语法、句组（含原因）。

4. 熟练度和推荐计算（后端）
    4.1 掌握度
        基于最近答题正确率、错误次数、时间衰减。
    4.2 推荐分
        推荐分 = 重要程度权重 + (1-掌握度)权重 + 最近错误权重 + 超期权重。
    4.3 错题回流
        测试错题自动加入复习队列并提高优先级。

5. 后端工程要求
    5.1 CORS 仅放行前端域名。
    5.2 环境区分开发/生产配置（数据库路径、日志级别）。
    5.3 提供健康检查接口 GET /api/health。
    5.4 对关键接口增加索引和分页能力。



{
  "database_schema": {
    "words": [
      "id",
      "kana",
      "kanji",
      "chinese",
      "importance",
      "proficiency"
    ],
    "sentence": [
      "id",
      "chapter",
      "grid",
      "japanese",
      "japanse_seg",
      "chinese",
      "importance",
      "proficiency"
    ],
    "grammar": [
      "id",
      "chapter",
      "template",
      "explanation",
      "proficiency",
      "importance",
      "proficiency"
    ],
    "grammar_sentence": [
      "id",
      "grammar_id",
      "sentence_id"
    ],
    "sentence_word_grammar": [
      "id",
      "grammar_id",
      "sentence_id",
      "word_id",
      "surface",
      "pos",
      "token_index"
    ],
    "sentence_group": [
      "group_id",
      "chapter",
      "type",
      "title"
    ],
    "tts_audio": [
      "id",
      "entity_type",
      "entity_id",
      "chapter",
      "language",
      "encoding",
      "file_path"
    ]
  }
}
