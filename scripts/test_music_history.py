import importlib.util
from concurrent.futures import ThreadPoolExecutor
from contextlib import redirect_stdout
from datetime import datetime, timedelta, timezone
from io import StringIO
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location("music_history", Path(__file__).with_name("music-history.py"))
music = importlib.util.module_from_spec(spec)
spec.loader.exec_module(music)
BASE = datetime(2026, 11, 14, tzinfo=timezone.utc)


def event(title="曲A", artist="歌手A", second=0, elapsed=None, playing=True):
    return dict(
        title=title, artist=artist, playing=playing,
        elapsedTime=float(second) if elapsed is None else elapsed,
        timestamp=(BASE + timedelta(seconds=second)).isoformat(),
        bundleIdentifier="com.google.Chrome", playbackRate=1 if playing else 0,
        _browser={"status": "verified", "url": "https://music.youtube.com/watch?v=test"},
    )


class HistoryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db = Path(self.tmp.name) / "history.sqlite3"

    def tearDown(self):
        self.tmp.cleanup()

    def put(self, **kwargs):
        return music.record(event(**kwargs), self.db, now=1000 + kwargs.get("second", 0))

    def listen(self, title="曲A", artist="歌手A", start=0):
        text = ""
        for offset in range(7):
            text = self.put(title=title, artist=artist, second=start+offset, elapsed=offset)
        return text

    def test_skips_at_four_or_exactly_five_seconds_never_count(self):
        for boundary in (4, 5):
            with self.subTest(boundary=boundary):
                self.db = Path(self.tmp.name) / f"{boundary}.sqlite3"
                for second in range(boundary):
                    self.assertEqual(self.put(second=second), "曲A — 歌手A")
                self.put(title="曲B", second=boundary, elapsed=0)
                self.assertEqual(music.ranking(self.db), [])

    def test_count_appears_only_after_more_than_five_seconds(self):
        for second in range(6):
            self.assertEqual(self.put(second=second), "曲A — 歌手A")
            self.assertEqual(music.ranking(self.db), [])
        self.assertEqual(self.put(second=5.1), "曲A — 歌手A · 1回目")
        self.assertEqual(music.ranking(self.db), [("曲A", "歌手A", 1)])

    def test_skip_after_five_seconds_counts_old_track_before_next_timer(self):
        for second in range(5):
            self.put(second=second)
        self.put(title="曲B", second=5.1, elapsed=0)
        self.assertEqual(music.ranking(self.db), [("曲A", "歌手A", 1)])

    def test_new_track_age_prevents_late_skip_notification_from_overcounting(self):
        for second in range(5):
            self.put(second=second)
        # A was skipped at 4.8; the B notification arrives 0.5 seconds later.
        self.put(title="曲B", second=5.3, elapsed=0.5)
        self.assertEqual(music.ranking(self.db), [])

    def test_pause_time_does_not_count_but_listening_resumes(self):
        for second in range(3):
            self.put(second=second)
        self.put(second=3, elapsed=2, playing=False)
        self.put(second=100, elapsed=2)
        for second in range(101, 104):
            self.put(second=second, elapsed=second-98)
        self.assertEqual(music.ranking(self.db), [])
        self.assertEqual(self.put(second=104, elapsed=6), "曲A — 歌手A · 1回目")

    def test_forward_seek_does_not_instantly_qualify(self):
        self.put()
        self.put(second=1)
        self.assertEqual(self.put(second=2, elapsed=100), "曲A — 歌手A")
        self.assertEqual(music.ranking(self.db), [])
        self.put(second=3, elapsed=101)
        self.put(second=4, elapsed=102)
        self.put(second=5, elapsed=103)
        self.assertEqual(music.ranking(self.db), [])
        self.assertEqual(self.put(second=6, elapsed=104), "曲A — 歌手A · 1回目")

    def test_opening_terminal_mid_song_still_waits_five_seconds(self):
        self.assertEqual(self.put(elapsed=90), "曲A — 歌手A")
        for second in range(1, 6):
            self.put(second=second, elapsed=90+second)
        self.assertEqual(music.ranking(self.db), [])
        self.assertEqual(self.put(second=6, elapsed=96), "曲A — 歌手A · 1回目")

    def test_parallel_terminals_do_not_add_time_or_duplicate_counts(self):
        for second in range(3):
            self.put(second=second)
        with ThreadPoolExecutor(max_workers=8) as workers:
            results = list(workers.map(lambda _: self.put(second=3), range(16)))
        self.assertEqual(set(results), {"曲A — 歌手A"})
        self.assertEqual(music.ranking(self.db), [])
        self.put(second=4)
        self.put(second=5)
        with ThreadPoolExecutor(max_workers=8) as workers:
            results = list(workers.map(lambda _: self.put(second=6), range(16)))
        self.assertEqual(set(results), {"曲A — 歌手A · 1回目"})
        self.assertEqual(music.ranking(self.db), [("曲A", "歌手A", 1)])

    def test_repeat_waits_again(self):
        self.assertEqual(self.listen(), "曲A — 歌手A · 1回目")
        self.assertEqual(self.put(second=30, elapsed=0), "曲A — 歌手A")
        for offset in range(1, 6):
            self.put(second=30+offset, elapsed=offset)
        self.assertEqual(music.ranking(self.db)[0][-1], 1)
        self.assertEqual(self.put(second=36, elapsed=6), "曲A — 歌手A · 2回目")

    def test_repeated_short_restarts_do_not_combine(self):
        for second in range(4):
            self.put(second=second)
        self.put(second=4, elapsed=0)
        for second in range(5, 8):
            self.put(second=second, elapsed=second-4)
        self.put(second=8, elapsed=0)
        self.assertEqual(music.ranking(self.db), [])

    def test_long_unobserved_gap_is_not_listening_time(self):
        for second in range(3):
            self.put(second=second)
        self.assertEqual(self.put(second=100, elapsed=100), "曲A — 歌手A")
        self.assertEqual(music.ranking(self.db), [])

    def test_time_is_real_seconds_at_double_speed(self):
        for second in range(6):
            data = dict(event(second=second, elapsed=second*2), playbackRate=2)
            music.record(data, self.db, now=1000+second)
        self.assertEqual(music.ranking(self.db), [])
        data = dict(event(second=6, elapsed=12), playbackRate=2)
        self.assertEqual(music.record(data, self.db, now=1006), "曲A — 歌手A · 1回目")

    def test_elapsed_now_is_used_even_without_clock_anchor_updates(self):
        for second in range(7):
            data = dict(event(), elapsedTimeNow=second)
            music.record(data, self.db, now=1000+second)
        self.assertEqual(music.ranking(self.db), [("曲A", "歌手A", 1)])

    def test_artist_metadata_arrives_late(self):
        self.put(artist="")
        for second in range(1, 7):
            self.put(second=second, artist="歌手A" if second == 1 else "")
        self.assertEqual(music.ranking(self.db), [("曲A", "歌手A", 1)])

    def test_rankings_and_persistence(self):
        self.listen()
        self.listen(title="曲B", start=10)
        self.listen(artist="歌手B", start=20)
        self.assertEqual(music.ranking(self.db, "artists"), [("歌手A", 2), ("歌手B", 1)])
        self.assertEqual(len(music.ranking(self.db, artist="手B")), 1)
        self.assertEqual(music.ranking(self.db, days=1, now=90000), [])
        self.assertEqual(len(music.ranking(self.db, limit=1)), 1)

    def test_stale_events_do_not_restart_current_track(self):
        self.listen()
        self.listen(title="曲B", start=10)
        self.put(second=3)
        self.assertEqual(self.put(title="曲B", second=17, elapsed=7), "曲B — 歌手A · 1回目")
        self.assertEqual(len(music.ranking(self.db)), 2)

    def test_legacy_counted_state_is_preserved(self):
        self.listen()
        con = sqlite3.connect(self.db)
        state = json.loads(con.execute("SELECT data FROM state WHERE id=1").fetchone()[0])
        for key in ("observed_at", "listened", "started_at"):
            state.pop(key)
        con.execute("UPDATE state SET data=?", (json.dumps(state),))
        con.commit()
        con.close()
        self.assertEqual(self.put(second=7, elapsed=7), "曲A — 歌手A · 1回目")
        self.assertEqual(music.ranking(self.db)[0][-1], 1)

    def test_unicode_ads_and_empty(self):
        self.assertEqual(self.listen(title="鬼舞辻󠄀無惨侵入", artist="椎名 豪"),
                         "鬼舞辻無惨侵入 — 椎名 豪 · 1回目")
        self.assertEqual(music.record({}, self.db), "")
        self.assertEqual(music.record(dict(event(), isAdvertisement=True), self.db), "")
        self.assertEqual(music.clean("100%\n🎵☀️"), "100% 🎵☀️")

    def test_regular_youtube_and_unverified_source_are_never_saved(self):
        for proof in (
            {"status": "blocked", "url": "https://www.youtube.com/watch?v=x"},
            {},
            {"status": "verified", "url": "https://music.youtube.com.evil.test/"},
        ):
            for second in range(8):
                data = dict(event(second=second), _browser=proof)
                self.assertEqual(music.record(data, self.db, now=1000+second), "曲A — 歌手A")
        self.assertFalse(self.db.exists())

    def test_excluded_source_time_is_not_credited(self):
        for second in range(4):
            self.put(second=second)
        normal = dict(event(title="動画B", second=4), _browser={"status": "blocked"})
        music.record(normal, self.db, now=1004)
        self.put(second=5)
        self.put(second=6)
        self.put(second=7)
        self.assertEqual(music.ranking(self.db), [])
        self.assertEqual(self.put(second=8), "曲A — 歌手A · 1回目")

    def test_browser_match_uses_url_metadata_and_playing_state(self):
        data = event()
        music_tab = dict(url="https://music.youtube.com/watch?v=a", title="曲A", artist="歌手A", playing=True)
        normal_tab = dict(url="https://www.youtube.com/watch?v=b", title="動画B", artist="投稿者", playing=True)
        snapshot = {"ok": True, "tabs": [music_tab, normal_tab]}
        self.assertEqual(music.classify_browser_source(data, snapshot)["status"], "verified")
        self.assertEqual(music.classify_browser_source(
            dict(data, title="動画B", artist="投稿者"), snapshot)["status"], "blocked")
        snapshot["tabs"][0] = dict(music_tab, playing=False)
        self.assertEqual(music.classify_browser_source(data, snapshot)["status"], "unverified")
        snapshot["tabs"][0] = music_tab
        snapshot["tabs"][1] = dict(normal_tab, title="曲A", artist="歌手A")
        self.assertEqual(music.classify_browser_source(data, snapshot)["status"], "blocked")

    def test_probe_failure_and_native_apps(self):
        with patch.object(music.subprocess, "run", side_effect=subprocess.TimeoutExpired("osascript", 2)):
            self.assertEqual(music.probe_browser_source(event())["status"], "unverified")
        self.assertEqual(music.record(dict(event(), bundleIdentifier="com.apple.Safari"), self.db),
                         "曲A — 歌手A")
        for second in range(7):
            music.record(dict(event(second=second), bundleIdentifier="com.apple.Music"),
                         self.db, now=1000+second)
        self.assertEqual(music.ranking(self.db), [("曲A", "歌手A", 1)])

    def test_watcher_records_quiet_stream_and_stops_sampling_after_count(self):
        # Run a real child process. A short test-only threshold keeps the test fast.
        player = Path(self.tmp.name) / "player"
        player.write_text(
            "#!" + sys.executable + "\n"
            "import datetime,json,sys,time\n"
            "now=time.time()\n"
            "data={'title':'静かな曲','artist':'歌手','playing':True,"
            "'bundleIdentifier':'com.apple.Music','elapsedTimeNow':now-"
            + repr(time.time()) + ",'timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat()}\n"
            "print(json.dumps({'payload':data} if sys.argv[1]=='stream' else data),flush=True)\n"
            "if sys.argv[1]=='stream':time.sleep(0.5)\n"
        )
        player.chmod(0o755)
        output = StringIO()
        real_run = music.subprocess.run
        with patch.object(music, "MIN_LISTEN_SECONDS", 0.05), \
             patch.object(music, "HEARTBEAT_SECONDS", 0.02), \
             patch.object(music.subprocess, "run", wraps=real_run) as sampler, \
             redirect_stdout(output):
            self.assertEqual(music.watch_player(str(player), self.db), 0)
        self.assertEqual(music.ranking(self.db), [("静かな曲", "歌手", 1)])
        texts = [json.loads(line)["_display"] for line in output.getvalue().splitlines()]
        self.assertEqual(texts, ["静かな曲 — 歌手", "静かな曲 — 歌手 · 1回目"])
        self.assertGreaterEqual(sampler.call_count, 1)
        self.assertLess(sampler.call_count, 8)

    def test_watcher_source_proof_and_child_cleanup(self):
        child = Mock()
        child.stdout = StringIO(json.dumps({"payload": event()}) + "\n")
        child.wait.return_value = 0
        child.poll.return_value = None
        output = StringIO()
        proof = {"status": "verified", "url": "https://music.youtube.com/watch?v=a"}
        with patch.object(music.subprocess, "Popen", return_value=child), \
             patch.object(music, "probe_browser_source", return_value=proof), \
             redirect_stdout(output):
            self.assertEqual(music.watch_player("player", self.db), 0)
        message = json.loads(output.getvalue())
        self.assertEqual(message["payload"]["_browser"], proof)
        self.assertEqual(message["_display"], "曲A — 歌手A")
        child.terminate.assert_called_once()
        self.assertTrue(child.stdout.closed)

    def test_cli_rank_and_forwarded_display_does_not_count_again(self):
        self.listen()
        base = [sys.executable, "-B", str(Path(__file__).with_name("music-history.py")),
                "--db", str(self.db)]
        result = subprocess.run(base + ["rank", "artists", "--json"],
                                capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(result.stdout), [{"artist": "歌手A", "plays": 1}])
        result = subprocess.run(base + ["rank", "--days", "0"], capture_output=True)
        self.assertEqual(result.returncode, 2)
        message = {"payload": event(title="別の曲"), "_display": "表示済み"}
        result = subprocess.run(base + ["ingest"], input=json.dumps(message),
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), "表示済み")
        self.assertEqual(music.ranking(self.db), [("曲A", "歌手A", 1)])


if __name__ == "__main__":
    unittest.main()
