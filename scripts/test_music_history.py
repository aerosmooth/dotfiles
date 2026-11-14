import importlib.util
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import tempfile
import subprocess
import sys
import unittest

spec = importlib.util.spec_from_file_location("music_history", Path(__file__).with_name("music-history.py"))
music = importlib.util.module_from_spec(spec)
spec.loader.exec_module(music)


def event(title="曲A", artist="歌手A", second=0, elapsed=0, playing=True):
    return dict(title=title, artist=artist, playing=playing, elapsedTime=elapsed,
                timestamp=f"2026-11-14T00:{second // 60:02}:{second % 60:02}Z",
                bundleIdentifier="com.google.Chrome", playbackRate=1 if playing else 0)


class HistoryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db = Path(self.tmp.name) / "history.sqlite3"

    def tearDown(self):
        self.tmp.cleanup()

    def put(self, **kwargs):
        return music.record(event(**kwargs), self.db, now=1000 + kwargs.get("second", 0))

    def test_concurrent_terminals_only_count_once(self):
        with ThreadPoolExecutor(max_workers=8) as workers:
            outputs = list(workers.map(lambda _: self.put(), range(16)))
        self.assertEqual(set(outputs), {"曲A — 歌手A · 1回目"})
        self.assertEqual(music.ranking(self.db)[0][-1], 1)

    def test_pause_resume_and_repeat_without_continuous_updates(self):
        self.put()
        self.put(second=40, elapsed=40, playing=False)
        self.put(second=100, elapsed=40)
        self.assertEqual(self.put(second=110, elapsed=50), "曲A — 歌手A · 1回目")
        self.assertEqual(self.put(second=300, elapsed=0), "曲A — 歌手A · 2回目")
        self.assertEqual(self.put(second=300, elapsed=0), "曲A — 歌手A · 2回目")

    def test_track_changes_persistence_and_stale_events(self):
        self.put()
        self.put(title="曲B", second=10)
        self.put(second=20)
        self.assertEqual(music.ranking(self.db)[0], ("曲A", "歌手A", 2))
        self.put(title="曲B", second=10)
        self.assertEqual(music.ranking(self.db)[1][-1], 1)

    def test_artist_metadata_arrives_late(self):
        self.put(artist="")
        self.put(second=1, artist="歌手A")
        self.put(second=2, artist="")
        self.assertEqual(music.ranking(self.db), [("曲A", "歌手A", 1)])

    def test_paused_new_track_is_counted_only_when_playing(self):
        self.assertEqual(self.put(playing=False), "")
        self.assertEqual(music.ranking(self.db), [])
        self.assertEqual(self.put(second=10), "曲A — 歌手A · 1回目")

    def test_rankings_filters_and_period(self):
        self.put()
        self.put(title="曲B", second=10)
        self.put(artist="歌手B", second=20)
        self.assertEqual(music.ranking(self.db, "artists"), [("歌手A", 2), ("歌手B", 1)])
        self.assertEqual(len(music.ranking(self.db, artist="手B")), 1)
        self.assertEqual(music.ranking(self.db, days=1, now=90000), [])
        self.assertEqual(len(music.ranking(self.db, limit=1)), 1)

    def test_cli_and_empty_read_only_ranking(self):
        self.assertEqual(music.ranking(self.db), [])
        self.assertFalse(self.db.exists())
        self.put()
        command = [sys.executable, "-B", str(Path(__file__).with_name("music-history.py")),
                   "--db", str(self.db), "rank"]
        output = subprocess.run(command + ["artists", "--days", "7", "--all", "--json"],
                                capture_output=True, text=True, check=True)
        # The fixtures are deliberately old, so use the all-time ranking too.
        self.assertEqual(json.loads(output.stdout), [])
        output = subprocess.run(command + ["--artist", "歌手A", "--json"],
                                capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(output.stdout),
                         [{"title": "曲A", "artist": "歌手A", "plays": 1}])
        result = subprocess.run(command + ["--days", "0"], capture_output=True)
        self.assertEqual(result.returncode, 2)

    def test_unicode_ads_empty_and_seek(self):
        self.assertEqual(self.put(title="鬼舞辻󠄀無惨侵入", artist="椎名 豪"),
                         "鬼舞辻無惨侵入 — 椎名 豪 · 1回目")
        self.put(second=10)
        self.put(second=60, elapsed=50)
        self.assertEqual(self.put(second=70, elapsed=20), "曲A — 歌手A · 1回目")
        self.assertEqual(music.record({}, self.db), "")
        self.assertEqual(music.record(dict(event(), isAdvertisement=True), self.db), "")
        self.assertEqual(music.clean("100%\n🎵☀️"), "100% 🎵☀️")


if __name__ == "__main__":
    unittest.main()
