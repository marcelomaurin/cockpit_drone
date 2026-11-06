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
    def __init__(self, vehicle_type, base_mode=0, system_id=1, component_id=1):
        self.type = vehicle_type
        self.base_mode = base_mode
        self.autopilot = 3
        self.custom_mode = 4
        self.system_id = system_id
        self.component_id = component_id

    def get_type(self):
        return "HEARTBEAT"

    def get_srcSystem(self):
        return self.system_id

    def get_srcComponent(self):
        return self.component_id


class SitlHeartbeatMapperTests(unittest.TestCase):
    def test_unsupported_and_gcs_heartbeats_are_ignored(self):
        for vehicle_type in (0, 6, 10, 99):
            with self.subTest(vehicle_type=vehicle_type):
                self.assertIsNone(MODULE.heartbeat_record(FakeHeartbeat(vehicle_type)))

    def test_invalid_mavlink_source_ids_are_ignored(self):
        for system_id, component_id in ((0, 1), (1, 0), (256, 1), (1, 256)):
            with self.subTest(system_id=system_id, component_id=component_id):
                msg = FakeHeartbeat(2, system_id=system_id, component_id=component_id)
                self.assertIsNone(MODULE.heartbeat_record(msg))

    def test_expiration_before_new_source_acceptance(self):
        lock = MODULE.HeartbeatSourceLock(timeout=3.0)
        first = {"system_id": 1, "component_id": 1}
        other = {"system_id": 2, "component_id": 1}
        self.assertTrue(lock.observe(first, now=10.0))
        self.assertTrue(lock.expire(now=13.1))
        self.assertTrue(lock.observe(other, now=13.1))
        self.assertEqual(lock.active_source, (2, 1))

    def test_supported_vehicle_classes(self):
        for vehicle_type, expected in ((2, "multirotor"), (4, "helicopter"),
                                       (11, "boat"), (12, "submersible")):
            with self.subTest(vehicle_type=vehicle_type):
                record = MODULE.heartbeat_record(FakeHeartbeat(vehicle_type), now=123.0)
                self.assertEqual(record["vehicle_class"], expected)
                self.assertFalse(record["control_authorized"])
                self.assertEqual(record["timestamp_monotonic"], 123.0)

    def test_two_sources_do_not_mix_before_timeout(self):
        lock = MODULE.HeartbeatSourceLock(timeout=3.0)
        first = {"system_id": 1, "component_id": 1}
        other = {"system_id": 2, "component_id": 1}
        self.assertTrue(lock.observe(first, now=10.0))
        self.assertFalse(lock.observe(other, now=11.0))
        self.assertEqual(lock.active_source, (1, 1))
        self.assertEqual(lock.last_seen, 10.0)
        self.assertFalse(lock.expire(now=13.0))
        self.assertTrue(lock.expire(now=13.1))
        self.assertIsNone(lock.active_source)
        self.assertTrue(lock.observe(other, now=13.2))
        self.assertEqual(lock.active_source, (2, 1))

    def test_selected_source_refreshes_timeout(self):
        lock = MODULE.HeartbeatSourceLock(timeout=3.0)
        first = {"system_id": 1, "component_id": 1}
        self.assertTrue(lock.observe(first, now=10.0))
        self.assertTrue(lock.observe(first, now=12.0))
        self.assertFalse(lock.expire(now=14.9))
        self.assertTrue(lock.expire(now=15.1))

    def test_reported_armed_is_not_control_permission(self):
        record = MODULE.heartbeat_record(FakeHeartbeat(2, base_mode=128))
        self.assertTrue(record["armed_reported"])
        self.assertFalse(record["control_authorized"])


if __name__ == "__main__":
    unittest.main()
