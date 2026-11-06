"""Runtime tests for the read-only SITL monitor without pymavlink or hardware."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "sitl_heartbeat_monitor_runtime", ROOT / "tools" / "sitl_heartbeat_monitor.py"
)
MONITOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MONITOR)


class FakeHeartbeat:
    type = 2
    autopilot = 3
    base_mode = 128
    custom_mode = 4

    def __init__(self, system_id):
        self.system_id = system_id

    def get_type(self):
        return "HEARTBEAT"

    def get_srcSystem(self):
        return self.system_id

    def get_srcComponent(self):
        return 1


class FakeConnection:
    def __init__(self):
        self.messages = [
            FakeHeartbeat(1), FakeHeartbeat(2), FakeHeartbeat(2),
            FakeHeartbeat(2),
        ]
        self.closed = False

    def recv_match(self, **kwargs):
        if self.messages:
            return self.messages.pop(0)
        raise KeyboardInterrupt

    def close(self):
        self.closed = True


class SitlMonitorRuntimeTests(unittest.TestCase):
    def test_custom_mode_uint32_boundaries(self):
        message = FakeHeartbeat(1)
        message.custom_mode = 0xFFFFFFFF
        record = MONITOR.heartbeat_record(message, now=1.0)
        self.assertEqual(record["custom_mode"], 0xFFFFFFFF)
        message.custom_mode = 0x100000000
        self.assertIsNone(MONITOR.heartbeat_record(message, now=2.0))
        message.custom_mode = -1
        self.assertIsNone(MONITOR.heartbeat_record(message, now=3.0))

    def test_timeout_handoff_and_read_only_output(self):
        connection = FakeConnection()
        mavutil = types.SimpleNamespace(
            mavlink_connection=lambda *args, **kwargs: connection
        )
        fake_package = types.ModuleType("pymavlink")
        fake_package.mavutil = mavutil
        clock = iter((10.0, 11.0, 13.1, 13.2))
        output = io.StringIO()
        with patch.dict(sys.modules, {"pymavlink": fake_package}), \
             patch.object(MONITOR.time, "monotonic", side_effect=lambda: next(clock)), \
             contextlib.redirect_stdout(output):
            result = MONITOR.run(14550, 3.0)

        self.assertEqual(result, 0)
        self.assertTrue(connection.closed)
        events = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual([e["event"] for e in events],
                         ["heartbeat", "heartbeat_timeout", "heartbeat", "heartbeat"])
        self.assertEqual([e["system_id"] for e in events if e["event"] == "heartbeat"],
                         [1, 2, 2])
        self.assertTrue(all(e["control_authorized"] is False for e in events))
        self.assertTrue(all(e["armed_reported"] for e in events if e["event"] == "heartbeat"))


if __name__ == "__main__":
    unittest.main()
