<template>
  <section class="page-wrap">
    <header class="head">
      <h1>{{ isEn() ? 'My Wordbook' : '我的单词本' }}</h1>
      <p>{{ isEn() ? 'Search to add words, then review them anytime.' : '搜索添加单词，随时复习。' }}</p>
    </header>

    <div class="search-box">
      <form class="search-form" @submit.prevent="doSearch">
        <input v-model="keyword" type="text" :placeholder="isEn() ? 'Search kana / kanji / meaning...' : '搜索单词（假名/汉字/释义）...'" />
        <button type="submit" class="btn-primary">{{ isEn() ? 'Search' : '检索' }}</button>
      </form>
      <div class="tool-actions">
        <button class="btn-green" :disabled="!words.length" @click="goReview">
          {{ isEn() ? `Review (${words.length})` : `开始复习 (${words.length})` }}
        </button>
        <button class="btn-blue" @click="goSelect">{{ isEn() ? 'Select words' : '去选词' }}</button>
      </div>
    </div>

    <div v-if="searching" class="search-results">
      <div class="sub-title">{{ isEn() ? `Results (${searchResults.length})` : `检索结果（${searchResults.length}）` }}</div>
      <div v-if="!searchResults.length" class="empty">{{ isEn() ? 'No matching words.' : '没有找到匹配的单词' }}</div>
      <div v-for="w in searchResults" :key="'s' + w.id" class="word-row">
        <div class="word-main">
          <span class="w-kana">{{ w.kana }}</span>
          <span v-if="w.kanji && w.kanji !== '/'" class="w-kanji">{{ w.kanji }}</span>
          <span class="w-ch">{{ isEn() ? `Ch.${w.chapter} · ` : `第${w.chapter}章 · ` }}{{ pickText(w.chinese, w.english) }}</span>
        </div>
        <div class="word-ops">
          <button class="icon-btn" type="button" @click="speak(w)" title="发音">🔊</button>
          <button v-if="!savedIds.has(w.id)" class="btn-add" type="button" @click="addWord(w)">{{ isEn() ? 'Add' : '加入' }}</button>
          <span v-else class="tag-added">{{ isEn() ? 'Added' : '已加入' }}</span>
        </div>
      </div>
    </div>
  </section>
</template>

<script>
import { authHeaders } from '../store/user';
import { speakJapanese } from '../utils/speech';
import languageStore from '../store/language';

export default {
  data() {
    return {
      loading: true,
      words: [],
      savedIds: new Set(),
      keyword: '',
      searching: false,
      searchResults: [],
    };
  },
  methods: {
    isEn() {
      return languageStore.isEn();
    },
    pickText(zh, en) {
      return languageStore.pickText(zh, en);
    },
    async loadWordbook() {
      try {
        const res = await fetch('/api/wordbook', { headers: authHeaders() });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || '加载失败');
        this.words = data;
        this.savedIds = new Set(data.map((w) => w.id));
      } catch (error) {
        this.errorText = error.message || '加载单词本失败';
      } finally {
        this.loading = false;
      }
    },
    async doSearch() {
      const kw = this.keyword.trim();
      if (!kw) {
        this.searching = false;
        this.searchResults = [];
        return;
      }
      this.searching = true;
      try {
        const res = await fetch(`/api/words?search=${encodeURIComponent(kw)}`);
        const data = await res.json();
        this.searchResults = data;
      } catch (error) {
        this.searchResults = [];
      }
    },
    async addWord(w) {
      try {
        const res = await fetch('/api/wordbook', {
          method: 'POST',
          headers: { ...authHeaders(), 'Content-Type': 'application/json' },
          body: JSON.stringify({ word_id: w.id }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || '添加失败');
        this.savedIds.add(w.id);
        if (!this.words.some((x) => x.id === w.id)) {
          this.words.push(w);
        }
      } catch (error) {
        alert(error.message || '添加失败');
      }
    },
    speak(w) {
      const text = w.kana && w.kana !== '/' ? w.kana : w.kanji;
      if (!text) return;
      speakJapanese(text, {
        ttsAudioId: w.tts_audio_id,
        entityType: 'word',
        entityId: w.id,
      });
    },
    goReview() {
      this.$router.push('/wordbook/review');
    },
    goSelect() {
      this.$router.push('/wordbook/select');
    },
  },
  mounted() {
    this.loadWordbook();
  },
};
</script>

<style scoped>
.page-wrap { display: flex; flex-direction: column; gap: 14px; }
.head h1 { margin: 0; color: #0f172a; }
.head p { margin: 6px 0 0; color: #475569; }

.search-box { display: flex; flex-direction: column; gap: 10px; }
.search-form { display: flex; gap: 8px; }
.search-form input {
  flex: 1;
  border: 1px solid #cbd5e1;
  border-radius: 10px;
  padding: 10px 12px;
  font-size: 14px;
}
.btn-primary {
  border: 0;
  border-radius: 10px;
  padding: 10px 16px;
  background: #0f766e;
  color: #fff;
  cursor: pointer;
}
.tool-actions { display: flex; gap: 8px; }
.btn-green {
  border: 0;
  border-radius: 10px;
  padding: 10px 16px;
  background: #16a34a;
  color: #fff;
  cursor: pointer;
  font-size: 14px;
}
.btn-green:disabled { background: #cbd5e1; cursor: not-allowed; }
.btn-blue {
  border: 1px solid #0284c7;
  background: #fff;
  color: #0284c7;
  border-radius: 10px;
  padding: 10px 16px;
  cursor: pointer;
  font-size: 14px;
}

.sub-title { font-weight: 600; color: #334155; margin-top: 4px; }
.empty { color: #64748b; padding: 18px 0; }

.search-results { display: flex; flex-direction: column; gap: 8px; }
.word-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: 10px 12px;
  flex-wrap: wrap;
}
.word-main { display: flex; align-items: baseline; gap: 8px; flex-wrap: wrap; }
.w-kana { font-size: 17px; font-weight: 700; color: #111827; }
.w-kanji { font-size: 15px; color: #475569; }
.w-ch { font-size: 13px; color: #64748b; }
.word-ops { display: flex; align-items: center; gap: 8px; }
.icon-btn {
  border: 1px solid #cbd5e1;
  background: #fff;
  border-radius: 8px;
  width: 32px;
  height: 32px;
  cursor: pointer;
}
.btn-add {
  border: 0;
  border-radius: 8px;
  padding: 6px 12px;
  background: #16a34a;
  color: #fff;
  cursor: pointer;
}
.tag-added { color: #16a34a; font-size: 13px; font-weight: 600; }
</style>
