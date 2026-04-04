let cachedVoice = null;
let voicesLoaded = false;
let lastText = "";
let lastAt = 0;
let activeAudio = null;
let activeObjectUrl = null;

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

export async function speakJapanese(text, options = {}) {
  if (!text || typeof window === "undefined") {
    return false;
  }

  const trimmed = String(text).trim();
  if (!trimmed) {
    return false;
  }

  const now = Date.now();
  if (trimmed === lastText && now - lastAt < 700) {
    return true;
  }

  try {
    const hasAudioId = Number.isInteger(options.ttsAudioId) && options.ttsAudioId > 0;
    const hasEntity = !!options.entityType && Number.isInteger(options.entityId) && options.entityId > 0;

    if (hasAudioId || hasEntity) {
      const params = new URLSearchParams();
      if (hasAudioId) {
        params.set("tts_audio_id", String(options.ttsAudioId));
      } else {
        params.set("entity_type", String(options.entityType));
        params.set("entity_id", String(options.entityId));
      }

      const response = await fetch(`/api/tts/audio?${params.toString()}`);
      if (response.ok) {
        const blob = await response.blob();

        if (activeAudio) {
          activeAudio.pause();
          activeAudio = null;
        }
        if (activeObjectUrl) {
          URL.revokeObjectURL(activeObjectUrl);
          activeObjectUrl = null;
        }

        activeObjectUrl = URL.createObjectURL(blob);
        activeAudio = new Audio(activeObjectUrl);
        await activeAudio.play();

        lastText = trimmed;
        lastAt = now;
        return true;
      }
    }
  } catch (err) {
    console.warn("Backend TTS playback failed, fallback to browser TTS:", err);
  }

  if (!window.speechSynthesis) {
    return false;
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
  return true;
}
