<template>
  <section class="about-page">
    <header class="hero">
      <h1>设计逻辑</h1>
      <p>从课本图片到可学习内容，再到复习推荐的端到端设计。</p>
    </header>

    <article class="card">
      <h2>1. 数据获取</h2>
      <p class="meta"><strong>input：</strong>课本图片或扫描 PDF（例如《大家的日语》）</p>
      <p class="meta"><strong>output：</strong>序列化 language JSON 数据</p>
      <ul class="list">
        <li><strong>模板识别：</strong>基于图片块标注训练检测模型，自动识别 grammar / word / sentence / dialogue / essay 区域（内容块目录如 datapre/extracted_blocks）。</li>
        <li><strong>LLM-OCR：</strong>使用 Gemini 2.5 Flash 按模块 Prompt 识别图片块，生成结构化文本（language_data JSON）。</li>
        <li><strong>数据清洗：</strong>清理假名噪声、括号解释等异常格式，持续迭代清洗脚本与 OCR Prompt。</li>
      </ul>
    </article>

    <article class="card">
      <h2>2. 数据处理</h2>
      <p class="meta"><strong>input：</strong>序列化 language JSON 数据</p>
      <p class="meta"><strong>output：</strong>数据库结构化数据</p>
      <ul class="list">
        <li><strong>数据入库：</strong>写入 grammar、sentence、word、grammar_group_sentence、sentence_group。</li>
        <li><strong>发音 TTS：</strong>批量计算 word 和 sentence 发音并存储到 tts_audio。</li>
        <li><strong>句子分词：</strong>使用 fugashi 分词，并按本章词表做最长匹配优先合并，提升词句对齐效果。</li>
        <li><strong>语法标注：</strong>结合模板匹配和 LLM 语义匹配，建立语法与句子 token 的关系用于高亮。</li>
        <li><strong>单词标注：</strong>建立章节词汇与句子 token 的映射关系，支持单词高亮与跳转。</li>
      </ul>
    </article>

    <article class="card">
      <h2>3. 前端 Vue 结构</h2>
      <ul class="list">
        <li><strong>全局入口：</strong>主页、关于、捐赠。</li>
        <li><strong>关于：</strong>设计逻辑、关于作者、版本更新。</li>
        <li><strong>主页：</strong>我的课本、我的单词、我的语法。</li>
        <li><strong>我的课本：</strong>课本列表 - 章节页 - 学习路径页 - 单词/语法/课文/测试。</li>
        <li><strong>我的单词：</strong>搜索、假名/汉字/中文显示控制、乱序、单词列表。</li>
        <li><strong>我的语法：</strong>搜索与语法卡片浏览。</li>
      </ul>
    </article>

    <article class="card">
      <h2>4. 后端 API 与数据表</h2>
      <p class="meta">当前工程实现为 Flask + SQLite，以下为核心数据与接口设计。</p>
      <h3>4.1 核心数据表</h3>
      <ul class="list">
        <li><strong>内容数据：</strong>word、grammar、sentence、sentence_group、sentence_word_grammar、grammar_group_sentence。</li>
        <li><strong>音频数据：</strong>tts_audio（word/sentence 音频路径、时长、生成时间）。</li>
        <li><strong>学习行为：</strong>user_answer_log、user_element_mastery、user_review_queue。</li>
      </ul>
      <h3>4.2 内容接口（只读）</h3>
      <ul class="list mono">
        <li>GET /api/words?chapter=</li>
        <li>GET /api/word/{id}/sentences</li>
        <li>GET /api/grammar?chapter=</li>
        <li>GET /api/sentences?chapter=</li>
        <li>GET /api/tts/audio?entity_type=word&amp;entity_id={id}</li>
        <li>GET /api/tts/audio?entity_type=sentence&amp;entity_id={id}</li>
      </ul>
      <p class="meta">句子接口要求返回 group_id / group_type / group_title / speaker / content / tokens。</p>
      <h3>4.3 学习行为接口（写入规划）</h3>
      <ul class="list mono">
        <li>POST /api/review/unknown-tokens</li>
        <li>POST /api/test/submit</li>
        <li>GET /api/review/recommendations</li>
      </ul>
    </article>

    <article class="card">
      <h2>5. 熟练度与推荐计算</h2>
      <ul class="list">
        <li><strong>掌握度：</strong>基于最近正确率、错误次数与时间衰减综合计算。</li>
        <li><strong>推荐分：</strong>重要程度权重 + (1 - 掌握度)权重 + 最近错误权重 + 超期权重。</li>
        <li><strong>错题回流：</strong>测试错题自动加入复习队列并提高优先级。</li>
      </ul>
    </article>

    <article class="card">
      <h2>6. 后端工程要求</h2>
      <ul class="list">
        <li>CORS 仅放行前端域名。</li>
        <li>区分开发/生产配置（数据库路径、日志级别）。</li>
        <li>提供健康检查接口：GET /api/health。</li>
        <li>关键接口支持索引与分页能力。</li>
      </ul>
    </article>
  </section>
</template>

<style scoped>
.about-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.hero {
  background: linear-gradient(135deg, #e0f2fe, #eef2ff 55%, #fef9c3);
  border: 1px solid #cbd5e1;
  border-radius: 16px;
  padding: 22px;
}

.hero h1 {
  margin: 0;
  color: #0f172a;
}

.hero p {
  margin: 6px 0 0;
  color: #334155;
}

.card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 18px;
}

.card h2 {
  margin: 0 0 8px;
  color: #0f172a;
}

.card p {
  margin: 0;
  color: #334155;
  line-height: 1.7;
}

.meta {
  margin: 6px 0;
  color: #334155;
}

.card h3 {
  margin: 14px 0 8px;
  color: #1e293b;
}

.list {
  margin: 8px 0 0;
  padding-left: 18px;
  color: #334155;
  line-height: 1.8;
}

.mono {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace;
}
</style>
