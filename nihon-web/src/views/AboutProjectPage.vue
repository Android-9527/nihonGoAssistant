<template>
  <section class="about-page">
    <header class="hero">
      <h1>关于项目</h1>
      <p>Nihon Assistant 是一个面向日语学习的辅助工具。</p>
    </header>

    <article class="card">
      <h2>项目简介</h2>
      <p>项目围绕课本学习流程，提供单词、例句、语法和朗读能力，帮助学习者高频复习与巩固。</p>
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
</style>
