<template>
  <section class="about-page">
    <header class="hero">
      <h1>关于</h1>
      <p>请选择你想查看的内容入口。</p>
    </header>

    <div class="entry-grid">
      <article class="entry-card" @click="go('/about/project')">
        <h2>关于项目</h2>
        <p>查看 Nihon Assistant 的定位、功能与目标。</p>
      </article>

      <article class="entry-card" @click="go('/about/author')">
        <h2>关于作者</h2>
        <p>查看作者介绍与项目维护说明。</p>
      </article>
    </div>
  </section>
</template>

<script>
export default {
  methods: {
    go(path) {
      this.$router.push(path)
    },
  },
}
</script>

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

.entry-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 14px;
}

.entry-card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 18px;
  cursor: pointer;
  transition: 0.2s ease;
}

.entry-card:hover {
  transform: translateY(-2px);
  border-color: #94a3b8;
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.08);
}

.entry-card h2 {
  margin: 0 0 8px;
  color: #0f172a;
}

.entry-card p {
  margin: 0;
  color: #334155;
  line-height: 1.7;
}
</style>
