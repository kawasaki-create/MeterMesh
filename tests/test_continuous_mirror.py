import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import dashboard_api
import unibase


def assistant_event(event_id, session_id, timestamp, model, *, input_tokens=0, output_tokens=0):
    return {
        "type": "assistant",
        "uuid": event_id,
        "sessionId": session_id,
        "timestamp": timestamp,
        "message": {
            "role": "assistant",
            "model": model,
            "content": [{"type": "text", "text": "n/a"}],
            "usage": {
                "input_tokens": input_tokens,
                "cache_creation_input_tokens": 0,
                "cache_read_input_tokens": 0,
                "output_tokens": output_tokens,
            },
        },
    }


def write_rows(path, rows, mode="w"):
    with path.open(mode, encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row) + "\n")


class ContinuousMirrorRefreshTests(unittest.TestCase):
    """A Syncthing-fed mirror source (add_stat manifest with "refresh": "continuous")
    must keep getting rescanned on every refresh, unlike an ordinary point-in-time
    backup snapshot, which is scanned once and then left alone."""

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        root = Path(self.temp_dir.name)
        self.mirror_root = root / ".claude" / "add_stat" / "mirror" / "root"
        self.projects_path = self.mirror_root / "projects"
        self.projects_path.mkdir(parents=True)
        self.unibase_path = root / "metermesh" / "unibase.sqlite3"
        self.db = unibase.Unibase(self.unibase_path)
        self.transcript = self.projects_path / "p" / "session.jsonl"
        self.transcript.parent.mkdir(parents=True)

    def register(self, *, continuous):
        self.db.register_source(unibase.DiscoveredSource(
            "mirror", "claude", "normalized_backup", self.mirror_root, "mirror",
            "Mac (Syncthing mirror)", True, 500, "mac-mirror", "2026-07-16T00:00:00Z", "ready",
            continuous=continuous,
        ))

    def refresh(self):
        with patch.object(dashboard_api, "register_default_sources"):
            dashboard_api.refresh_enabled_sources(self.unibase_path)

    def test_continuous_source_is_rescanned_every_refresh(self):
        self.register(continuous=True)
        write_rows(self.transcript, [
            assistant_event("event-1", "session-1", "2026-07-16T12:00:00Z", "claude-sonnet-5", input_tokens=5),
        ])

        self.refresh()
        self.assertEqual(len(self.db.active_event_rows("claude")), 1)

        write_rows(self.transcript, [
            assistant_event("event-2", "session-1", "2026-07-16T12:01:00Z", "claude-sonnet-5", input_tokens=7),
        ], mode="a")
        self.refresh()

        self.assertEqual(len(self.db.active_event_rows("claude")), 2)

    def test_ordinary_backup_is_scanned_once_then_skipped(self):
        self.register(continuous=False)
        write_rows(self.transcript, [
            assistant_event("event-1", "session-1", "2026-07-16T12:00:00Z", "claude-sonnet-5", input_tokens=5),
        ])

        self.refresh()
        self.assertEqual(len(self.db.active_event_rows("claude")), 1)

        write_rows(self.transcript, [
            assistant_event("event-2", "session-1", "2026-07-16T12:01:00Z", "claude-sonnet-5", input_tokens=7),
        ], mode="a")
        self.refresh()

        self.assertEqual(len(self.db.active_event_rows("claude")), 1)


if __name__ == "__main__":
    unittest.main()
