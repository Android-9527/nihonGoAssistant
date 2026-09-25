<template>
  <section class="about-page">
    <header class="hero">
      <h1>版本更新</h1>
      <p>记录功能迭代与体验优化。</p>
    </header>

    <p v-if="loadError" class="load-error">{{ loadError }}</p>
    <p v-else-if="!versions.length" class="load-error">暂无更新记录</p>

    <article v-for="item in versions" :key="item.version" class="card">
      <div class="card-head">
        <h2>{{ item.version }}</h2>
        <span v-if="item.date" class="card-date">{{ item.date }}</span>
      </div>
      <ul class="list">
        <li v-for="(change, idx) in item.changes" :key="idx">{{ change }}</li>
      </ul>
    </article>
  </section>
</template>

<script>
export default {
  data() {
    return {
      versions: [],
      loadError: '',
    };
  },
  async mounted() {
    try {
      const response = await fetch('/data/changelog.json');
      if (!response.ok) throw new Error('加载失败');
      const data = await response.json();
      this.versions = Array.isArray(data?.versions) ? data.versions : [];
    } catch (error) {
      this.loadError = '更新日志加载失败';
    }
  },
};
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

.card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 18px;
}

.card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 8px;
}

.card h2 {
  margin: 0;
  color: #0f172a;
}

.card-date {
  flex-shrink: 0;
  padding: 3px 10px;
  background: #f1f5f9;
  color: #64748b;
  border-radius: 999px;
  font-size: 12px;
}

.list {
  margin: 0;
  padding-left: 18px;
  color: #334155;
  line-height: 1.8;
}

.load-error {
  margin: 0;
  padding: 40px 20px;
  text-align: center;
  color: #9ca3af;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
}
</style>
