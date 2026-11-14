#!/usr/bin/env python3
"""Record observed playback starts and show local music rankings."""
import argparse
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import re
import sqlite3
import signal
import queue
import threading
import subprocess
from urllib.parse import urlsplit
import sys
import time
import unicodedata

DEFAULT_DB = Path.home() / ".local/share/zsh-music-prompt/history.sqlite3"
UNSAFE = re.compile(r"[\x00-\x1f\x7f-\x9f]")
IVS = re.compile(r"[\U000e0100-\U000e01ef]")


def clean(value):
    if not isinstance(value, str):
        return ""
    return unicodedata.normalize("NFC", IVS.sub("", UNSAFE.sub(" ", value))).strip()


def number(value):
    if isinstance(value, bool):
        return None
    try:
        result = float(value)
        return result if math.isfinite(result) and result >= 0 else None
    except (TypeError, ValueError):
        return None


def event_time(data, now):
    value = data.get("timestamp")
    if isinstance(value, str):
        try:
            moment = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return moment.replace(tzinfo=moment.tzinfo or timezone.utc).timestamp()
        except ValueError:
            pass
    return now


def display(title, artist, count=None):
    text = " — ".join(part for part in (title, artist) if part)
    return text + (f" · {count}回目" if count is not None else "")



# Browser IDs are not enough to distinguish YouTube from YouTube Music.
CHROME_PREFIX = "com.google.Chrome"
OTHER_BROWSER_PREFIXES = (
    "com.apple.Safari", "org.mozilla.firefox", "com.microsoft.edgemac",
    "com.brave.Browser", "com.vivaldi.Vivaldi", "com.operasoftware.Opera",
    "company.thebrowser.Browser", "com.cmuxterm", "com.mitchellh.ghostty",
)
SOURCE_PROBE = Path(__file__).with_name("music-source.js")


def app_id(data):
    return data.get("parentApplicationBundleIdentifier") or data.get("bundleIdentifier") or ""


def youtube_music_url(value):
    try:
        parsed = urlsplit(value) if isinstance(value, str) else None
        return bool(parsed and parsed.scheme == "https" and parsed.hostname == "music.youtube.com")
    except ValueError:
        return False


def browser_eligible(data):
    source = app_id(data)
    if not isinstance(source, str):
        return False
    if source.startswith(CHROME_PREFIX):
        proof = data.get("_browser", {})
        return (
            isinstance(proof, dict) and proof.get("status") == "verified"
            and youtube_music_url(proof.get("url"))
        )
    # Other browsers cannot be verified by the Chrome probe.
    return not source.startswith(OTHER_BROWSER_PREFIXES)


def classify_browser_source(data, snapshot):
    """Require a matching title, artist, playback state, and exact Music host."""
    if not isinstance(snapshot, dict) or snapshot.get("ok") is not True:
        return {"status": "unverified"}
    title, artist = clean(data.get("title")), clean(data.get("artist"))
    playing = data.get("playing") is True
    matches = []
    for tab in snapshot.get("tabs", []):
        if not isinstance(tab, dict) or tab.get("playing") is not playing:
            continue
        if not title or clean(tab.get("title")) != title:
            continue
        tab_artist = clean(tab.get("artist"))
        if artist and tab_artist and artist != tab_artist:
            continue
        matches.append(tab)
    music = [tab for tab in matches if youtube_music_url(tab.get("url"))]
    if music and len(music) == len(matches):
        return {"status": "verified", "url": music[0]["url"]}
    return {"status": "blocked" if matches else "unverified"}


def probe_browser_source(data):
    try:
        result = subprocess.run(
            ["/usr/bin/osascript", "-l", "JavaScript", str(SOURCE_PROBE)],
            capture_output=True, text=True, timeout=2, check=True,
        )
        return classify_browser_source(data, json.loads(result.stdout))
    except (OSError, subprocess.SubprocessError, ValueError, TypeError):
        return {"status": "unverified"}



MIN_LISTEN_SECONDS = 5.0
HEARTBEAT_SECONDS = 1.0
MAX_SAMPLE_GAP = 3.0


def observation_time(data, now=None):
    if now is not None:
        return now
    value = number(data.get("_observed_at"))
    return value if value is not None else time.time()


def playback_position(data, observed_at):
    value = number(data.get("elapsedTimeNow"))
    if value is not None:
        return value
    value = number(data.get("elapsedTime"))
    if value is None:
        return None
    if data.get("playing") is True:
        rate = number(data.get("playbackRate"))
        rate = 1.0 if rate is None else rate
        value += max(0, observed_at - event_time(data, observed_at)) * rate
    return value


def suspend_pending(db_path, observed_at):
    """Do not credit time spent in an excluded or unverified source."""
    path = Path(db_path)
    if not path.exists():
        return
    con = sqlite3.connect(path, timeout=0.5, isolation_level=None)
    try:
        con.execute("BEGIN IMMEDIATE")
        row = con.execute("SELECT data FROM state WHERE id=1").fetchone()
        if row:
            state = json.loads(row[0])
            last_seen = state.get("observed_at", observed_at)
            if observed_at >= last_seen and state.get("playing"):
                state.update(playing=False, observed_at=observed_at)
                con.execute("UPDATE state SET data=? WHERE id=1",
                            (json.dumps(state, ensure_ascii=False),))
        con.execute("COMMIT")
    finally:
        con.close()


def emit_update(message, text):
    message["_display"] = text
    print(json.dumps(message, ensure_ascii=False), flush=True)


def watch_player(player, db_path=DEFAULT_DB):
    """Record in the background; sample pending plays even without stream events."""
    child = reader = None
    events = queue.Queue()

    def stop(signum, frame):
        raise SystemExit(0)

    def read_events():
        try:
            for line in child.stdout:
                events.put(line)
        except (OSError, ValueError):
            pass
        finally:
            events.put(None)

    previous = signal.signal(signal.SIGTERM, stop)
    next_check = None
    last_text = None
    try:
        child = subprocess.Popen(
            [player, "stream", "--no-diff", "--no-artwork", "--debounce=250"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
        )
        reader = threading.Thread(target=read_events, daemon=True)
        reader.start()
        while True:
            timeout = None if next_check is None else max(0, next_check - time.monotonic())
            try:
                line = events.get(timeout=timeout)
                if line is None:
                    break
                message = json.loads(line)
            except queue.Empty:
                # Refresh actual playback before counting; never reuse an old
                # "playing" notification as proof that five seconds were heard.
                try:
                    result = subprocess.run(
                        [player, "get", "--now", "--no-artwork"],
                        capture_output=True, text=True, timeout=3, check=True,
                    )
                    message = {"payload": json.loads(result.stdout)}
                except (OSError, subprocess.SubprocessError, ValueError):
                    try:
                        suspend_pending(db_path, time.time())
                    except (sqlite3.Error, OSError):
                        pass
                    next_check = time.monotonic() + HEARTBEAT_SECONDS
                    continue
            except (ValueError, TypeError):
                continue
            if not isinstance(message, dict):
                continue
            data = message.get("payload")
            if not isinstance(data, dict):
                data = {}
                message["payload"] = data
            data["_observed_at"] = time.time()
            data.pop("_browser", None)
            data.pop("_pending", None)
            message.pop("_display", None)
            source = app_id(data)
            if isinstance(source, str) and source.startswith(CHROME_PREFIX) and data.get("title"):
                data["_browser"] = probe_browser_source(data)
            try:
                if not data.get("title") and next_check is not None:
                    suspend_pending(db_path, data["_observed_at"])
                text = record(data, db_path)
            except (sqlite3.Error, OSError):
                text = display(clean(data.get("title")), clean(data.get("artist"))) \
                    if data.get("playing") is True else ""
                data["_pending"] = bool(data.get("playing") and browser_eligible(data))
            # DB writes continue while a command is running in the terminal.
            # Only send changed text to zsh, rather than one event per second.
            if text != last_text:
                emit_update(message, text)
                last_text = text
            if data.get("_pending"):
                deadline = time.monotonic() + HEARTBEAT_SECONDS
                next_check = min(next_check, deadline) if next_check is not None else deadline
                if next_check <= time.monotonic():
                    next_check = deadline
            else:
                next_check = None
        return child.wait()
    except BrokenPipeError:
        return 0
    finally:
        if child is not None:
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
            if reader is not None:
                reader.join(timeout=1)
            if child.stdout is not None:
                child.stdout.close()
        signal.signal(signal.SIGTERM, previous)


def record(data, db_path=DEFAULT_DB, now=None):
    """Commit one play only after more than five confirmed listening seconds."""
    if not isinstance(data, dict):
        return ""
    data["_pending"] = False
    title, artist = clean(data.get("title")), clean(data.get("artist"))
    playing = data.get("playing") is True
    if not title:
        return ""
    now = observation_time(data, now)
    if data.get("isAdvertisement") is True or not browser_eligible(data):
        suspend_pending(db_path, now)
        return display(title, artist) if playing and not data.get("isAdvertisement") else ""
    stamp = event_time(data, now)
    position = playback_position(data, now)
    source = app_id(data)
    rate = number(data.get("playbackRate"))
    rate = rate if rate is not None else (1.0 if playing else 0.0)
    db_path = Path(db_path)
    db_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    con = sqlite3.connect(db_path, timeout=0.5, isolation_level=None)
    try:
        con.execute("BEGIN IMMEDIATE")
        con.execute("""CREATE TABLE IF NOT EXISTS plays (
            id INTEGER PRIMARY KEY, title TEXT NOT NULL, artist TEXT NOT NULL,
            played_at REAL NOT NULL)""")
        con.execute("CREATE INDEX IF NOT EXISTS plays_song ON plays(title, artist)")
        con.execute("CREATE INDEX IF NOT EXISTS plays_time ON plays(played_at)")
        con.execute("""CREATE TABLE IF NOT EXISTS state (
            id INTEGER PRIMARY KEY CHECK(id=1), data TEXT NOT NULL)""")
        row = con.execute("SELECT data FROM state WHERE id=1").fetchone()
        previous = json.loads(row[0]) if row else {}
        last_seen = previous.get("observed_at", now)
        stale = bool(previous) and (
            now < last_seen or stamp < previous.get("stamp", stamp) - 0.05
        )
        same_title = title == previous.get("title") and source == previous.get("source")
        if same_title and not artist:
            artist = previous.get("artist", "")
        same_song = same_title and (
            artist == previous.get("artist") or not previous.get("artist")
        )
        play_id = previous.get("play_id") if same_song else None
        listened = previous.get("listened", 0.0) if same_song else 0.0
        started_at = previous.get("started_at", now) if same_song else now
        if not stale:
            gap = max(0, now - last_seen)
            old_position = previous.get("elapsed")
            old_rate = previous.get("rate", 1.0)
            expected = old_position
            if expected is not None and previous.get("playing"):
                expected += gap * old_rate
            restarted = bool(
                same_song and playing and position is not None
                and expected is not None and position <= 5
                and expected - position >= 2
            )
            if (not same_song or restarted) and previous:
                # A skip can arrive just after the five-second boundary, before
                # the next periodic sample. The new track's age bounds the end
                # of the old one. Long gaps and unknown positions get no credit.
                old_listened = previous.get("listened", 0.0)
                if (previous.get("play_id") is None and previous.get("playing")
                        and source == previous.get("source") and playing
                        and position is not None and position <= 5 and rate > 0
                        and old_position is not None and gap <= MAX_SAMPLE_GAP):
                    ended_at = now - position / rate
                    old_listened += max(0, min(now, ended_at) - last_seen)
                    if old_listened > MIN_LISTEN_SECONDS:
                        con.execute(
                            "INSERT INTO plays(title, artist, played_at) VALUES(?, ?, ?)",
                            (previous["title"], previous["artist"],
                             previous.get("started_at", last_seen)),
                        )
                play_id, listened, started_at = None, 0.0, now
            elif same_song and previous.get("playing") and gap <= MAX_SAMPLE_GAP:
                if old_position is not None and position is not None and old_rate > 0:
                    # A seek may jump the position forward, but cannot add more
                    # listening time than the actual interval between samples.
                    advanced = max(0, position - old_position) / old_rate
                    listened += min(gap, advanced)
            if same_song and artist and not previous.get("artist") and play_id:
                con.execute("UPDATE plays SET artist=? WHERE id=?", (artist, play_id))
            if listened > MIN_LISTEN_SECONDS and play_id is None:
                cursor = con.execute(
                    "INSERT INTO plays(title, artist, played_at) VALUES(?, ?, ?)",
                    (title, artist, started_at),
                )
                play_id = cursor.lastrowid
            state = dict(
                title=title, artist=artist, source=source, playing=playing,
                elapsed=position, stamp=stamp, rate=rate, play_id=play_id,
                observed_at=now, listened=listened, started_at=started_at,
            )
            con.execute(
                "INSERT INTO state(id, data) VALUES(1, ?) "
                "ON CONFLICT(id) DO UPDATE SET data=excluded.data",
                (json.dumps(state, ensure_ascii=False),),
            )
        count = con.execute(
            "SELECT COUNT(*) FROM plays WHERE title=? AND artist=?", (title, artist)
        ).fetchone()[0]
        con.execute("COMMIT")
        data["_pending"] = playing and play_id is None
        return display(title, artist, count if play_id is not None else None) if playing else ""
    finally:
        con.close()


def ranking(db_path, kind="songs", artist=None, days=None, limit=20, now=None):
    path = Path(db_path)
    if not path.exists():
        return []
    con = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True, timeout=0.5)
    try:
        con.create_function("casefold", 1, str.casefold)
        clauses, args = [], []
        if artist:
            clauses.append("instr(casefold(artist), ?) > 0")
            args.append(clean(artist).casefold())
        if days is not None:
            clauses.append("played_at >= ?")
            args.append((time.time() if now is None else now) - days * 86400)
        where = " WHERE " + " AND ".join(clauses) if clauses else ""
        if kind == "artists":
            sql = "SELECT artist, COUNT(*) AS plays FROM plays" + where
            sql += " GROUP BY artist ORDER BY plays DESC, artist"
        else:
            sql = "SELECT title, artist, COUNT(*) AS plays FROM plays" + where
            sql += " GROUP BY title, artist ORDER BY plays DESC, artist, title"
        if limit is not None:
            sql += " LIMIT ?"
            args.append(limit)
        return con.execute(sql, args).fetchall()
    finally:
        con.close()


def positive(value):
    parsed = int(value)
    if parsed < 1:
        raise argparse.ArgumentTypeError("1以上を指定してください")
    return parsed


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description="音楽の再生回数を保存・表示します。")
    parser.add_argument("--db", type=Path, default=DEFAULT_DB, help="保存先")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("ingest", help="再生情報を標準入力から記録")
    watch = commands.add_parser("watch", help="再生情報とブラウザの再生元を監視")
    watch.add_argument("--player", required=True, help="media-control のパス")
    rank = commands.add_parser("rank", help="再生回数ランキング")
    rank.add_argument("kind", nargs="?", choices=("songs", "artists"), default="songs",
                      help="songs: 曲別 / artists: 歌手別")
    rank.add_argument("--artist", help="歌手名の一部で絞り込み")
    rank.add_argument("--days", type=positive, help="最近N日分")
    rank.add_argument("--limit", type=positive, default=20, help="表示件数（初期値20）")
    rank.add_argument("--all", action="store_true", help="全件表示")
    rank.add_argument("--json", action="store_true", help="JSONで出力")
    args = parser.parse_args()
    if args.command == "watch":
        return watch_player(args.player, args.db)
    if args.command == "ingest":
        try:
            message = json.load(sys.stdin)
            data = message.get("payload", {}) if isinstance(message, dict) else {}
        except (ValueError, TypeError):
            print("")
            return 0
        if isinstance(message, dict) and isinstance(message.get("_display"), str):
            print(message["_display"])
            return 0
        try:
            print(record(data, args.db))
        except (sqlite3.Error, OSError):
            # Keep the song visible even if the history cannot be saved.
            if isinstance(data, dict) and data.get("playing") is True:
                print(display(clean(data.get("title")), clean(data.get("artist"))))
            else:
                print("")
        return 0
    try:
        rows = ranking(args.db, args.kind, args.artist, args.days,
                       None if args.all else args.limit)
    except (sqlite3.Error, OSError) as error:
        print(f"再生履歴を読めませんでした: {error}", file=sys.stderr)
        return 1
    if args.json:
        fields = ("artist", "plays") if args.kind == "artists" else ("title", "artist", "plays")
        print(json.dumps([dict(zip(fields, row)) for row in rows], ensure_ascii=False, indent=2))
    elif not rows:
        print("再生履歴がありません。ON のターミナルで音楽を再生すると記録されます。")
    else:
        period = f"最近{args.days}日" if args.days else "全期間"
        print(f"{'歌手別' if args.kind == 'artists' else '曲別'} 再生回数ランキング（{period}）")
        for index, row in enumerate(rows, 1):
            label = (row[0] or "歌手不明") if args.kind == "artists" else display(row[0], row[1])
            print(f"{index:>3}. {row[-1]:>5}回  {label}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
