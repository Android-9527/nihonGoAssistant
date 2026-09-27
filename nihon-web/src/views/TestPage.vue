<template>
  <section class="test-wrap">
    <header>
      <h1>{{ isReview ? '复习模式' : `第 ${chapter} 章单元测试` }}</h1>
      <p>{{ isReview ? '优先复习上次忘记与低掌握的条目' : '100% 单词与语法，自评并记录掌握度' }}</p>
    </header>

    <div v-if="loading" class="test-state">加载中...</div>

    <div v-else-if="errorText" class="test-state test-error">{{ errorText }}</div>

    <!-- 完成视图 -->
    <div v-else-if="finished" class="test-done">
      <h2>{{ isReview ? '本轮复习完成' : '本轮测试完成' }}</h2>
      <div class="done-stats">
        <div class="done-stat done-ok">认识/记得：{{ correctTotal }}</div>
        <div class="done-stat done-bad">忘记：{{ wrongTotal }}</div>
      </div>
      <p class="done-tip">忘记的条目已记入掌握度，明天再来复习效果更好。</p>
      <div class="done-actions">
        <button class="test-btn" @click="restart">再测一轮</button>
        <button class="test-btn" @click="goChapter">返回章节</button>
        <button v-if="!isReview" class="test-btn" @click="goHome">返回主页</button>
      </div>
    </div>

    <!-- 无内容（复习模式无推荐） -->
    <div v-else-if="noContent" class="test-state">
      <p>暂无待复习内容，先去「单元测试」测一轮吧。</p>
      <button class="test-btn" @click="goHome">返回主页</button>
    </div>

    <!-- 卡片流程 -->
    <template v-else>
      <div class="test-tabs">
        <button
          class="test-tab"
          :class="{ active: activeTab === 'word' }"
          @click="switchTab('word')"
        >
          单词测试
          <span v-if="wordProgress">（{{ wordProgress }}）</span>
        </button>
        <button
          class="test-tab"
          :class="{ active: activeTab === 'grammar' }"
          @click="switchTab('grammar')"
        >
          语法测试
          <span v-if="grammarProgress">（{{ grammarProgress }}）</span>
        </button>
      </div>

      <!-- 单词卡 -->
      <div v-if="activeTab === 'word'" class="flash-area">
        <div v-if="wordDeck.length" class="flash-meta">
          <span>第 {{ wordIndex + 1 }} / {{ wordDeck.length }} 个单词</span>
        </div>

        <div
          class="flash-card word-card"
          :class="{ revealed: wordRevealed }"
          @click="revealWord"
        >
          <div v-if="!wordRevealed" class="flash-front">
            <div class="flash-kana">{{ currentWord.kana }}</div>
            <div class="flash-hint">请回忆单词发音和释义</div>
          </div>
          <div v-else class="flash-back">
            <div class="flash-kana">{{ currentWord.kana }}</div>
            <div class="flash-kanji">{{ currentWord.kanji && currentWord.kanji !== '/' ? currentWord.kanji : '（无汉字）' }}</div>
            <div class="flash-cn">{{ currentWord.chinese }}</div>
            <div class="flash-example">
              <div class="ex-jp">{{ currentWord.example?.japanese || '（暂无例句）' }}</div>
              <div class="ex-cn">{{ currentWord.example?.chinese || '' }}</div>
            </div>
          </div>
        </div>

        <div v-if="wordRevealed" class="flash-actions">
          <button class="test-btn btn-ok" @click="assessWord(true)">认识</button>
          <button class="test-btn btn-bad" @click="assessWord(false)">忘记</button>
        </div>
      </div>

      <!-- 语法卡 -->
      <div v-else class="flash-area">
        <div v-if="grammarDeck.length" class="flash-meta">
          <span>第 {{ grammarIndex + 1 }} / {{ grammarDeck.length }} 条语法</span>
        </div>

        <div
          class="flash-card grammar-card"
          :class="{ revealed: grammarRevealed }"
          @click="revealGrammar"
        >
          <div v-if="!grammarRevealed" class="flash-front">
            <div class="flash-sentence">{{ currentGrammar.example?.japanese || currentGrammar.template }}</div>
            <div class="flash-hint">请回忆这个句子的语法</div>
          </div>
          <div v-else class="flash-back">
            <div class="flash-template">{{ currentGrammar.template }}</div>
            <div class="flash-explanation">{{ currentGrammar.explanation }}</div>
          </div>
        </div>

        <div v-if="grammarRevealed" class="flash-actions">
          <button class="test-btn btn-ok" @click="assessGrammar(true)">记得语法</button>
          <button class="test-btn btn-bad" @click="assessGrammar(false)">忘记语法</button>
        </div>
      </div>

      <p v-if="submitError" class="test-state test-error">{{ submitError }}</p>
    </template>
  </section>
</template>

<script>
import { authHeaders } from '../store/user';
import { speakJapanese } from '../utils/speech';

function shuffle(arr) {
  const pool = [...arr];
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  return pool;
}

export default {
  data() {
    return {
      loading: true,
      errorText: '',
      submitError: '',
      isReview: false,
      chapter: 0,
      activeTab: 'word',
      // word
      allWords: [],
      sentencePool: [],
      wordDeck: [],
      wordIndex: 0,
      wordRevealed: false,
      wordRevealAt: 0,
      // grammar
      grammarDeck: [],
      grammarIndex: 0,
      grammarRevealed: false,
      grammarRevealAt: 0,
      // stats
      correctTotal: 0,
      wrongTotal: 0,
      finished: false,
      noContent: false,
    };
  },
  computed: {
    currentWord() {
      return this.wordDeck[this.wordIndex] || null;
    },
    currentGrammar() {
      return this.grammarDeck[this.grammarIndex] || null;
    },
    wordProgress() {
      if (!this.wordDeck.length) return '';
      return `${this.wordIndex} / ${this.wordDeck.length}`;
    },
    grammarProgress() {
      if (!this.grammarDeck.length) return '';
      return `${this.grammarIndex} / ${this.grammarDeck.length}`;
    },
  },
  async mounted() {
    this.isReview = this.$route.query.mode === 'review';
    this.chapter = Number(this.$route.query.chapter || 0);
    if (this.isReview) {
      await this.loadReview();
    } else if (this.chapter > 0) {
      await this.loadTest();
    } else {
      this.errorText = '缺少章节参数';
      this.loading = false;
    }
  },
  methods: {
    async loadTest() {
      try {
        const [wordsRes, grammarRes, sentencesRes] = await Promise.all([
          fetch(`/api/words?chapter=${this.chapter}`),
          fetch(`/api/grammar?chapter=${this.chapter}`),
          fetch(`/api/sentences?chapter=${this.chapter}`),
        ]);
        this.allWords = await wordsRes.json();
        const grammar = await grammarRes.json();
        this.sentencePool = await sentencesRes.json();
        this.buildDecks(this.allWords, grammar);
      } catch (error) {
        this.errorText = error.message || '加载测试数据失败';
      } finally {
        this.loading = false;
      }
    },
    async loadReview() {
      try {
        const recRes = await fetch('/api/review/recommendations?limit=60', { headers: authHeaders() });
        const data = await recRes.json();
        if (!recRes.ok) {
          throw new Error(data.error || '获取复习推荐失败');
        }
        if (!data.length) {
          this.noContent = true;
          this.loading = false;
          return;
        }
        const wordIds = new Set(
          data.filter((i) => i.element_type === 'word').map((i) => i.element_id),
        );
        const grammarIds = new Set(
          data.filter((i) => i.element_type === 'grammar').map((i) => i.element_id),
        );
        const [wordsRes, grammarRes, sentencesRes] = await Promise.all([
          fetch('/api/words'),
          fetch('/api/grammar'),
          fetch('/api/sentences'),
        ]);
        const allWords = await wordsRes.json();
        const allGrammar = await grammarRes.json();
        this.sentencePool = await sentencesRes.json();
        this.buildDecks(
          allWords.filter((w) => wordIds.has(w.id)),
          allGrammar.filter((g) => grammarIds.has(g.id)),
        );
      } catch (error) {
        this.errorText = error.message || '加载复习数据失败';
      } finally {
        this.loading = false;
      }
    },
    buildDecks(words, grammarList) {
      this.wordDeck = shuffle(
        words.map((w) => {
          const examples = this.sentencePool.filter((s) =>
            (s.tokens || []).some((t) => t.word_id === w.id),
          );
          const example = examples.length ? examples[Math.floor(Math.random() * examples.length)] : null;
          return { ...w, example };
        }),
      );
      this.grammarDeck = shuffle(
        grammarList.map((g) => {
          const examples = g.examples || [];
          const example = examples.length ? examples[Math.floor(Math.random() * examples.length)] : null;
          return {
            id: g.id,
            chapter: g.chapter,
            template: g.template,
            explanation: g.explanation,
            example,
          };
        }),
      );
      if (this.wordDeck.length === 0 && this.grammarDeck.length === 0) {
        this.noContent = true;
        return;
      }
      if (!this.wordDeck.length) this.activeTab = 'grammar';
      if (!this.grammarDeck.length) this.activeTab = 'word';
    },
    switchTab(tab) {
      this.activeTab = tab;
      this.submitError = '';
    },
    revealWord() {
      if (this.wordRevealed) return;
      this.wordRevealed = true;
      this.wordRevealAt = Date.now();
      this.speakCurrentWord();
    },
    speakCurrentWord() {
      const word = this.currentWord;
      if (!word) return;
      const text =
        word.kana && word.kana !== '/'
          ? word.kana
          : word.kanji && word.kanji !== '/'
            ? word.kanji
            : '';
      if (!text) return;
      speakJapanese(text, {
        ttsAudioId: word.tts_audio_id,
        entityType: 'word',
        entityId: word.id,
      });
    },
    revealGrammar() {
      if (this.grammarRevealed) return;
      this.grammarRevealed = true;
      this.grammarRevealAt = Date.now();
    },
    async submitAnswer(elementType, elementId, correct) {
      const durationMs = Date.now() - (elementType === 'word' ? this.wordRevealAt : this.grammarRevealAt);
      const res = await fetch('/api/test/submit', {
        method: 'POST',
        headers: { ...authHeaders(), 'Content-Type': 'application/json' },
        body: JSON.stringify({
          element_type: elementType,
          element_id: elementId,
          correct,
          duration_ms: Math.max(0, durationMs),
          chapter: this.isReview ? null : this.chapter,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.error || '提交失败');
      }
    },
    async assessWord(correct) {
      const word = this.currentWord;
      if (!word) return;
      this.submitError = '';
      try {
        await this.submitAnswer('word', word.id, correct);
      } catch (error) {
        this.submitError = error.message || '提交失败，请重试';
        return;
      }
      if (correct) this.correctTotal += 1;
      else this.wrongTotal += 1;
      this.wordIndex += 1;
      this.wordRevealed = false;
      if (this.wordIndex >= this.wordDeck.length) {
        if (this.grammarDeck.length && this.activeTab === 'word') {
          this.activeTab = 'grammar';
        } else {
          this.finished = true;
        }
      }
    },
    async assessGrammar(correct) {
      const grammar = this.currentGrammar;
      if (!grammar) return;
      this.submitError = '';
      try {
        await this.submitAnswer('grammar', grammar.id, correct);
      } catch (error) {
        this.submitError = error.message || '提交失败，请重试';
        return;
      }
      if (correct) this.correctTotal += 1;
      else this.wrongTotal += 1;
      this.grammarIndex += 1;
      this.grammarRevealed = false;
      if (this.grammarIndex >= this.grammarDeck.length) {
        this.finished = true;
      }
    },
    restart() {
      this.finished = false;
      this.wordIndex = 0;
      this.grammarIndex = 0;
      this.wordRevealed = false;
      this.grammarRevealed = false;
      this.correctTotal = 0;
      this.wrongTotal = 0;
      this.submitError = '';
      // 重新随机例句
      this.buildDecks(this.wordDeck.map(({ example, ...w }) => w), this.grammarDeck.map(({ example, ...g }) => g));
    },
    goChapter() {
      if (this.isReview) {
        this.$router.push('/home');
      } else {
        this.$router.push(`/textbook/minna-nihongo-1/chapter/${this.chapter}/learn`);
      }
    },
    goHome() {
      this.$router.push('/home');
    },
  },
};
</script>

<style scoped>
.test-wrap {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

header h1 {
  margin: 0;
  color: #0f172a;
}

header p {
  margin: 6px 0 0;
  color: #475569;
}

.test-tabs {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.test-tab {
  border: 1px solid #cbd5e1;
  background: #fff;
  color: #1f2937;
  border-radius: 10px;
  padding: 9px 16px;
  cursor: pointer;
  font-size: 14px;
}

.test-tab.active {
  background: #22c55e;
  border-color: #22c55e;
  color: #fff;
  font-weight: 600;
}

.flash-area {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.flash-meta {
  color: #475569;
  font-size: 13px;
}

.flash-card {
  border: 1.5px solid #cbd5e1;
  background: #fff;
  border-radius: 16px;
  min-height: 220px;
  padding: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  text-align: center;
  transition: 0.2s ease;
}

.flash-card:hover {
  border-color: #94a3b8;
}

.word-card.revealed,
.grammar-card.revealed {
  cursor: default;
}

.flash-front {
  display: flex;
  flex-direction: column;
  gap: 14px;
  align-items: center;
}

.flash-kana {
  font-size: 42px;
  font-weight: 700;
  color: #111827;
}

.flash-sentence {
  font-size: 26px;
  font-weight: 600;
  color: #111827;
  line-height: 1.7;
}

.flash-hint {
  color: #64748b;
  font-size: 14px;
}

.flash-back {
  display: flex;
  flex-direction: column;
  gap: 8px;
  align-items: center;
}

.flash-kanji {
  font-size: 22px;
  font-weight: 600;
  color: #0f172a;
}

.flash-cn {
  font-size: 16px;
  color: #334155;
}

.flash-template {
  font-size: 24px;
  font-weight: 700;
  color: #0f172a;
}

.flash-explanation {
  font-size: 15px;
  color: #334155;
  white-space: pre-line;
  max-width: 640px;
}

.flash-example {
  margin-top: 10px;
  border: 1px dashed #cbd5e1;
  border-radius: 10px;
  padding: 10px 14px;
  background: #f8fafc;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.ex-jp {
  font-size: 16px;
  color: #111827;
}

.ex-cn {
  font-size: 13px;
  color: #64748b;
}

.flash-actions {
  display: flex;
  justify-content: center;
  gap: 14px;
  flex-wrap: wrap;
}

.test-btn {
  border: 1px solid #cbd5e1;
  background: #fff;
  color: #1f2937;
  border-radius: 10px;
  padding: 10px 22px;
  cursor: pointer;
  font-size: 15px;
}

.test-btn:hover {
  border-color: #94a3b8;
}

.btn-ok {
  background: #f0fdf4;
  border-color: #86efac;
  color: #15803d;
  font-weight: 600;
}

.btn-bad {
  background: #fff1f2;
  border-color: #fecaca;
  color: #b91c1c;
  font-weight: 600;
}

.test-state {
  color: #64748b;
  padding: 20px 0;
}

.test-error {
  color: #b91c1c;
}

.test-done {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 24px;
  text-align: center;
}

.test-done h2 {
  margin: 0;
  color: #0f172a;
}

.done-stats {
  margin-top: 14px;
  display: flex;
  justify-content: center;
  gap: 20px;
  flex-wrap: wrap;
}

.done-stat {
  font-size: 18px;
  font-weight: 700;
}

.done-ok {
  color: #15803d;
}

.done-bad {
  color: #b91c1c;
}

.done-tip {
  margin: 12px 0 0;
  color: #64748b;
  font-size: 13px;
}

.done-actions {
  margin-top: 18px;
  display: flex;
  justify-content: center;
  gap: 10px;
  flex-wrap: wrap;
}
</style>
