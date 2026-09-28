<template>
  <section class="chapters-wrap">
    <header>
      <h1>{{ bookTitle }}</h1>
      <p>选择章节进入学习流程。</p>
    </header>

    <div class="chapters-grid">
      <button v-for="n in chapters" :key="n" class="chapter-btn" @click="openChapter(n)">
        第 {{ n }} 章
      </button>
    </div>
  </section>
</template>

<script>
const KEY = 'nihon_books';

export default {
  data() {
    return { bookTitle: '课本' };
  },
  computed: {
    chapters() {
      let start = 1;
      let end = 25;
      const saved = localStorage.getItem(KEY);
      if (saved) {
        const found = JSON.parse(saved).find((b) => b.id === this.$route.params.bookId);
        if (found && found.chapterStart && found.chapterEnd) {
          start = found.chapterStart;
          end = found.chapterEnd;
        }
      }
      const list = [];
      for (let n = start; n <= end; n += 1) list.push(n);
      return list;
    },
  },
  methods: {
    openChapter(chapter) {
      this.$router.push(`/textbook/${this.$route.params.bookId}/chapter/${chapter}/learn`);
    },
    loadBook() {
      const saved = localStorage.getItem(KEY);
      if (!saved) return;
      const books = JSON.parse(saved);
      const found = books.find((b) => b.id === this.$route.params.bookId);
      if (found) this.bookTitle = found.title;
    },
  },
  mounted() {
    this.loadBook();
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
.chapter-btn:hover { border-color: #0ea5e9; background: #f0f9ff; }
</style>
