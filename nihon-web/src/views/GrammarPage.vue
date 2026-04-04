<template>
  <div class="grammar-container">
    <div class="grammar-header">
      <h2>语法学习</h2>
      <input 
        v-model="searchText" 
        type="text" 
        placeholder="搜索语法..."
        class="search-input"
      />
    </div>

    <div class="grammar-list">
      <div 
        v-for="point in filteredGrammar" 
        :key="point.id"
        class="grammar-card"
      >
        <div class="grammar-header-info">
          <div class="grammar-id">{{ point.id }}.</div>
          <div class="grammar-template">{{ point.template }}</div>
        </div>
        
        <div class="grammar-explanation">
          {{ point.explanation }}
        </div>

        <div class="examples-section">
          <h4>例句</h4>
          <div class="examples-list">
            <div 
              v-for="example in point.examples" 
              :key="example.id"
              @mouseenter="speakSentence(example.japanese)"
              class="example-item"
            >
              <div class="example-japanese">{{ example.japanese }}</div>
              <div class="tokens">
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
              <div class="example-chinese">{{ example.chinese }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <p v-if="filteredGrammar.length === 0" class="no-results">
      未找到匹配的语法
    </p>
  </div>
</template>

<script>
import { speakJapanese } from '../utils/speech'

export default {
  data() {
    return {
      grammar: [],
      searchText: '',
    };
  },
  computed: {
    filteredGrammar() {
      return this.grammar.filter(point => {
        const search = this.searchText.toLowerCase();
        return (
          point.template.toLowerCase().includes(search) ||
          point.explanation.toLowerCase().includes(search)
        );
      });
    },
  },
  methods: {
    async fetchGrammar() {
      try {
        const chapter = this.$route.query.chapter;
        const url = chapter
          ? `/api/grammar?chapter=${encodeURIComponent(chapter)}`
          : '/api/grammar';
        const response = await fetch(url);
        this.grammar = await response.json();
      } catch (error) {
        console.error('Failed to fetch grammar:', error);
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
    speakSentence(text) {
      speakJapanese(text);
    },
  },
  mounted() {
    this.fetchGrammar();
  },
};
</script>

<style scoped>
.grammar-container {
  max-width: 1100px;
  margin: 0 auto;
  padding: 20px;
}

.grammar-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
  gap: 20px;
}

.grammar-header h2 {
  margin: 0;
  color: #1f2937;
}

.search-input {
  padding: 8px 12px;
  border: 1px solid #d1d5db;
  border-radius: 4px;
  font-size: 14px;
  flex: 1;
  min-width: 200px;
}

.search-input:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 4px rgba(59, 130, 246, 0.2);
}

.grammar-list {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.grammar-card {
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  padding: 20px;
  transition: all 0.2s;
}

.grammar-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  border-color: #3b82f6;
}

.grammar-header-info {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 16px;
}

.grammar-id {
  display: inline-block;
  padding: 6px 14px;
  background: #dbeafe;
  color: #1e40af;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 600;
  flex-shrink: 0;
}

.grammar-template {
  font-size: 18px;
  font-weight: 600;
  color: #1f2937;
}

.grammar-explanation {
  background: #f9fafb;
  padding: 12px 16px;
  border-left: 3px solid #3b82f6;
  border-radius: 4px;
  margin-bottom: 16px;
  color: #4b5563;
  font-size: 14px;
  line-height: 1.6;
}

.examples-section h4 {
  margin: 0 0 12px 0;
  color: #1f2937;
  font-size: 14px;
}

.examples-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.example-item {
  background: #f3f4f6;
  padding: 12px;
  border-radius: 6px;
  font-size: 13px;
}

.example-japanese {
  font-weight: 600;
  color: #1f2937;
  margin-bottom: 8px;
}

.tokens {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-bottom: 8px;
}

.token {
  display: inline-block;
  padding: 3px 6px;
  background: white;
  border: 1px solid #d1d5db;
  border-radius: 3px;
  font-size: 12px;
  transition: all 0.2s;
}

.token.clickable {
  cursor: pointer;
}

.token.clickable:hover {
  transform: translateY(-1px);
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

.example-chinese {
  color: #6b7280;
  font-size: 12px;
}

.no-results {
  text-align: center;
  color: #9ca3af;
  padding: 60px 20px;
}
</style>
