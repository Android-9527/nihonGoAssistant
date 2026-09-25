<script>
import { speakJapanese } from '../utils/speech'

export default {
  data() {
    return {
      sentences: [],
      tokenInfoVisible: false,
      selectedToken: null,
      selectedGrammar: null,
      grammarInfoCache: {},
      loadingTokenGrammar: false,
    };
  },
  computed: {
    groupedSentenceBlocks() {
      const groups = [];
      const map = new Map();

      this.sentences.forEach((sentence) => {
        const key = sentence.group_id ?? sentence.grid ?? sentence.id;
        if (!map.has(key)) {
          const group = { id: key, sentences: [] };
          map.set(key, group);
          groups.push(group);
        }
        map.get(key).sentences.push(sentence);
      });

      groups.forEach((group) => {
        const first = group.sentences[0] || {};
        const hasSpeaker = group.sentences.some((s) => (s.speaker || '').trim());
        const rawType = (first.group_type || '').trim().toLowerCase();

        let viewType = rawType;
        if (!viewType || viewType === 'single') {
          if (group.sentences.length === 1) {
            viewType = 'single';
          } else {
            viewType = hasSpeaker ? 'dialogue' : 'essay';
          }
        }

        group.viewType = viewType;
        group.title = (first.group_title || '').trim() ||
          (viewType === 'dialogue' ? `对话 ${group.id}` : viewType === 'essay' ? `短文 ${group.id}` : '例句');
      });

      return groups;
    },
  },
  methods: {
    async fetchSentences() {
      try {
        const chapter = this.$route.query.chapter;
        const url = chapter
          ? `/api/sentences?chapter=${encodeURIComponent(chapter)}`
          : '/api/sentences';
        const response = await fetch(url);
        this.sentences = await response.json();
      } catch (error) {
        console.error('Failed to fetch sentences:', error);
      }
    },
    async handleTokenClick(token) {
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
      this.selectedGrammar = null;

      if (hasGrammar) {
        await this.loadGrammarInfo(token.grammar_id);
      }
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
    speakSentence(sentence) {
      const text = sentence?.japanese || '';
      speakJapanese(text, {
        ttsAudioId: sentence?.tts_audio_id,
        entityType: 'sentence',
        entityId: sentence?.id,
      });
    },
    async loadGrammarInfo(grammarId) {
      if (this.grammarInfoCache[grammarId]) {
        this.selectedGrammar = this.grammarInfoCache[grammarId];
        return;
      }

      this.loadingTokenGrammar = true;
      try {
        const response = await fetch('/api/grammar');
        const allGrammar = await response.json();
        const nextCache = { ...this.grammarInfoCache };
        allGrammar.forEach((item) => {
          nextCache[item.id] = item;
        });
        this.grammarInfoCache = nextCache;
        this.selectedGrammar = this.grammarInfoCache[grammarId] || null;
      } catch (error) {
        console.error('Failed to load grammar info:', error);
        this.selectedGrammar = null;
      } finally {
        this.loadingTokenGrammar = false;
      }
    },
    closeTokenInfo() {
      this.tokenInfoVisible = false;
      this.selectedToken = null;
      this.selectedGrammar = null;
      this.loadingTokenGrammar = false;
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
  },
  mounted() {
    this.fetchSentences();
  },
};
</script>

<template>
  <div class="sentences-container">
    <div class="sentences-header">
      <h2>例句学习</h2>
    </div>

    <div class="sentences-list">
      <div
        v-for="group in groupedSentenceBlocks"
        :key="`group-${group.id}`"
        class="sentence-group"
      >
        <div class="group-title">{{ group.title }}</div>

        <div v-if="group.viewType === 'single'" class="group-sentences">
          <div
            v-for="sentence in group.sentences"
            :key="sentence.id"
            class="sentence-card"
          >
            <div class="sentence-number">{{ sentence.id }}</div>
            <div class="sentence-content">
              <div class="sentence-head">
                <button
                  class="speak-btn"
                  type="button"
                  title="播放读音"
                  @click.stop="speakSentence(sentence)"
                >
                  🔊
                </button>
                <div class="japanese">{{ sentence.japanese }}</div>
              </div>
              <div class="tokens">
                <span
                  v-for="token in sentence.tokens"
                  :key="`${sentence.id}-${token.token_index}`"
                  @click.stop="handleTokenClick(token)"
                  :class="tokenClasses(token)"
                  class="token"
                  :title="tokenTitle(token)"
                >
                  {{ token.surface }}
                </span>
              </div>
              <div class="chinese">{{ sentence.chinese }}</div>
            </div>
          </div>
        </div>

        <div v-else-if="group.viewType === 'dialogue'" class="dialogue-wrap">
          <article
            v-for="sentence in group.sentences"
            :key="sentence.id"
            class="dialogue-line"
          >
            <div class="dialogue-row">
              <button
                class="speak-btn"
                type="button"
                title="播放读音"
                @click.stop="speakSentence(sentence)"
              >
                🔊
              </button>
              <span class="speaker">{{ sentence.speaker || '旁白' }}</span>
              <span class="utterance">{{ sentence.content || sentence.japanese }}</span>
            </div>
            <div class="tokens dialogue-tokens">
              <span
                v-for="token in sentence.tokens"
                :key="`${sentence.id}-${token.token_index}`"
                @click.stop="handleTokenClick(token)"
                :class="tokenClasses(token)"
                class="token"
                :title="tokenTitle(token)"
              >
                {{ token.surface }}
              </span>
            </div>
            <div class="chinese">{{ sentence.chinese }}</div>
          </article>
        </div>

        <article v-else class="essay-wrap">
          <div
            v-for="sentence in group.sentences"
            :key="sentence.id"
            class="essay-line"
          >
            <button
              class="speak-btn"
              type="button"
              title="播放读音"
              @click.stop="speakSentence(sentence)"
            >
              🔊
            </button>
            <p class="essay-paragraph">{{ sentence.content || sentence.japanese }}</p>
          </div>

          <div class="essay-token-lines">
            <div v-for="sentence in group.sentences" :key="`tokens-${sentence.id}`" class="tokens">
              <span
                v-for="token in sentence.tokens"
                :key="`${sentence.id}-${token.token_index}`"
                @click.stop="handleTokenClick(token)"
                :class="tokenClasses(token)"
                class="token"
                :title="tokenTitle(token)"
              >
                {{ token.surface }}
              </span>
            </div>
          </div>

          <div class="essay-cn">
            <p v-for="sentence in group.sentences" :key="`cn-${sentence.id}`">{{ sentence.chinese }}</p>
          </div>
        </article>
      </div>
    </div>

    <p v-if="groupedSentenceBlocks.length === 0" class="no-results">
      暂无例句
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
          <p v-if="loadingTokenGrammar">语法详情加载中...</p>
          <template v-else>
            <p><strong>模板：</strong>{{ selectedGrammar?.template || '-' }}</p>
            <p><strong>解释：</strong>{{ selectedGrammar?.explanation || '-' }}</p>
          </template>
          <button class="jump-btn" type="button" @click="goToGrammarDetail">进入语法详情</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.sentences-container {
  max-width: 1100px;
  margin: 0 auto;
  padding: 20px;
}

.sentences-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
  gap: 20px;
}

.sentences-header h2 {
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

.sentences-list {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.sentence-group {
  background: #f8fafc;
  border: 1px solid #dbe4ef;
  border-radius: 10px;
  padding: 14px;
}

.group-title {
  font-size: 15px;
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 12px;
}

.group-sentences {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: 12px;
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
  border-color: #3b82f6;
}

.dialogue-wrap {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.dialogue-line {
  border: 1px solid #e2e8f0;
  background: #ffffff;
  border-radius: 10px;
  padding: 12px;
}

.dialogue-row {
  display: flex;
  gap: 10px;
  align-items: flex-start;
}

.sentence-head {
  display: flex;
  gap: 10px;
  align-items: center;
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

.speaker {
  display: inline-block;
  min-width: 64px;
  font-size: 12px;
  font-weight: 700;
  color: #0f766e;
  background: #ecfeff;
  border: 1px solid #99f6e4;
  border-radius: 999px;
  padding: 2px 8px;
  text-align: center;
}

.utterance {
  flex: 1;
  color: #1f2937;
  line-height: 1.7;
  font-size: 16px;
}

.dialogue-tokens {
  margin-top: 8px;
}

.essay-wrap {
  border: 1px solid #e2e8f0;
  background: #ffffff;
  border-radius: 12px;
  padding: 16px;
}

.essay-paragraph {
  margin: 0;
  color: #111827;
  font-size: 16px;
  line-height: 1.9;
  text-indent: 2em;
}

.essay-line {
  display: flex;
  gap: 10px;
  align-items: flex-start;
  margin-bottom: 10px;
}

.essay-line:last-child {
  margin-bottom: 0;
}

.essay-paragraph:last-child {
  margin-bottom: 0;
}

.essay-token-lines {
  margin-top: 12px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.essay-cn {
  margin-top: 12px;
  padding-top: 10px;
  border-top: 1px dashed #cbd5e1;
  color: #6b7280;
  font-size: 13px;
}

.essay-cn p {
  margin: 0 0 4px;
}

.essay-cn p:last-child {
  margin-bottom: 0;
}

.sentence-number {
  display: inline-block;
  padding: 4px 12px;
  background: #f0f4f8;
  color: #0f172a;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 600;
  margin-bottom: 12px;
}

.sentence-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.japanese {
  font-size: 18px;
  font-weight: 600;
  color: #1f2937;
  line-height: 1.6;
}

.tokens {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.token {
  display: inline-block;
  padding: 4px 8px;
  background: #f3f4f6;
  border-radius: 4px;
  font-size: 13px;
  transition: all 0.2s;
}

.token.clickable {
  cursor: pointer;
}

.token.clickable:hover {
  transform: scale(1.05);
}

.token-word {
  background: #dcfce7;
  color: #166534;
  border: 1px solid #86efac;
}

.token-word:hover {
  background: #16a34a;
  color: white;
}

.token-grammar {
  background: #fef9c3;
  color: #854d0e;
  border: 1px solid #fde047;
}

.token-grammar:hover {
  background: #eab308;
  color: #111827;
}

.chinese {
  font-size: 13px;
  color: #6b7280;
  line-height: 1.5;
}

.no-results {
  text-align: center;
  color: #9ca3af;
  padding: 60px 20px;
  grid-column: 1 / -1;
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
