<template>
  <section class="page-wrap">
    <header class="head">
      <h1>{{ isEn() ? 'Select Words' : '选词' }}</h1>
      <p>{{ isEn() ? 'Check words, then click "Add to wordbook".' : '勾选单词，再点“加入背单词”生效。' }}</p>
    </header>

    <div class="chapter-bar">
      <button class="nav-arrow" type="button" @click="prevChapter">‹</button>
      <select v-model.number="chapter" class="chapter-select" @change="loadWords">
        <option v-for="n in 50" :key="n" :value="n">
          {{ isEn() ? `Chapter ${n}` : `第 ${n} 章` }}
        </option>
      </select>
      <button class="nav-arrow" type="button" @click="nextChapter">›</button>
      <span class="added-count">{{ isEn() ? `Saved: ${savedIds.size}` : `已添加 ${savedIds.size} 个` }}</span>
      <button class="btn-all" type="button" :disabled="!words.length || loading" @click="toggleAll">
        {{ allSelected ? (isEn() ? 'Deselect all' : '取消全选') : (isEn() ? 'Select all' : '全选') }}
      </button>
      <button class="btn-submit" type="button" :disabled="!words.length || loading || busy" @click="syncSelected">
        {{ isEn() ? `Add to wordbook (${selectedIds.size})` : `加入背单词 (${selectedIds.size})` }}
      </button>
    </div>

    <div v-if="loading" class="empty">{{ isEn() ? 'Loading...' : '加载中...' }}</div>
    <template v-else>
      <div v-if="!words.length" class="empty">{{ isEn() ? 'No words in this chapter.' : '该章没有单词。' }}</div>
      <label v-for="w in words" :key="w.id" class="word-row" :class="{ checked: selectedIds.has(w.id) }">
        <input
          type="checkbox"
          class="word-check"
          :checked="selectedIds.has(w.id)"
          @change="toggleWord(w.id)"
        />
        <div class="word-main">
          <span class="w-kana">{{ w.kana }}</span>
          <span v-if="w.kanji && w.kanji !== '/'" class="w-kanji">{{ w.kanji }}</span>
          <span class="w-meaning">{{ pickText(w.chinese, w.english) }}</span>
        </div>
        <span v-if="savedIds.has(w.id)" class="tag-saved">{{ isEn() ? 'Saved' : '已加入' }}</span>
        <button class="icon-btn" type="button" @click.stop="speak(w)" title="发音">🔊</button>
      </label>
    </template>
  </section>
</template>

<script>
import { authHeaders } from '../store/user';
import { speakJapanese } from '../utils/speech';
import languageStore from '../store/language';

export default {
  data() {
    return {
      chapter: 1,
      loading: true,
      busy: false,
      words: [],
      savedIds: new Set(),
      selectedIds: new Set(),
    };
  },
  computed: {
    allSelected() {
      return this.words.length > 0 && this.words.every((w) => this.selectedIds.has(w.id));
    },
  },
  methods: {
    isEn() {
      return languageStore.isEn();
    },
    pickText(zh, en) {
      return languageStore.pickText(zh, en);
    },
    async loadWords() {
      this.loading = true;
      try {
        const res = await fetch(`/api/words?chapter=${this.chapter}`);
        const data = await res.json();
        this.words = data;
      } catch (error) {
        this.words = [];
      } finally {
        this.loading = false;
      }
    },
    async loadSavedIds() {
      try {
        const res = await fetch('/api/wordbook', { headers: authHeaders() });
        const data = await res.json();
        this.savedIds = new Set(data.map((w) => w.id));
        this.selectedIds = new Set(this.savedIds);
      } catch (error) {
        this.savedIds = new Set();
        this.selectedIds = new Set();
      }
    },
    toggleWord(id) {
      const next = new Set(this.selectedIds);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      this.selectedIds = next;
    },
    toggleAll() {
      if (!this.words.length) return;
      const next = new Set(this.selectedIds);
      if (this.allSelected) {
        for (const w of this.words) next.delete(w.id);
      } else {
        for (const w of this.words) next.add(w.id);
      }
      this.selectedIds = next;
    },
    async syncSelected() {
      if (this.busy) return;
      const toAdd = [...this.selectedIds].filter((id) => !this.savedIds.has(id));
      const toRemove = [...this.savedIds].filter((id) => !this.selectedIds.has(id));
      if (!toAdd.length && !toRemove.length) return;
      this.busy = true;
      try {
        await Promise.all(toAdd.map((id) => this.postAdd(id)));
        await Promise.all(toRemove.map((id) => this.removeById(id)));
        this.savedIds = new Set(this.selectedIds);
      } catch (error) {
        alert(error.message || '保存失败');
      } finally {
        this.busy = false;
      }
    },
    async postAdd(wordId) {
      const res = await fetch('/api/wordbook', {
        method: 'POST',
        headers: { ...authHeaders(), 'Content-Type': 'application/json' },
        body: JSON.stringify({ word_id: wordId }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || '添加失败');
    },
    async removeById(wordId) {
      const res = await fetch(`/api/wordbook/${wordId}`, {
        method: 'DELETE',
        headers: authHeaders(),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || '移除失败');
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
    prevChapter() {
      if (this.chapter > 1) {
        this.chapter -= 1;
        this.loadWords();
      }
    },
    nextChapter() {
      if (this.chapter < 50) {
        this.chapter += 1;
        this.loadWords();
      }
    },
    goBack() {
      this.$router.push('/wordbook');
    },
  },
  mounted() {
    this.loadSavedIds();
    this.loadWords();
  },
};
</script>

<style scoped>
.page-wrap { display: flex; flex-direction: column; gap: 12px; }
.head h1 { margin: 0; color: #0f172a; }
.head p { margin: 6px 0 0; color: #475569; }

.chapter-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
.nav-arrow {
  border: 1px solid #cbd5e1;
  background: #fff;
  border-radius: 8px;
  width: 34px;
  height: 34px;
  font-size: 18px;
  cursor: pointer;
}
.chapter-select {
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  padding: 8px 10px;
  font-size: 14px;
  background: #fff;
}
.added-count { color: #0f766e; font-size: 13px; font-weight: 600; margin-left: auto; }
.btn-all {
  border: 1px solid #0f766e;
  background: #fff;
  color: #0f766e;
  border-radius: 8px;
  padding: 8px 14px;
  cursor: pointer;
  font-size: 13px;
}
.btn-all:disabled { background: #f1f5f9; color: #94a3b8; border-color: #cbd5e1; cursor: not-allowed; }
.btn-submit {
  border: 0;
  border-radius: 8px;
  padding: 8px 14px;
  background: #16a34a;
  color: #fff;
  cursor: pointer;
  font-size: 13px;
}
.btn-submit:disabled { background: #cbd5e1; cursor: not-allowed; }
.empty { color: #64748b; padding: 16px 0; }

.word-row {
  display: flex;
  align-items: center;
  gap: 10px;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: 10px 12px;
  cursor: pointer;
  transition: 0.15s ease;
}
.word-row:hover { border-color: #94a3b8; }
.word-row.checked { border-color: #6ee7b7; background: #f0fdfa; }
.word-check {
  width: 18px;
  height: 18px;
  accent-color: #10b981;
  cursor: pointer;
  flex-shrink: 0;
}
.word-main { display: flex; align-items: baseline; gap: 8px; flex-wrap: wrap; flex: 1; }
.w-kana { font-size: 17px; font-weight: 700; color: #111827; }
.w-kanji { font-size: 15px; color: #475569; }
.w-meaning { font-size: 13px; color: #64748b; }
.tag-saved { color: #16a34a; font-size: 12px; font-weight: 600; flex-shrink: 0; }
.icon-btn {
  border: 1px solid #cbd5e1;
  background: #fff;
  border-radius: 8px;
  width: 32px;
  height: 32px;
  cursor: pointer;
  flex-shrink: 0;
}
</style>
