<template>
  <section class="page-wrap">
    <header class="head">
      <h1>我的课本</h1>
      <p>当前在学课本与熟练度。</p>
    </header>

    <form class="add-book" @submit.prevent="addBook">
      <input v-model="newTitle" type="text" placeholder="输入书名，例如：大家的日语初级1" required />
      <button type="submit">添加书籍</button>
    </form>

    <div class="books-grid">
      <article v-for="book in books" :key="book.id" class="book-card" @click="openBook(book.id)">
        <h2>{{ book.title }}</h2>
        <p class="sub">熟练度：{{ book.progress }}%</p>
        <div class="bar">
          <div class="bar-fill" :style="{ width: `${book.progress}%` }"></div>
        </div>
      </article>
    </div>
  </section>
</template>

<script>
const KEY = 'nihon_books';
const DEFAULT_BOOKS = [
  { id: 'minna-nihongo-1', title: '大家的日语初级1', progress: 0, chapterStart: 1, chapterEnd: 25 },
  { id: 'minna-nihongo-2', title: '大家的日语初级2', progress: 0, chapterStart: 26, chapterEnd: 50 },
];

export default {
  data() {
    return {
      books: [],
      newTitle: '',
    };
  },
  methods: {
    loadBooks() {
      const saved = localStorage.getItem(KEY);
      const savedBooks = saved ? JSON.parse(saved) : [];

      // 合并默认书单：已存在不重复并补齐元数据，缺失则补上；默认书排在前面
      const merged = [];
      for (const def of DEFAULT_BOOKS) {
        const existing = savedBooks.find((b) => b.id === def.id);
        merged.push(existing ? { ...def, ...existing } : { ...def });
      }
      for (const book of savedBooks) {
        if (!merged.some((m) => m.id === book.id)) {
          merged.push(book);
        }
      }
      this.books = merged;
      this.saveBooks();
    },
    saveBooks() {
      localStorage.setItem(KEY, JSON.stringify(this.books));
    },
    addBook() {
      const title = this.newTitle.trim();
      if (!title) return;
      const id = `${Date.now()}`;
      this.books.unshift({ id, title, progress: 0 });
      this.newTitle = '';
      this.saveBooks();
    },
    openBook(bookId) {
      this.$router.push(`/textbook/${bookId}/chapters`);
    },
  },
  mounted() {
    this.loadBooks();
  },
};
</script>

<style scoped>
.page-wrap { display: flex; flex-direction: column; gap: 14px; }
.head h1 { margin: 0; }
.head p { margin: 6px 0 0; color: #475569; }

.add-book { display: flex; gap: 10px; flex-wrap: wrap; }
.add-book input {
  flex: 1;
  min-width: 260px;
  border: 1px solid #cbd5e1;
  border-radius: 10px;
  padding: 10px 12px;
}
.add-book button {
  border: 0;
  border-radius: 10px;
  padding: 10px 14px;
  background: #0f766e;
  color: #fff;
  cursor: pointer;
}

.books-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 12px;
}
.book-card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 14px;
  cursor: pointer;
}
.book-card:hover { border-color: #94a3b8; }
.book-card h2 { margin: 0 0 8px; font-size: 18px; }
.sub { margin: 0 0 8px; color: #334155; }
.bar { height: 10px; background: #e2e8f0; border-radius: 99px; overflow: hidden; }
.bar-fill { height: 100%; background: linear-gradient(90deg, #22c55e, #84cc16); }
</style>
