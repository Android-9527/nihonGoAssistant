<template>
  <div class="detail-container">
    <div class="detail-header">
      <button @click="goBack" class="back-btn">← 返回</button>
      <h2 v-if="word">
        {{ word.kana }}
        <span v-if="word.kanji !== '/'" class="kanji-badge">{{ word.kanji }}</span>
      </h2>
    </div>

    <div v-if="word" class="word-info">
      <div class="info-card">
        <h3>单词信息</h3>
        <div class="info-row">
          <label>假名</label>
          <span>{{ word.kana }}</span>
        </div>
        <div class="info-row">
          <label>汉字</label>
          <span>{{ word.kanji !== '/' ? word.kanji : '（无）' }}</span>
        </div>
        <div class="info-row">
          <label>中文</label>
          <span>{{ word.chinese }}</span>
        </div>
      </div>
    </div>

    <div class="sentences-section">
      <h3>包含该单词的例句（共 {{ sentences.length }} 句）</h3>
      <div v-if="sentences.length > 0" class="sentences-list">
        <div v-for="sentence in sentences" :key="sentence.id" class="sentence-card">
          <div class="sentence-head">
            <button
              class="speak-btn"
              type="button"
              title="播放读音"
              @click.stop="speakSentence(sentence)"
            >
              🔊
            </button>
            <div class="sentence-japanese">{{ sentence.japanese }}</div>
          </div>
          <div class="sentence-tokens">
            <span 
              v-for="token in sentence.tokens" 
              :key="`${sentence.id}-${token.token_index}`"
              :class="{ 'is-target': token.word_id === parseInt($route.params.id) }"
              class="token"
            >
              {{ token.surface }}
            </span>
          </div>
          <div class="sentence-chinese">{{ sentence.chinese }}</div>
        </div>
      </div>
      <p v-else class="no-results">无包含该单词的例句</p>
    </div>
  </div>
</template>

<script>
import { speakJapanese } from '../utils/speech'

export default {
  data() {
    return {
      word: null,
      sentences: [],
      wordId: null,
    };
  },
  methods: {
    async fetchWord() {
      this.wordId = this.$route.params.id;
      try {
        const response = await fetch(`/api/word/${this.wordId}/sentences`);
        this.sentences = await response.json();
        
        // Get word info from first API call
        const wordsResponse = await fetch('/api/words');
        const allWords = await wordsResponse.json();
        this.word = allWords.find(w => w.id == this.wordId);
      } catch (error) {
        console.error('Failed to fetch word detail:', error);
      }
    },
    goBack() {
      this.$router.push('/words');
    },
    speakSentence(sentence) {
      const text = sentence?.japanese || '';
      speakJapanese(text, {
        ttsAudioId: sentence?.tts_audio_id,
        entityType: 'sentence',
        entityId: sentence?.id,
      });
    },
  },
  mounted() {
    this.fetchWord();
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

.kanji-badge {
  margin-left: 10px;
  padding: 4px 12px;
  background: #dbeafe;
  color: #1e40af;
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

.word-info {
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

.sentence-head {
  display: flex;
  gap: 10px;
  align-items: center;
  margin-bottom: 8px;
}

.speak-btn {
  width: 32px;
  height: 32px;
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

.sentence-japanese {
  font-size: 18px;
  font-weight: 600;
  color: #1f2937;
  margin-bottom: 0;
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
  background: #f3f4f6;
  border-radius: 4px;
  font-size: 14px;
}

.token.is-target {
  background: #fef08a;
  color: #92400e;
  font-weight: 600;
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
