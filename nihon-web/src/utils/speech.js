let cachedVoice = null;
let voicesLoaded = false;
let lastText = "";
let lastAt = 0;

function pickJapaneseVoice() {
  const voices = window.speechSynthesis.getVoices();
  if (!voices || voices.length === 0) {
    return null;
  }

  const direct = voices.find((v) => (v.lang || "").toLowerCase().startsWith("ja"));
  if (direct) {
    return direct;
  }

  const byName = voices.find((v) => {
    const info = `${v.name || ""} ${v.voiceURI || ""}`.toLowerCase();
    return info.includes("japanese") || info.includes("ja-jp") || info.includes("haruka") || info.includes("sayaka");
  });

  return byName || null;
}

function ensureVoiceCache() {
  if (voicesLoaded && cachedVoice) {
    return;
  }
  cachedVoice = pickJapaneseVoice();
  voicesLoaded = true;
}

if (typeof window !== "undefined" && window.speechSynthesis) {
  window.speechSynthesis.onvoiceschanged = () => {
    cachedVoice = pickJapaneseVoice();
    voicesLoaded = true;
  };
}

export function speakJapanese(text) {
  if (!text || typeof window === "undefined" || !window.speechSynthesis) {
    return;
  }

  const trimmed = String(text).trim();
  if (!trimmed) {
    return;
  }

  const now = Date.now();
  if (trimmed === lastText && now - lastAt < 700) {
    return;
  }

  ensureVoiceCache();

  const utterance = new SpeechSynthesisUtterance(trimmed);
  utterance.lang = "ja-JP";
  utterance.rate = 0.95;
  utterance.pitch = 1.0;
  if (cachedVoice) {
    utterance.voice = cachedVoice;
  }

  window.speechSynthesis.cancel();
  window.speechSynthesis.speak(utterance);

  lastText = trimmed;
  lastAt = now;
}
