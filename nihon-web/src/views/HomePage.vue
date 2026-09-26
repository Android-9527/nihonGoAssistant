<template>
  <section class="home">
    <header class="hero">
      <h1>学习中心</h1>
      <p>从课本、单词、语法三个模块进入学习。</p>
    </header>

    <div class="module-grid">
      <article class="module-card" @click="go('/textbooks')">
        <h2>我的课本</h2>
        <p>查看当前在学课本，进入章节学习流程。</p>
      </article>

      <article class="module-card review-card" @click="goReview">
        <h2>我的复习</h2>
        <p>优先复习上次忘记与低掌握的单词、语法。</p>
        <div class="review-badge">{{ reviewBadge }}</div>
      </article>
    </div>

    <section class="word-search-panel">
      <div class="word-search-head">
        <h2>单词检索</h2>
        <p>支持假名、汉字、中文检索，点击可进入单词详情。</p>
      </div>

      <div class="word-search-form">
        <input
          v-model.trim="wordSearchText"
          class="word-input"
          placeholder="例如：相撲 / すもう / 相扑"
        />
        <button class="action-btn" @click="clearWordSearch" :disabled="!wordSearchText">
          清空
        </button>
      </div>

      <div v-if="wordSearchError" class="word-search-error">{{ wordSearchError }}</div>

      <div v-else-if="wordSearchText" class="word-result-list">
        <article
          v-for="(word, idx) in filteredWords"
          :key="word.id"
          class="word-result-card"
          @click="openWordDetail(word)"
        >
          <div class="word-result-order">{{ idx + 1 }}</div>
          <div class="word-result-main">
            <div class="word-result-kana">{{ word.kana }}</div>
            <div class="word-result-meta">
              <span>汉字：{{ word.kanji && word.kanji !== '/' ? word.kanji : '（无）' }}</span>
              <span>中文：{{ word.chinese }}</span>
            </div>
          </div>
          <div class="word-result-chapter">第{{ word.chapter }}章</div>
        </article>
        <p v-if="!filteredWords.length" class="empty-review">未检索到匹配单词</p>
      </div>
    </section>

    <section class="grammar-search-panel">
      <div class="grammar-search-head">
        <h2>语法查询</h2>
        <p>输入一句日语，自动分析并返回课本中最相关的 3 条语法。</p>
      </div>

      <div class="grammar-search-form">
        <input
          v-model.trim="querySentence"
          class="grammar-input"
          placeholder="请输入日语句子，例如：これはいくらですか"
          @keyup.enter="runGrammarSearch"
        />
        <button class="action-btn" @click="runGrammarSearch" :disabled="queryLoading || !querySentence">
          {{ queryLoading ? '查询中...' : '开始查询' }}
        </button>
      </div>

      <p v-if="queryError" class="grammar-error">{{ queryError }}</p>

      <div v-if="queryResult" class="grammar-llm-box">
        <div><strong>LLM模板：</strong>{{ queryResult.llm?.grammar_pattern || '（空）' }}</div>
        <div class="llm-explanation-line"><strong>LLM解释：</strong>{{ queryResult.llm?.grammar_explanation || '（空）' }}</div>
      </div>

      <div v-if="queryResult && (queryResult.results || []).length" class="grammar-result-list">
        <article
          v-for="(item, idx) in queryResult.results"
          :key="`${item.unique_id}-${idx}`"
          class="grammar-result-card"
          @click="openGrammarDetail(item)"
        >
          <div class="grammar-result-title">{{ idx + 1 }}. 第{{ item.chapter }}章 · Grammar {{ item.grammar_id }}</div>
          <div class="grammar-result-template">{{ item.template }}</div>
          <div class="grammar-result-score">综合分：{{ (item.final_score * 100).toFixed(2) }}%</div>
        </article>
      </div>

      <p v-else-if="queryResult" class="empty-review">没有检索到结果，可尝试更完整的句子。</p>
    </section>
  </section>
</template>

<script>
import userStore from '../store/user';

export default {
  data() {
    return {
      reviewCount: null,
      querySentence: '',
      queryLoading: false,
      queryError: '',
      queryResult: null,
      allWords: [],
      wordSearchText: '',
      wordSearchError: '',
    };
  },
  computed: {
    isLoggedIn() {
      return userStore.isLoggedIn.value;
    },
    reviewBadge() {
      if (!this.isLoggedIn) return '登录后可查看待复习内容';
      if (this.reviewCount === null) return '加载中...';
      return this.reviewCount > 0 ? `${this.reviewCount} 项待复习` : '暂无待复习内容';
    },
    filteredWords() {
      const keyword = this.wordSearchText.trim().toLowerCase();
      if (!keyword) return [];

      return this.allWords
        .filter((word) => {
          const kana = (word.kana || '').toLowerCase();
          const kanji = (word.kanji || '').toLowerCase();
          const chinese = (word.chinese || '').toLowerCase();
          return kana.includes(keyword) || kanji.includes(keyword) || chinese.includes(keyword);
        })
        .slice(0, 20);
    },
  },
  methods: {
    go(path) {
      this.$router.push(path);
    },
    goReview() {
      if (!userStore.isLoggedIn.value) {
        this.$router.push({ path: '/login', query: { redirect: '/home' } });
        return;
      }
      this.$router.push({ path: '/test', query: { mode: 'review' } });
    },
    async fetchReviewCount() {
      this.reviewCount = null;
      try {
        const response = await fetch('/api/review/recommendations?limit=60', {
          headers: userStore.authHeaders(),
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || '获取复习数量失败');
        this.reviewCount = Array.isArray(data) ? data.length : 0;
      } catch (error) {
        this.reviewCount = 0;
      }
    },
    async fetchWords() {
      this.wordSearchError = '';
      try {
        const response = await fetch('/api/words');
        if (!response.ok) throw new Error('获取单词失败');
        this.allWords = await response.json();
      } catch (error) {
        this.wordSearchError = error.message || '获取单词失败';
      }
    },
    clearWordSearch() {
      this.wordSearchText = '';
    },
    openWordDetail(word) {
      if (!word || word.id == null) return;
      this.$router.push(`/word/${word.id}`);
    },
    async runGrammarSearch() {
      const sentence = this.querySentence.trim();
      if (!sentence) return;

      this.queryLoading = true;
      this.queryError = '';
      this.queryResult = null;
      try {
        const response = await fetch('/api/grammar-search', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ sentence }),
        });
        const data = await response.json();
        if (!response.ok) {
          throw new Error(data.error || '查询失败');
        }
        this.queryResult = {
          ...data,
          results: (data.results || []).slice(0, 3),
        };
      } catch (error) {
        this.queryError = error.message || '查询失败';
      } finally {
        this.queryLoading = false;
      }
    },
    openGrammarDetail(item) {
      if (!item || item.grammar_id == null) return;
      this.$router.push({
        path: `/grammar/${item.grammar_id}`,
        query: item.chapter != null ? { chapter: String(item.chapter) } : {},
      });
    },
  },
  watch: {
    isLoggedIn(val) {
      if (val) {
        this.fetchReviewCount();
      } else {
        this.reviewCount = null;
      }
    },
  },
  mounted() {
    this.fetchWords();
    if (userStore.isLoggedIn.value) {
      this.fetchReviewCount();
    }
  },
};
</script>

<style scoped>
.home {
  display: flex;
  flex-direction: column;
  gap: 18px;
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

.module-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 14px;
}

.module-card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 18px;
  cursor: pointer;
  transition: 0.2s ease;
}

.module-card:hover {
  transform: translateY(-2px);
  border-color: #94a3b8;
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.08);
}

.module-card h2 {
  margin: 0 0 6px;
  font-size: 18px;
  color: #0f172a;
}

.module-card p {
  margin: 0;
  color: #475569;
  font-size: 14px;
}

.review-card {
  border-color: #a7f3d0;
  background: linear-gradient(180deg, #ffffff, #f0fdf4);
}

.review-badge {
  margin-top: 10px;
  display: inline-block;
  background: #dcfce7;
  color: #15803d;
  border-radius: 999px;
  padding: 4px 12px;
  font-size: 12px;
  font-weight: 600;
}

.word-search-panel {
  background: linear-gradient(180deg, #ffffff, #f8fafc);
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 16px;
}

.word-search-head h2 {
  margin: 0;
  font-size: 18px;
  color: #0f172a;
}

.word-search-head p {
  margin: 6px 0 0;
  font-size: 13px;
  color: #64748b;
}

.word-search-form {
  margin-top: 10px;
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.word-input {
  flex: 1;
  min-width: 260px;
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  padding: 8px 10px;
  font-size: 14px;
}

.word-search-error {
  margin-top: 10px;
  color: #b91c1c;
  font-size: 13px;
}

.word-result-list {
  margin-top: 10px;
  display: grid;
  gap: 8px;
}

.word-result-card {
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  background: #fff;
  padding: 10px;
  cursor: pointer;
  transition: 0.2s ease;
  display: flex;
  align-items: center;
  gap: 10px;
}

.word-result-card:hover {
  border-color: #94a3b8;
  box-shadow: 0 6px 14px rgba(15, 23, 42, 0.08);
}

.word-result-order {
  width: 24px;
  height: 24px;
  border-radius: 999px;
  background: #e2e8f0;
  color: #334155;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 700;
  flex-shrink: 0;
}

.word-result-main {
  flex: 1;
  min-width: 0;
}

.word-result-kana {
  font-size: 15px;
  font-weight: 700;
  color: #0f172a;
}

.word-result-meta {
  margin-top: 2px;
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  color: #475569;
  font-size: 12px;
}

.word-result-chapter {
  color: #0369a1;
  font-size: 12px;
  flex-shrink: 0;
}

.grammar-search-panel {
  background: linear-gradient(180deg, #ffffff, #f8fafc);
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 16px;
}

.grammar-search-head h2 {
  margin: 0;
  font-size: 18px;
  color: #0f172a;
}

.grammar-search-head p {
  margin: 6px 0 0;
  font-size: 13px;
  color: #64748b;
}

.grammar-search-form {
  margin-top: 10px;
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.grammar-input {
  flex: 1;
  min-width: 260px;
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  padding: 8px 10px;
  font-size: 14px;
}

.grammar-error {
  margin-top: 10px;
  color: #b91c1c;
  font-size: 13px;
}

.grammar-llm-box {
  margin-top: 10px;
  border: 1px dashed #cbd5e1;
  border-radius: 10px;
  padding: 10px;
  background: #fff;
  display: flex;
  flex-direction: column;
  gap: 8px;
  font-size: 13px;
  color: #334155;
}

.llm-explanation-line {
  white-space: pre-line;
}

.grammar-result-list {
  margin-top: 10px;
  display: grid;
  gap: 8px;
}

.grammar-result-card {
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  background: #fff;
  padding: 10px;
  cursor: pointer;
  transition: 0.2s ease;
}

.grammar-result-card:hover {
  border-color: #94a3b8;
  box-shadow: 0 6px 14px rgba(15, 23, 42, 0.08);
}

.grammar-result-title {
  font-size: 12px;
  color: #64748b;
}

.grammar-result-template {
  margin-top: 4px;
  color: #0f172a;
  font-weight: 600;
}

.grammar-result-score {
  margin-top: 4px;
  color: #0369a1;
  font-size: 12px;
}

.action-btn {
  border: 1px solid #cbd5e1;
  background: #fff;
  color: #1f2937;
  border-radius: 8px;
  padding: 7px 12px;
  cursor: pointer;
}

.action-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.empty-review {
  margin: 0;
  color: #64748b;
}
</style>
