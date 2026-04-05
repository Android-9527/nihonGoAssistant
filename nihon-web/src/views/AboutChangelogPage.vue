<template>
  <section class="about-page">
    <header class="hero">
      <h1>版本更新</h1>
      <p>记录功能迭代与体验优化。</p>
    </header>

    <article class="card">
      <h2>v0.3.0</h2>
      <ul class="list">
        <li>课文模块支持 single / dialogue / essay 三类分组展示</li>
        <li>句子组支持标题显示，兼容 sentence_group.title</li>
        <li>单词、句子、语法例句由悬浮播音改为点击按钮播音</li>
      </ul>
    </article>

    <article class="card">
      <h2>v0.2.0</h2>
      <ul class="list">
        <li>首页新增随机复习区域，支持不懂分词点击标记</li>
        <li>新增我的单词/我的语法二级入口（本子 + 复习）</li>
        <li>语法与单词 token 支持点击跳转详情页</li>
      </ul>
    </article>

    <article class="card">
      <h2>v0.1.0</h2>
      <ul class="list">
        <li>完成课本、单词、语法、课文基础学习流</li>
        <li>完成后端词句语法查询 API 与前端页面联调</li>
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

.list {
  margin: 0;
  padding-left: 18px;
  color: #334155;
  line-height: 1.8;
}
</style>
