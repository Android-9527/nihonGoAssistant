<template>
  <div class="detail-container">
    <div class="detail-header">
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
          class="sentence-card"
        >
          <div class="sentence-head">
            <button
              class="speak-btn"
              type="button"
              title="播放读音"
              @click.stop="speakSentence(example)"
            >
              🔊
            </button>
            <div class="sentence-japanese">{{ example.japanese }}</div>
          </div>
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
      grammar: null,
      examples: [],
      grammarInfoCache: {},
      tokenInfoVisible: false,
      selectedToken: null,
      selectedGrammar: null,
    };
  },
  methods: {
    async fetchGrammarDetail() {
      const grammarId = Number(this.$route.params.id);
      const chapter = Number(this.$route.query.chapter);
      if (!Number.isFinite(grammarId)) {
        this.grammar = null;
        this.examples = [];
        this.grammarInfoCache = {};
        return;
      }

      try {
        const url = Number.isFinite(chapter)
          ? `/api/grammar?chapter=${encodeURIComponent(chapter)}`
          : '/api/grammar';
        const response = await fetch(url);
        const allGrammar = await response.json();
        const cache = {};
        allGrammar.forEach((item) => {
          cache[item.id] = item;
        });
        this.grammarInfoCache = cache;

        const found = allGrammar.find((item) => item.id === grammarId);
        this.grammar = found || null;
        this.examples = found?.examples || [];
      } catch (error) {
        console.error('Failed to fetch grammar detail:', error);
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
        ? this.grammarInfoCache[token.grammar_id] || null
        : null;
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
    this.fetchGrammarDetail();
  },
  watch: {
    '$route.params.id'() {
      this.fetchGrammarDetail();
    },
    '$route.query.chapter'() {
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
  white-space: pre-line;
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

.sentence-head {
  display: flex;
  gap: 10px;
  align-items: center;
  margin-bottom: 12px;
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
  white-space: pre-line;
}

.word-block {
  background: #f8fafc;
}

.grammar-block {
  background: #fffdf3;
}
</style>
