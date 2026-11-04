<template>
  <section class="learn-wrap">
    <header>
      <h1>{{ isEn() ? `Chapter ${chapter} Study Path` : `第 ${chapter} 章学习路径` }}</h1>
      <p>{{ bookTitle }}</p>
    </header>

    <div class="flow-grid">
      <button class="flow-item" @click="goWords">1. {{ isEn() ? 'Words' : '单词' }}</button>
      <button class="flow-item" @click="goGrammar">2. {{ isEn() ? 'Grammar' : '语法' }}</button>
      <button class="flow-item" @click="goText">3. {{ isEn() ? 'Text' : '课文' }}</button>
      <button class="flow-item" @click="goTest">4. {{ isEn() ? 'Test' : '测试' }}</button>
    </div>
  </section>
</template>

<script>
import languageStore from '../store/language';

const KEY = 'nihon_books';

export default {
  data() {
    return { bookTitle: '课本' };
  },
  computed: {
    chapter() {
      return Number(this.$route.params.chapter || 0);
    },
  },
  methods: {
    isEn() {
      return languageStore.isEn();
    },
    loadBook() {
      const saved = localStorage.getItem(KEY);
      if (!saved) return;
      const books = JSON.parse(saved);
      const found = books.find((b) => b.id === this.$route.params.bookId);
      if (found) this.bookTitle = found.title;
    },
    goWords() {
      this.$router.push(`/words?chapter=${this.chapter}`);
    },
    goGrammar() {
      this.$router.push(`/grammar?chapter=${this.chapter}`);
    },
    goText() {
      this.$router.push(`/sentences?chapter=${this.chapter}`);
    },
    goTest() {
      this.$router.push(`/test?chapter=${this.chapter}`);
    },
  },
  mounted() {
    this.loadBook();
  },
};
</script>

<style scoped>
.learn-wrap { display: flex; flex-direction: column; gap: 12px; }
header h1 { margin: 0; }
header p { margin: 6px 0 0; color: #475569; }
.flow-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 10px;
}
.flow-item {
  border: 1px solid #cbd5e1;
  background: #fff;
  border-radius: 12px;
  padding: 14px;
  text-align: left;
  cursor: pointer;
}
.flow-item:hover { border-color: #22c55e; background: #f0fdf4; }
</style>
