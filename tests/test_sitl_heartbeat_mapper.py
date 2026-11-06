"""Unit tests for the read-only SITL heartbeat mapper (no pymavlink required)."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "sitl_heartbeat_monitor", ROOT / "tools" / "sitl_heartbeat_monitor.py"
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class FakeHeartbeat:
    def __init__(self, vehicle_type, base_mode=0):
        self.type = vehicle_type
        self.base_mode = base_mode
        self.autopilot = 3
        self.custom_mode = 4

    def get_type(self):
        return "HEARTBEAT"

    def get_srcSystem(self):
        return 1

    def get_srcComponent(self):
        return 1


class SitlHeartbeatMapperTests(unittest.TestCase):
    def test_unsupported_and_gcs_heartbeats_are_ignored(self):
        for vehicle_type in (0, 6, 10, 99):
            with self.subTest(vehicle_type=vehicle_type):
                self.assertIsNone(MODULE.heartbeat_record(FakeHeartbeat(vehicle_type)))

    def test_supported_vehicle_classes(self):
        for vehicle_type, expected in ((2, "multirotor"), (4, "helicopter"),
                                       (11, "boat"), (12, "submersible")):
            with self.subTest(vehicle_type=vehicle_type):
                record = MODULE.heartbeat_record(FakeHeartbeat(vehicle_type), now=123.0)
                self.assertEqual(record["vehicle_class"], expected)
                self.assertFalse(record["control_authorized"])
                self.assertEqual(record["timestamp_monotonic"], 123.0)

    def test_reported_armed_is_not_control_permission(self):
        record = MODULE.heartbeat_record(FakeHeartbeat(2, base_mode=128))
        self.assertTrue(record["armed_reported"])
        self.assertFalse(record["control_authorized"])


if __name__ == "__main__":
    unittest.main()
