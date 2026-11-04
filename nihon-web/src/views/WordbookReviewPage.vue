<template>
  <section class="review-wrap">
    <header>
      <h1>{{ isEn() ? 'Wordbook Review' : '单词本复习' }}</h1>
      <p v-if="deck.length" class="meta">
        {{ isEn() ? `Word ${index} / ${deck.length}` : `单词 ${index} / ${deck.length}` }}
      </p>
    </header>

    <div v-if="loading" class="empty">{{ isEn() ? 'Loading...' : '加载中...' }}</div>

    <div v-else-if="noContent" class="empty-box">
      <p>{{ isEn() ? 'Your wordbook is empty. Select some words first.' : '单词本还是空的，先去选词添加吧。' }}</p>
      <button class="btn-back" type="button" @click="goSelect">{{ isEn() ? 'Select words' : '去选词' }}</button>
    </div>

    <template v-else-if="!finished">
      <div v-if="errorText" class="state error">{{ errorText }}</div>
      <div v-if="current" class="flash-area">
        <div class="flash-card word-card" :class="{ revealed }" @click="reveal">
          <template v-if="!revealed">
            <div class="flash-front">
              <div class="flash-kana">{{ current.kana }}</div>
              <div class="flash-hint">{{ isEn() ? 'Tap to reveal' : '点击查看释义' }}</div>
              <div v-if="current.reason" class="flash-reason">{{ current.reason }}</div>
            </div>
          </template>
          <template v-else>
            <div class="flash-back">
              <div v-if="current.kanji && current.kanji !== '/'" class="flash-kanji">{{ current.kanji }}</div>
              <div class="flash-meaning">{{ pickText(current.chinese, current.english) }}</div>
              <div v-if="current.example" class="flash-example">
                <div class="ex-jp">{{ current.example.japanese }}</div>
                <div class="ex-cn">{{ pickText(current.example.chinese, current.example.english) }}</div>
              </div>
            </div>
          </template>
        </div>
        <div v-if="revealed" class="flash-actions">
          <button class="btn-ok" type="button" @click="assess(true)">{{ isEn() ? 'Remembered' : '记得' }}</button>
          <button class="btn-bad" type="button" @click="assess(false)">{{ isEn() ? 'Forgot' : '忘记' }}</button>
        </div>
      </div>
    </template>

    <div v-else class="done-box">
      <h2>{{ isEn() ? 'Review Complete' : '复习完成' }}</h2>
      <p class="stat">{{ isEn() ? `Correct ${correctTotal} / ${total}` : `答对 ${correctTotal} / ${total}` }}</p>
      <div class="done-actions">
        <button class="btn-ok" type="button" @click="restart">{{ isEn() ? 'Review again' : '再来一轮' }}</button>
        <button class="btn-back" type="button" @click="goBack">{{ isEn() ? 'Back to wordbook' : '返回单词本' }}</button>
      </div>
    </div>
  </section>
</template>

<script>
import { authHeaders } from '../store/user';
import { speakJapanese } from '../utils/speech';
import languageStore from '../store/language';

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
      noContent: false,
      finished: false,
      errorText: '',
      deck: [],
      index: 0,
      revealed: false,
      correctTotal: 0,
      revealAt: 0,
    };
  },
  computed: {
    current() {
      return this.deck[this.index] || null;
    },
    total() {
      return this.correctTotal + (this.deck.length - this.index);
    },
  },
  methods: {
    isEn() {
      return languageStore.isEn();
    },
    pickText(zh, en) {
      return languageStore.pickText(zh, en);
    },
    async loadDeck() {
      try {
        // 调度取词：到期旧词（上次忘记/到期复习）优先约 70%，新词随机补 30%
        const res = await fetch('/api/wordbook/review?limit=30', { headers: authHeaders() });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || '加载失败');
        if (!data.length) {
          this.noContent = true;
          this.loading = false;
          return;
        }
        this.deck = shuffle(data);
        this.speakCurrent();
      } catch (error) {
        this.errorText = error.message || '加载复习数据失败';
      } finally {
        this.loading = false;
      }
    },
    reveal() {
      if (this.revealed) return;
      this.revealed = true;
      this.revealAt = Date.now();
    },
    speakCurrent() {
      const w = this.current;
      if (!w) return;
      const text = w.kana && w.kana !== '/' ? w.kana : w.kanji;
      if (!text) return;
      speakJapanese(text, {
        ttsAudioId: w.tts_audio_id,
        entityType: 'word',
        entityId: w.id,
      });
    },
    async assess(correct) {
      const w = this.current;
      if (!w) return;
      this.errorText = '';
      try {
        const durationMs = Math.max(0, Date.now() - this.revealAt);
        const res = await fetch('/api/test/submit', {
          method: 'POST',
          headers: { ...authHeaders(), 'Content-Type': 'application/json' },
          body: JSON.stringify({
            element_type: 'word',
            element_id: w.id,
            correct,
            duration_ms: durationMs,
            chapter: w.chapter,
          }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || '提交失败');
      } catch (error) {
        this.errorText = error.message || '提交失败，请重试';
        return;
      }
      if (correct) this.correctTotal += 1;
      this.index += 1;
      this.revealed = false;
      if (this.index >= this.deck.length) {
        this.finished = true;
      } else {
        // 下一张正面假名出现时自动播放语音
        this.speakCurrent();
      }
    },
    restart() {
      this.finished = false;
      this.index = 0;
      this.revealed = false;
      this.correctTotal = 0;
      this.errorText = '';
      this.deck = shuffle(this.deck);
      this.speakCurrent();
    },
    goSelect() {
      this.$router.push('/wordbook/select');
    },
    goBack() {
      this.$router.push('/wordbook');
    },
  },
  mounted() {
    this.loadDeck();
  },
};
</script>

<style scoped>
.review-wrap { display: flex; flex-direction: column; gap: 14px; }
header h1 { margin: 0; color: #0f172a; }
.meta { margin: 6px 0 0; color: #475569; }
.empty { color: #64748b; padding: 16px 0; }
.empty-box { text-align: center; padding: 30px 0; color: #64748b; display: flex; flex-direction: column; gap: 14px; align-items: center; }

.flash-area { display: flex; flex-direction: column; gap: 12px; }
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
.flash-card:hover { border-color: #94a3b8; }
.flash-card.revealed { cursor: default; }
.flash-front { display: flex; flex-direction: column; gap: 14px; align-items: center; }
.flash-kana { font-size: 42px; font-weight: 700; color: #111827; }
.flash-kanji { font-size: 22px; color: #475569; }
.flash-hint { color: #64748b; font-size: 14px; }
.flash-reason {
  margin-top: 12px;
  background: #fef3c7;
  color: #92400e;
  border-radius: 999px;
  padding: 3px 10px;
  font-size: 12px;
}
.flash-back { display: flex; flex-direction: column; gap: 12px; align-items: center; }
.flash-meaning { font-size: 22px; font-weight: 600; color: #111827; }
.flash-example { display: flex; flex-direction: column; gap: 6px; }
.ex-jp { font-size: 18px; color: #0f766e; line-height: 1.6; }
.ex-cn { font-size: 14px; color: #64748b; }

.flash-actions { display: flex; justify-content: center; gap: 10px; }
.btn-ok {
  border: 0;
  border-radius: 10px;
  padding: 10px 22px;
  background: #16a34a;
  color: #fff;
  cursor: pointer;
  font-size: 15px;
}
.btn-bad {
  border: 1px solid #f87171;
  background: #fff;
  color: #dc2626;
  border-radius: 10px;
  padding: 10px 22px;
  cursor: pointer;
  font-size: 15px;
}
.btn-sound { display: none; }
.btn-back {
  border: 1px solid #94a3b8;
  background: #fff;
  color: #334155;
  border-radius: 10px;
  padding: 10px 18px;
  cursor: pointer;
}

.done-box { text-align: center; padding: 26px 0; display: flex; flex-direction: column; gap: 12px; align-items: center; }
.done-box h2 { margin: 0; color: #0f172a; }
.stat { color: #334155; font-size: 18px; font-weight: 600; margin: 0; }
.done-actions { display: flex; gap: 10px; }

.state.error { color: #dc2626; }
</style>
