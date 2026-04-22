from __future__ import annotations

import argparse
import os
import sqlite3
import time
from pathlib import Path

import google.auth
from google.api_core import exceptions as gax_exceptions
from google.cloud import texttospeech


BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent
DB_PATH = PROJECT_DIR / "nihon_assistant_data.db"
AUDIO_DIR = BASE_DIR / "audio"

VOICE_NAME = "ja-JP-Chirp3-HD-Puck"
LANGUAGE_CODE = "ja-JP"
QUOTA_PROJECT = os.getenv("GOOGLE_CLOUD_QUOTA_PROJECT", "")


def get_tts_client() -> texttospeech.TextToSpeechClient:
    credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    if QUOTA_PROJECT:
        credentials = credentials.with_quota_project(QUOTA_PROJECT)
    # REST transport is generally more stable than gRPC in proxied networks.
    return texttospeech.TextToSpeechClient(credentials=credentials, transport="rest")


def is_retryable_network_error(exc: Exception) -> bool:
    msg = str(exc)
    retry_markers = [
        "ConnectionResetError(10054",
        "UNAVAILABLE",
        "ServiceUnavailable",
        "Getting metadata from plugin failed",
        "Connection aborted",
        "EOF occurred in violation of protocol",
    ]
    return isinstance(exc, (gax_exceptions.ServiceUnavailable, gax_exceptions.DeadlineExceeded)) or any(
        marker in msg for marker in retry_markers
    )


def ensure_tts_audio_table(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS tts_audio (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT NOT NULL,
            entity_id INTEGER NOT NULL,
            chapter INTEGER,
            text_source TEXT NOT NULL,
            text_value TEXT NOT NULL,
            voice_name TEXT NOT NULL,
            language_code TEXT NOT NULL,
            audio_encoding TEXT NOT NULL,
            file_path TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'done',
            error_msg TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(entity_type, entity_id, voice_name, audio_encoding)
        )
        """
    )
    conn.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_tts_audio_entity
        ON tts_audio(entity_type, entity_id)
        """
    )
    conn.commit()


def synthesize_text(client: texttospeech.TextToSpeechClient, text: str) -> bytes:
    input_text = texttospeech.SynthesisInput(text=text)
    voice = texttospeech.VoiceSelectionParams(language_code=LANGUAGE_CODE, name=VOICE_NAME)
    audio_config = texttospeech.AudioConfig(audio_encoding=texttospeech.AudioEncoding.MP3)
    response = client.synthesize_speech(input=input_text, voice=voice, audio_config=audio_config)
    return response.audio_content


def upsert_tts_row(
    conn: sqlite3.Connection,
    entity_type: str,
    entity_id: int,
    chapter: int,
    text_source: str,
    text_value: str,
    file_path: Path,
    status: str,
    error_msg: str = "",
) -> None:
    file_path_obj = Path(file_path)
    try:
        stored_path = file_path_obj.resolve().relative_to(PROJECT_DIR.resolve()).as_posix()
    except Exception:
        stored_path = str(file_path_obj)

    conn.execute(
        """
        INSERT INTO tts_audio(
            entity_type, entity_id, chapter, text_source, text_value,
            voice_name, language_code, audio_encoding, file_path, status, error_msg, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(entity_type, entity_id, voice_name, audio_encoding)
        DO UPDATE SET
            chapter=excluded.chapter,
            text_source=excluded.text_source,
            text_value=excluded.text_value,
            file_path=excluded.file_path,
            status=excluded.status,
            error_msg=excluded.error_msg,
            updated_at=CURRENT_TIMESTAMP
        """,
        (
            entity_type,
            entity_id,
            chapter,
            text_source,
            text_value,
            VOICE_NAME,
            LANGUAGE_CODE,
            "MP3",
            stored_path,
            status,
            error_msg,
        ),
    )


def already_done(conn: sqlite3.Connection, entity_type: str, entity_id: int) -> bool:
    row = conn.execute(
        """
        SELECT file_path, status
        FROM tts_audio
        WHERE entity_type = ? AND entity_id = ? AND voice_name = ? AND audio_encoding = 'MP3'
        """,
        (entity_type, entity_id, VOICE_NAME),
    ).fetchone()
    if not row:
        return False
    file_path, status = row
    return status == "done" and file_path and Path(file_path).exists()


def fetch_word_rows(conn: sqlite3.Connection, chapter_start: int, chapter_end: int) -> list[tuple]:
    return conn.execute(
        """
        SELECT id, chapter, kana, kanji
        FROM word
        WHERE chapter BETWEEN ? AND ?
        ORDER BY chapter, id
        """,
        (chapter_start, chapter_end),
    ).fetchall()


def fetch_sentence_rows(
    conn: sqlite3.Connection,
    chapter_start: int,
    chapter_end: int,
    sentence_ids: list[int] | None = None,
) -> list[tuple]:
    if sentence_ids:
        placeholders = ",".join("?" for _ in sentence_ids)
        sql = f"""
        SELECT id, chapter, jp_sentence
        FROM sentence
        WHERE chapter BETWEEN ? AND ?
          AND id IN ({placeholders})
          AND TRIM(COALESCE(jp_sentence, '')) <> ''
        ORDER BY chapter, id
        """
        params: tuple = (chapter_start, chapter_end, *sentence_ids)
        return conn.execute(sql, params).fetchall()

    return conn.execute(
        """
        SELECT id, chapter, jp_sentence
        FROM sentence
        WHERE chapter BETWEEN ? AND ? AND TRIM(COALESCE(jp_sentence, '')) <> ''
        ORDER BY chapter, id
        """,
        (chapter_start, chapter_end),
    ).fetchall()


def run_batch(
    target: str,
    chapter_start: int,
    chapter_end: int,
    sleep_seconds: float,
    max_retries: int,
    sentence_ids: list[int] | None = None,
) -> None:
    if not DB_PATH.exists():
        raise FileNotFoundError(f"DB not found: {DB_PATH}")

    if not QUOTA_PROJECT:
        print("提示: 未设置 GOOGLE_CLOUD_QUOTA_PROJECT，建议先设置以避免配额归属问题。")

    AUDIO_DIR.mkdir(parents=True, exist_ok=True)

    client = get_tts_client()
    conn = sqlite3.connect(DB_PATH)
    try:
        ensure_tts_audio_table(conn)

        total = 0
        success = 0
        failed = 0
        skipped = 0

        if target in ("word", "both"):
            rows = fetch_word_rows(conn, chapter_start, chapter_end)
            print(f"开始处理 word，共 {len(rows)} 条")
            for word_id, chapter, kana, kanji in rows:
                total += 1
                if already_done(conn, "word", word_id):
                    skipped += 1
                    continue

                text_value = (kana or "").strip() or (kanji or "").strip()
                if not text_value:
                    skipped += 1
                    continue

                out_dir = AUDIO_DIR / "word" / f"chapter_{chapter}"
                out_dir.mkdir(parents=True, exist_ok=True)
                out_file = out_dir / f"word_{word_id}.mp3"

                ok = False
                last_error = ""
                for attempt in range(max_retries):
                    try:
                        audio = synthesize_text(client, text_value)
                        out_file.write_bytes(audio)
                        upsert_tts_row(conn, "word", word_id, chapter, "kana", text_value, out_file, "done")
                        conn.commit()
                        success += 1
                        ok = True
                        break
                    except Exception as e:
                        last_error = str(e)
                        if is_retryable_network_error(e):
                            client = get_tts_client()
                        wait = min(10, 1.5 * (2 ** attempt))
                        time.sleep(wait)

                if not ok:
                    failed += 1
                    upsert_tts_row(conn, "word", word_id, chapter, "kana", text_value, out_file, "error", last_error)
                    conn.commit()

                time.sleep(sleep_seconds)

        if target in ("sentence", "both"):
            rows = fetch_sentence_rows(conn, chapter_start, chapter_end, sentence_ids=sentence_ids)
            print(f"开始处理 sentence，共 {len(rows)} 条")
            for sentence_id, chapter, jp_sentence in rows:
                total += 1
                if already_done(conn, "sentence", sentence_id):
                    skipped += 1
                    continue

                text_value = (jp_sentence or "").strip()
                if not text_value:
                    skipped += 1
                    continue

                out_dir = AUDIO_DIR / "sentence" / f"chapter_{chapter}"
                out_dir.mkdir(parents=True, exist_ok=True)
                out_file = out_dir / f"sentence_{sentence_id}.mp3"

                ok = False
                last_error = ""
                for attempt in range(max_retries):
                    try:
                        audio = synthesize_text(client, text_value)
                        out_file.write_bytes(audio)
                        upsert_tts_row(conn, "sentence", sentence_id, chapter, "jp_sentence", text_value, out_file, "done")
                        conn.commit()
                        success += 1
                        ok = True
                        break
                    except Exception as e:
                        last_error = str(e)
                        if is_retryable_network_error(e):
                            client = get_tts_client()
                        wait = min(10, 1.5 * (2 ** attempt))
                        time.sleep(wait)

                if not ok:
                    failed += 1
                    upsert_tts_row(conn, "sentence", sentence_id, chapter, "jp_sentence", text_value, out_file, "error", last_error)
                    conn.commit()

                time.sleep(sleep_seconds)

        print("批量完成")
        print(f"- total: {total}")
        print(f"- success: {success}")
        print(f"- failed: {failed}")
        print(f"- skipped(done/empty): {skipped}")
        print(f"- audio dir: {AUDIO_DIR}")
    finally:
        conn.close()


def run_single_mode() -> None:
    if not QUOTA_PROJECT:
        print("提示: 未设置 GOOGLE_CLOUD_QUOTA_PROJECT，若出现配额相关错误请先设置该环境变量。")
    print("请输入日语句子，然后回车：")
    text = input().strip()
    if not text:
        raise SystemExit("没有输入内容，已退出。")

    client = get_tts_client()
    out_file = BASE_DIR / "output.mp3"
    last_error = ""
    for attempt in range(4):
        try:
            out_file.write_bytes(synthesize_text(client, text))
            break
        except Exception as e:
            last_error = str(e)
            if is_retryable_network_error(e):
                client = get_tts_client()
            time.sleep(min(10, 1.5 * (2 ** attempt)))
    else:
        raise RuntimeError(f"TTS failed after retries: {last_error}")
    print(f"已生成音频: {out_file}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="TTS single + batch tool for word/sentence")
    parser.add_argument("--mode", choices=["single", "batch"], default="single")
    parser.add_argument("--target", choices=["word", "sentence", "both"], default="both")
    parser.add_argument("--chapter-start", type=int, default=1)
    parser.add_argument("--chapter-end", type=int, default=25)
    parser.add_argument("--sleep", type=float, default=0.25)
    parser.add_argument("--max-retries", type=int, default=4)
    parser.add_argument(
        "--sentence-ids",
        type=str,
        default="",
        help="仅处理指定句子ID，逗号分隔，如 5799,5800,5801",
    )
    args = parser.parse_args()

    sentence_ids: list[int] | None = None
    if args.sentence_ids.strip():
        sentence_ids = [int(x.strip()) for x in args.sentence_ids.split(",") if x.strip()]

    if args.mode == "single":
        run_single_mode()
    else:
        run_batch(
            target=args.target,
            chapter_start=args.chapter_start,
            chapter_end=args.chapter_end,
            sleep_seconds=args.sleep,
            max_retries=args.max_retries,
            sentence_ids=sentence_ids,
        )