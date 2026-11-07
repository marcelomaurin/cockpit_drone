"""Unit checks for read-only SITL heartbeat classification (no pymavlink needed)."""
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from sitl_heartbeat_monitor import heartbeat_record


class FakeHeartbeat:
    type = 11
    autopilot = 3
    base_mode = 128
    custom_mode = 4

    def get_type(self):
        return "HEARTBEAT"

    def get_srcSystem(self):
        return 1

    def get_srcComponent(self):
        return 1


class HeartbeatTests(unittest.TestCase):
    def test_boat_and_armed_are_telemetry_only(self):
        record = heartbeat_record(FakeHeartbeat(), now=123.0)
        self.assertEqual(record["vehicle_class"], "boat")
        self.assertTrue(record["armed_reported"])
        self.assertFalse(record["control_authorized"])
        self.assertEqual(record["timestamp_monotonic"], 123.0)

    def test_ground_rover_is_not_boat(self):
        msg = FakeHeartbeat()
        msg.type = 10
        self.assertIsNone(heartbeat_record(msg, 0))

    def test_gcs_is_not_multirotor(self):
        msg = FakeHeartbeat()
        msg.type = 6
        self.assertEqual(heartbeat_record(msg, 0)["vehicle_class"], "unsupported")


if __name__ == "__main__":
    unittest.main()
