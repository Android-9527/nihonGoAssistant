<template>
  <div class="detail-container">
    <div class="detail-header">
      <button @click="goBack" class="back-btn">← 返回</button>
      <h2 v-if="grammar">
        语法 #{{ grammar.id }}
        <span class="template-badge">{{ grammar.template }}</span>
      </h2>
      <h2 v-else>语法详情</h2>
    </div>

    <div v-if="grammar" class="grammar-info">
      <div class="info-card">
        <h3>语法信息</h3>
        <div class="info-row">
          <label>ID</label>
          <span>{{ grammar.id }}</span>
        </div>
        <div class="info-row">
          <label>章节</label>
          <span>{{ grammar.chapter }}</span>
        </div>
        <div class="info-row">
          <label>模板</label>
          <span>{{ grammar.template }}</span>
        </div>
        <div class="info-row">
          <label>解释</label>
          <span>{{ grammar.explanation }}</span>
        </div>
      </div>
    </div>

    <div class="sentences-section">
      <h3>语法例句（共 {{ examples.length }} 句）</h3>
      <div v-if="examples.length > 0" class="sentences-list">
        <div
          v-for="example in examples"
          :key="example.id"
          @mouseenter="speakSentence(example.japanese)"
          class="sentence-card"
        >
          <div class="sentence-japanese">{{ example.japanese }}</div>
          <div class="sentence-tokens">
            <span
              v-for="token in example.tokens"
              :key="`${example.id}-${token.token_index}`"
              @click.stop="handleTokenClick(token)"
              :class="tokenClasses(token)"
              class="token"
              :title="tokenTitle(token)"
            >
              {{ token.surface }}
            </span>
          </div>
          <div class="sentence-chinese">{{ example.chinese }}</div>
        </div>
      </div>
      <p v-else class="no-results">无该语法的例句</p>
    </div>
  </div>
</template>

<script>
import { speakJapanese } from '../utils/speech'

export default {
  data() {
    return {
      grammar: null,
      examples: [],
    };
  },
  methods: {
    async fetchGrammarDetail() {
      const grammarId = Number(this.$route.params.id);
      if (!Number.isFinite(grammarId)) {
        this.grammar = null;
        this.examples = [];
        return;
      }

      try {
        const response = await fetch('/api/grammar');
        const allGrammar = await response.json();
        const found = allGrammar.find((item) => item.id === grammarId);

        this.grammar = found || null;
        this.examples = found?.examples || [];
      } catch (error) {
        console.error('Failed to fetch grammar detail:', error);
      }
    },
    handleTokenClick(token) {
      if (token.grammar_id != null) {
        this.$router.push(`/grammar/${token.grammar_id}`);
        return;
      }
      if (token.word_id) {
        this.$router.push(`/word/${token.word_id}`);
      }
    },
    tokenClasses(token) {
      return {
        clickable: token.grammar_id != null || !!token.word_id,
        'token-word': !!token.word_id && token.grammar_id == null,
        'token-grammar': token.grammar_id != null,
      };
    },
    tokenTitle(token) {
      if (token.grammar_id != null) {
        return `语法 #${token.grammar_id}`;
      }
      if (token.word_id) {
        return `${token.kana} / ${token.chinese}`;
      }
      return '';
    },
    goBack() {
      this.$router.push('/grammar');
    },
    speakSentence(text) {
      speakJapanese(text);
    },
  },
  mounted() {
    this.fetchGrammarDetail();
  },
  watch: {
    '$route.params.id'() {
      this.fetchGrammarDetail();
    },
  },
};
</script>

<style scoped>
.detail-container {
  max-width: 1100px;
  margin: 0 auto;
  padding: 20px;
}

.detail-header {
  display: flex;
  align-items: center;
  gap: 20px;
  margin-bottom: 30px;
}

.detail-header h2 {
  margin: 0;
  color: #1f2937;
}

.template-badge {
  margin-left: 10px;
  padding: 4px 12px;
  background: #fef3c7;
  color: #92400e;
  border-radius: 4px;
  font-size: 0.9em;
}

.back-btn {
  padding: 8px 16px;
  background: #f3f4f6;
  border: 1px solid #d1d5db;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  transition: all 0.2s;
}

.back-btn:hover {
  background: #e5e7eb;
}

.grammar-info {
  display: grid;
  gap: 20px;
  margin-bottom: 40px;
}

.info-card {
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  padding: 20px;
}

.info-card h3 {
  margin: 0 0 16px 0;
  color: #1f2937;
}

.info-row {
  display: flex;
  justify-content: space-between;
  padding: 12px 0;
  border-bottom: 1px solid #f3f4f6;
  gap: 24px;
}

.info-row:last-child {
  border-bottom: none;
}

.info-row label {
  font-weight: 600;
  color: #6b7280;
  min-width: 100px;
}

.info-row span {
  color: #1f2937;
}

.sentences-section {
  margin-bottom: 30px;
}

.sentences-section h3 {
  margin-bottom: 16px;
  color: #1f2937;
}

.sentences-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.sentence-card {
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  padding: 16px;
  transition: all 0.2s;
}

.sentence-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.sentence-japanese {
  font-size: 18px;
  font-weight: 600;
  color: #1f2937;
  margin-bottom: 12px;
}

.sentence-tokens {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-bottom: 12px;
}

.token {
  display: inline-block;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 14px;
  border: 1px solid #d1d5db;
  transition: all 0.2s;
}

.token.clickable {
  cursor: pointer;
}

.token-word {
  background: #dcfce7;
  color: #166534;
  border-color: #86efac;
}

.token-word:hover {
  background: #16a34a;
  color: white;
}

.token-grammar {
  background: #fef9c3;
  color: #854d0e;
  border-color: #fde047;
}

.token-grammar:hover {
  background: #eab308;
  color: #111827;
}

.sentence-chinese {
  font-size: 14px;
  color: #6b7280;
}

.no-results {
  text-align: center;
  color: #9ca3af;
  padding: 40px 20px;
}
</style>
