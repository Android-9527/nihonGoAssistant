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
              class="example-item"
            >
              <div class="example-head">
                <button
                  class="speak-btn"
                  type="button"
                  title="播放读音"
                  @click.stop="speakSentence(example)"
                >
                  🔊
                </button>
                <div class="example-japanese">{{ example.japanese }}</div>
              </div>
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

    <div v-if="tokenInfoVisible" class="token-modal-mask" @click.self="closeTokenInfo">
      <div class="token-modal">
        <div class="token-modal-head">
          <h3>分词信息</h3>
          <button class="close-btn" type="button" @click="closeTokenInfo">关闭</button>
        </div>

        <p class="token-surface">分词：{{ selectedToken?.surface || '-' }}</p>

        <div v-if="selectedToken?.word_id" class="token-block word-block">
          <h4>单词信息</h4>
          <p><strong>ID：</strong>{{ selectedToken.word_id }}</p>
          <p><strong>假名：</strong>{{ selectedToken.kana || '-' }}</p>
          <p><strong>汉字：</strong>{{ selectedToken.kanji || '-' }}</p>
          <p><strong>中文：</strong>{{ selectedToken.chinese || '-' }}</p>
          <button class="jump-btn" type="button" @click="goToWordDetail">进入单词详情</button>
        </div>

        <div v-if="selectedToken?.grammar_id != null" class="token-block grammar-block">
          <h4>语法信息</h4>
          <p><strong>ID：</strong>{{ selectedToken.grammar_id }}</p>
          <p><strong>模板：</strong>{{ selectedGrammar?.template || '-' }}</p>
          <p><strong>解释：</strong>{{ selectedGrammar?.explanation || '-' }}</p>
          <button class="jump-btn" type="button" @click="goToGrammarDetail">进入语法详情</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { speakJapanese } from '../utils/speech'

export default {
  data() {
    return {
      grammar: [],
      searchText: '',
      tokenInfoVisible: false,
      selectedToken: null,
      selectedGrammar: null,
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
      const hasWord = !!token.word_id;
      const hasGrammar = token.grammar_id != null;

      if (!hasWord && !hasGrammar) {
        return;
      }

      if (hasWord && !hasGrammar) {
        this.$router.push(`/word/${token.word_id}`);
        return;
      }

      if (!hasWord && hasGrammar) {
        this.$router.push(`/grammar/${token.grammar_id}`);
        return;
      }

      this.selectedToken = token;
      this.tokenInfoVisible = true;
      this.selectedGrammar = hasGrammar
        ? this.grammar.find((item) => item.id === token.grammar_id) || null
        : null;
    },
    closeTokenInfo() {
      this.tokenInfoVisible = false;
      this.selectedToken = null;
      this.selectedGrammar = null;
    },
    goToWordDetail() {
      if (!this.selectedToken?.word_id) return;
      this.$router.push(`/word/${this.selectedToken.word_id}`);
      this.closeTokenInfo();
    },
    goToGrammarDetail() {
      if (this.selectedToken?.grammar_id == null) return;
      this.$router.push(`/grammar/${this.selectedToken.grammar_id}`);
      this.closeTokenInfo();
    },
    tokenClasses(token) {
      return {
        clickable: token.grammar_id != null || !!token.word_id,
        'token-grammar': token.grammar_id != null,
      };
    },
    tokenTitle(token) {
      if (token.word_id && token.grammar_id != null) {
        return `${token.kana} / ${token.chinese} | 语法 #${token.grammar_id}`;
      }
      if (token.word_id) {
        return `${token.kana} / ${token.chinese}`;
      }
      if (token.grammar_id != null) {
        return `语法 #${token.grammar_id}`;
      }
      return '';
    },
    speakSentence(example) {
      const text = example?.japanese || '';
      speakJapanese(text, {
        ttsAudioId: example?.tts_audio_id,
        entityType: 'sentence',
        entityId: example?.id,
      });
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

.example-head {
  display: flex;
  gap: 10px;
  align-items: center;
  margin-bottom: 8px;
}

.speak-btn {
  width: 30px;
  height: 30px;
  border: 1px solid #d1d5db;
  border-radius: 50%;
  background: #fff;
  cursor: pointer;
  flex-shrink: 0;
}

.speak-btn:hover {
  border-color: #3b82f6;
  background: #eff6ff;
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

.token-modal-mask {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.45);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
  z-index: 2000;
}

.token-modal {
  width: min(640px, 100%);
  max-height: 80vh;
  overflow-y: auto;
  background: #ffffff;
  border-radius: 12px;
  border: 1px solid #cbd5e1;
  box-shadow: 0 20px 40px rgba(15, 23, 42, 0.2);
  padding: 16px;
}

.token-modal-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}

.token-modal-head h3 {
  margin: 0;
  color: #0f172a;
}

.close-btn,
.jump-btn {
  border: 1px solid #cbd5e1;
  background: #ffffff;
  color: #0f172a;
  border-radius: 8px;
  padding: 6px 12px;
  cursor: pointer;
}

.close-btn:hover,
.jump-btn:hover {
  background: #f1f5f9;
}

.token-surface {
  margin: 0 0 12px;
  color: #1e293b;
}

.token-block {
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: 12px;
  margin-bottom: 10px;
}

.token-block h4 {
  margin: 0 0 8px;
  color: #0f172a;
}

.token-block p {
  margin: 4px 0;
  color: #334155;
  line-height: 1.6;
}

.word-block {
  background: #f8fafc;
}

.grammar-block {
  background: #fffdf3;
}
</style>
