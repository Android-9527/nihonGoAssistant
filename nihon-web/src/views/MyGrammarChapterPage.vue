<template>
  <section class="chapters-wrap">
    <header>
      <h1>我的语法</h1>
      <p>请选择章节进入语法学习。</p>
    </header>

    <div class="chapters-grid">
      <button v-for="n in 25" :key="n" class="chapter-btn" @click="open(n)">
        第 {{ n }} 章
      </button>
    </div>
  </section>
</template>

<script>
export default {
  methods: {
    open(chapter) {
      this.$router.push(`/grammar?chapter=${chapter}`);
    },
  },
};
</script>

<style scoped>
.chapters-wrap { display: flex; flex-direction: column; gap: 12px; }
header h1 { margin: 0; }
header p { margin: 6px 0 0; color: #475569; }

.chapters-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
  gap: 10px;
}

.chapter-btn {
  border: 1px solid #cbd5e1;
  background: #fff;
  border-radius: 10px;
  padding: 12px;
  cursor: pointer;
}

.chapter-btn:hover {
  border-color: #eab308;
  background: #fefce8;
}
</style>
