<script>
import { speakJapanese } from '../utils/speech'

export default {
  data() {
    return {
      words: [],
      displayWords: [],
      searchText: '',
      hideFields: {
        kana: false,
        kanji: false,
        chinese: false,
      },
      isShuffled: false,
      originalWords: [],
    };
  },
  computed: {
    filteredWords() {
      return this.displayWords.filter(word => {
        const search = this.searchText.toLowerCase();
        return (
          word.kana.toLowerCase().includes(search) ||
          word.kanji.toLowerCase().includes(search) ||
          word.chinese.toLowerCase().includes(search)
        );
      });
    },
  },
  methods: {
    async fetchWords() {
      try {
        const chapter = this.$route.query.chapter;
        const url = chapter
          ? `http://localhost:5000/api/words?chapter=${encodeURIComponent(chapter)}`
          : 'http://localhost:5000/api/words';
        const response = await fetch(url);
        this.words = await response.json();
        this.displayWords = [...this.words];
        this.originalWords = [...this.words];
      } catch (error) {
        console.error('Failed to fetch words:', error);
      }
    },
    toggleHide(field) {
      this.hideFields[field] = !this.hideFields[field];
    },
    toggleShuffle() {
      if (this.isShuffled) {
        // 恢复原始顺序
        this.displayWords = [...this.originalWords];
        this.isShuffled = false;
      } else {
        // 乱序
        this.displayWords = this.shuffle([...this.displayWords]);
        this.isShuffled = true;
      }
    },
    shuffle(array) {
      const arr = [...array];
      for (let i = arr.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [arr[i], arr[j]] = [arr[j], arr[i]];
      }
      return arr;
    },
    goToWordDetail(wordId) {
      this.$router.push(`/word/${wordId}`);
    },
    speakWord(word) {
      const text = word.kana && word.kana !== '/' ? word.kana : (word.kanji && word.kanji !== '/' ? word.kanji : '');
      speakJapanese(text);
    },
  },
  mounted() {
    this.fetchWords();
  },
};
</script>

<template>
  <div class="words-container">
    <div class="words-header">
      <h2>单词学习</h2>
      <div class="controls">
        <input 
          v-model="searchText" 
          type="text" 
          placeholder="搜索单词..."
          class="search-input"
        />
        <button @click="toggleHide('kana')" :class="{ active: hideFields.kana }" class="btn">
          {{ hideFields.kana ? '显示假名' : '隐藏假名' }}
        </button>
        <button @click="toggleHide('kanji')" :class="{ active: hideFields.kanji }" class="btn">
          {{ hideFields.kanji ? '显示汉字' : '隐藏汉字' }}
        </button>
        <button @click="toggleHide('chinese')" :class="{ active: hideFields.chinese }" class="btn">
          {{ hideFields.chinese ? '显示中文' : '隐藏中文' }}
        </button>
        <button @click="toggleShuffle" :class="{ active: isShuffled }" class="btn btn-primary">
          {{ isShuffled ? '恢复顺序' : '乱序' }}
        </button>
      </div>
    </div>

    <div class="words-list">
      <div 
        v-for="(word, idx) in filteredWords" 
        :key="word.id"
        @mouseenter="speakWord(word)"
        @click="goToWordDetail(word.id)"
        class="word-item"
      >
        <span class="word-number">{{ idx + 1 }}</span>
        <div class="word-content">
          <span v-if="!hideFields.kana" class="kana">{{ word.kana }}</span>
          <span v-if="!hideFields.kanji" class="kanji">{{ word.kanji }}</span>
          <span v-if="!hideFields.chinese" class="chinese">{{ word.chinese }}</span>
        </div>
      </div>
    </div>

    <p v-if="filteredWords.length === 0" class="no-results">
      未找到匹配的单词
    </p>
  </div>
</template>

<style scoped>
.words-container {
  max-width: 1100px;
  margin: 0 auto;
  padding: 20px;
}

.words-header {
  margin-bottom: 30px;
}

.words-header h2 {
  margin-bottom: 15px;
  color: #1f2937;
}

.controls {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  align-items: center;
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

.btn {
  padding: 8px 16px;
  background: #f3f4f6;
  border: 1px solid #d1d5db;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  transition: all 0.2s;
}

.btn:hover {
  background: #e5e7eb;
}

.btn.active {
  background: #3b82f6;
  color: white;
  border-color: #3b82f6;
}

.btn-primary {
  background: #3b82f6;
  color: white;
  border-color: #3b82f6;
}

.btn-primary:hover {
  background: #2563eb;
}

.words-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.word-item {
  display: flex;
  align-items: center;
  padding: 16px 20px;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
}

.word-item:hover {
  background: #f9fafb;
  border-color: #3b82f6;
  box-shadow: 0 2px 8px rgba(59, 130, 246, 0.1);
}

.word-number {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  background: #e5e7eb;
  border-radius: 50%;
  margin-right: 16px;
  font-weight: 600;
  color: #6b7280;
  flex-shrink: 0;
}

.word-content {
  display: flex;
  gap: 20px;
  flex: 1;
}

.kana, .kanji, .chinese {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.kana {
  flex: 1;
  min-width: 100px;
}

.kanji {
  flex: 1;
  min-width: 100px;
}

.chinese {
  flex: 2;
  min-width: 150px;
  color: #666;
}

.no-results {
  text-align: center;
  color: #9ca3af;
  padding: 40px 20px;
}
</style>
