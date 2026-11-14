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


def watch_player(player):
    """Resolve browser source off the prompt thread, then forward JSON events."""
    child = None

    def stop(signum, frame):
        raise SystemExit(0)

    previous = signal.signal(signal.SIGTERM, stop)
    try:
        child = subprocess.Popen(
            [player, "stream", "--no-diff", "--no-artwork", "--debounce=250"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
        )
        for line in child.stdout:
            try:
                message = json.loads(line)
                data = message.get("payload", {})
                if isinstance(data, dict) and isinstance(app_id(data), str):
                    # Never trust browser proof received from the player itself.
                    data.pop("_browser", None)
                    if app_id(data).startswith(CHROME_PREFIX) and data.get("title"):
                        data["_browser"] = probe_browser_source(data)
                print(json.dumps(message, ensure_ascii=False), flush=True)
            except (ValueError, TypeError, AttributeError):
                continue
        return child.wait()
    except BrokenPipeError:
        return 0
    finally:
        if child is not None:
            if child.stdout is not None:
                child.stdout.close()
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
        signal.signal(signal.SIGTERM, previous)


def record(data, db_path=DEFAULT_DB, now=None):
    """Count starts, not metadata updates or pause/resume; serialize all shells."""
    if not isinstance(data, dict):
        return ""
    title, artist = clean(data.get("title")), clean(data.get("artist"))
    playing = data.get("playing") is True
    if not title or data.get("isAdvertisement") is True:
        return ""
    if not browser_eligible(data):
        return display(title, artist) if playing else ""
    now = time.time() if now is None else now
    stamp = event_time(data, now)
    elapsed = number(data.get("elapsedTime"))
    source = data.get("parentApplicationBundleIdentifier") or data.get("bundleIdentifier") or ""
    rate = number(data.get("playbackRate"))
    rate = rate if rate is not None else (1.0 if playing else 0.0)
    db_path = Path(db_path)
    db_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    con = sqlite3.connect(db_path, timeout=0.5, isolation_level=None)
    try:
        # The state check and increment must be one transaction across terminals.
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
        stale = bool(previous) and stamp < previous["stamp"] - 0.05
        same_title = title == previous.get("title") and source == previous.get("source")
        # Some players supply the artist after the first track notification.
        if same_title and not artist:
            artist = previous.get("artist", "")
        same_song = same_title and (
            artist == previous.get("artist") or not previous.get("artist")
        )
        play_id = previous.get("play_id") if same_song else None
        if not stale:
            if same_song and artist and not previous.get("artist") and play_id:
                con.execute("UPDATE plays SET artist=? WHERE id=?", (artist, play_id))
            restarted = False
            if same_song and playing and play_id and elapsed is not None:
                old_elapsed = previous.get("elapsed")
                if old_elapsed is not None and stamp > previous["stamp"] + 0.5:
                    expected = old_elapsed
                    if previous.get("playing"):
                        expected += max(0, stamp - previous["stamp"]) * previous.get("rate", 1)
                    # Returning to the beginning counts as another play.
                    # Ordinary seeks and resuming a paused song do not.
                    restarted = elapsed <= 5 and expected - elapsed >= 10
            if playing and (play_id is None or restarted):
                cursor = con.execute(
                    "INSERT INTO plays(title, artist, played_at) VALUES(?, ?, ?)",
                    (title, artist, now),
                )
                play_id = cursor.lastrowid
            state = dict(
                title=title, artist=artist, source=source, playing=playing,
                elapsed=elapsed if elapsed is not None else (
                    previous.get("elapsed") if same_song else None
                ),
                stamp=stamp, rate=rate, play_id=play_id,
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
        return display(title, artist, count) if playing else ""
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
        return watch_player(args.player)
    if args.command == "ingest":
        try:
            message = json.load(sys.stdin)
            data = message.get("payload", {}) if isinstance(message, dict) else {}
        except (ValueError, TypeError):
            print("")
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
