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

      <article class="module-card" @click="go('/my-words')">
        <h2>我的单词</h2>
        <p>按章节进入单词学习。</p>
      </article>

      <article class="module-card" @click="go('/my-grammar')">
        <h2>我的语法</h2>
        <p>按章节进入语法学习。</p>
      </article>
    </div>

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
        <div><strong>LLM解释：</strong>{{ queryResult.llm?.grammar_explanation || '（空）' }}</div>
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

    <section class="review-panel">
      <div class="review-head">
        <h2>随机复习</h2>
      </div>

      <div v-if="currentSentence" class="single-review">
        <div class="review-meta">
          <span>第 {{ currentReviewIndex + 1 }} / {{ reviewSentences.length }} 句</span>
          <span class="unknown-count">已标记不懂分词: {{ currentUnknownCount }}</span>
        </div>

        <p class="jp">{{ currentSentence.japanese }}</p>

        <div class="review-actions">
          <button class="action-btn" @click="revealAnswer" :disabled="showAnswer">
            {{ showAnswer ? '已显示中文与分词' : '显示中文与分词' }}
          </button>
          <button class="action-btn" @click="nextSentence">
            下一句
          </button>
        </div>

        <div v-if="showAnswer" class="answer-area">
          <p class="cn">{{ currentSentence.chinese }}</p>

          <div class="token-list">
            <button
              v-for="token in currentSentence.tokens || []"
              :key="`review-${currentSentence.id}-${token.token_index}`"
              class="token-btn"
              :class="{ selected: isUnknownToken(currentSentence.id, token.token_index) }"
              @click="toggleUnknownToken(token)"
              :title="isUnknownToken(currentSentence.id, token.token_index) ? '已标记不懂' : '点击标记不懂'"
            >
              {{ token.surface }}
            </button>
          </div>
        </div>
      </div>

      <p v-else class="empty-review">暂无可复习句子</p>

      <div class="review-tip">
        当前先做前端点击标记，后续可把“不懂分词”提交到后台更新掌握度。
      </div>
    </section>
  </section>
</template>

<script>
export default {
  data() {
    return {
      allSentences: [],
      reviewSentences: [],
      currentReviewIndex: 0,
      showAnswer: false,
      unknownTokenMap: {},
      querySentence: '',
      queryLoading: false,
      queryError: '',
      queryResult: null,
    };
  },
  computed: {
    currentSentence() {
      return this.reviewSentences[this.currentReviewIndex] || null;
    },
    currentUnknownCount() {
      const sentenceId = this.currentSentence?.id;
      if (!sentenceId || !this.unknownTokenMap[sentenceId]) return 0;
      return this.unknownTokenMap[sentenceId].length;
    },
  },
  methods: {
    go(path) {
      this.$router.push(path);
    },
    async fetchSentences() {
      try {
        const response = await fetch('/api/sentences?chapter=2');
        this.allSentences = await response.json();
        this.pickRandomSentences();
      } catch (error) {
        console.error('Failed to fetch random review sentences:', error);
      }
    },
    pickRandomSentences() {
      const pool = [...this.allSentences];
      for (let i = pool.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [pool[i], pool[j]] = [pool[j], pool[i]];
      }
      this.reviewSentences = pool.slice(0, 5);
      this.currentReviewIndex = 0;
      this.showAnswer = false;
    },
    revealAnswer() {
      this.showAnswer = true;
    },
    nextSentence() {
      if (!this.reviewSentences.length) return;
      this.currentReviewIndex = (this.currentReviewIndex + 1) % this.reviewSentences.length;
      this.showAnswer = false;
    },
    isUnknownToken(sentenceId, tokenIndex) {
      const list = this.unknownTokenMap[sentenceId] || [];
      return list.includes(tokenIndex);
    },
    toggleUnknownToken(token) {
      const sentence = this.currentSentence;
      if (!sentence) return;

      const sentenceId = sentence.id;
      const tokenIndex = token.token_index;
      const currentList = [...(this.unknownTokenMap[sentenceId] || [])];
      const exists = currentList.includes(tokenIndex);
      const nextList = exists
        ? currentList.filter((idx) => idx !== tokenIndex)
        : [...currentList, tokenIndex];

      this.unknownTokenMap = {
        ...this.unknownTokenMap,
        [sentenceId]: nextList,
      };
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
  mounted() {
    this.fetchSentences();
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

.review-panel {
  background: linear-gradient(180deg, #ffffff, #f8fafc);
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 16px;
}

.review-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
}

.review-head h2 {
  margin: 0;
  font-size: 18px;
  color: #0f172a;
}

.single-review {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.review-meta {
  display: flex;
  justify-content: space-between;
  color: #475569;
  font-size: 13px;
  gap: 10px;
  flex-wrap: wrap;
}

.unknown-count {
  color: #0f766e;
}

.jp {
  margin: 0 0 8px;
  font-size: 20px;
  font-weight: 600;
  color: #111827;
}

.review-actions {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
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

.answer-area {
  border: 1px dashed #cbd5e1;
  border-radius: 10px;
  padding: 12px;
  background: #ffffff;
}

.cn {
  margin: 0;
  color: #6b7280;
  font-size: 13px;
}

.token-list {
  margin-top: 10px;
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.token-btn {
  border: 1px solid #d1d5db;
  background: #f9fafb;
  color: #111827;
  border-radius: 7px;
  padding: 4px 10px;
  cursor: pointer;
  font-size: 13px;
}

.token-btn:hover {
  border-color: #94a3b8;
}

.token-btn.selected {
  background: #fee2e2;
  border-color: #ef4444;
  color: #991b1b;
}

.empty-review {
  margin: 0;
  color: #64748b;
}

.review-tip {
  margin-top: 10px;
  color: #64748b;
  font-size: 12px;
}
</style>
