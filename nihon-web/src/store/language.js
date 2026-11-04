import { ref } from 'vue';

const LANG_KEY = 'nihon_lang';

// 'zh' = 中文模式（默认），'en' = English 模式
const lang = ref(localStorage.getItem(LANG_KEY) === 'en' ? 'en' : 'zh');

export function isEn() {
  return lang.value === 'en';
}

export function toggleLang() {
  lang.value = lang.value === 'en' ? 'zh' : 'en';
  localStorage.setItem(LANG_KEY, lang.value);
}

// 内容字段回退：英文为空时退回中文，避免未翻译的章节显示空白
export function pickText(zh, en) {
  if (isEn()) {
    return en && String(en).trim() ? en : zh;
  }
  return zh;
}

export default {
  lang,
  isEn,
  toggleLang,
  pickText,
};
