#!/usr/bin/env python3
"""Read-only MAVLink heartbeat monitor for local ArduPilot SITL.

Requires: pip install pymavlink
Only binds to 127.0.0.1. Does not send commands or arm vehicles.
"""
import argparse
import json
import operator
import time


VEHICLE_TYPES = {
    1: "fixed_wing",
    2: "multirotor",
    3: "multirotor",
    4: "helicopter",
    10: "unsupported",  # ground rover, not a boat
    11: "boat",
    12: "submersible",
    13: "multirotor",
    14: "multirotor",
    15: "multirotor",
    19: "multirotor",
    20: "multirotor",
    21: "multirotor",
}


def heartbeat_record(message, now=None):
    """Convert a decoded pymavlink HEARTBEAT to telemetry; never authorize control."""
    if message.get_type() != "HEARTBEAT":
        return None
    vehicle_type = operator.index(message.type)
    if not 0 <= vehicle_type <= 255:
        return None
    # MAV_TYPE_GCS=6 and generic/autopilot peripheral types are not vehicles.
    category = VEHICLE_TYPES.get(vehicle_type, "unsupported")
    if category == "unsupported":
        return None
    system_id = operator.index(message.get_srcSystem())
    component_id = operator.index(message.get_srcComponent())
    if not (1 <= system_id <= 255 and 1 <= component_id <= 255):
        return None
    custom_mode = operator.index(message.custom_mode)
    base_mode = operator.index(message.base_mode)
    autopilot = operator.index(message.autopilot)
    if not (0 <= custom_mode <= 0xFFFFFFFF and
            0 <= base_mode <= 255 and 0 <= autopilot <= 255):
        return None
    return {
        "timestamp_monotonic": time.monotonic() if now is None else now,
        "system_id": system_id,
        "component_id": component_id,
        "vehicle_type": vehicle_type,
        "vehicle_class": category,
        "autopilot": autopilot,
        "base_mode": base_mode,
        "custom_mode": custom_mode,
        "armed_reported": bool(base_mode & 128),
        "control_authorized": False,
    }


class HeartbeatSourceLock:
    """Keep telemetry from a single MAVLink source until it expires."""

    def __init__(self, timeout):
        self.timeout = timeout
        self.active_source = None
        self.last_seen = None

    def observe(self, record, now):
        if record is None:
            return False
        source = (record["system_id"], record["component_id"])
        if self.active_source is None:
            self.active_source = source
        if source != self.active_source:
            return False
        self.last_seen = now
        return True

    def expire(self, now):
        if self.last_seen is None:
            return False
        # A monotonic clock rollback invalidates the previous source lease.
        if now >= self.last_seen and now - self.last_seen <= self.timeout:
            return False
        self.last_seen = None
        self.active_source = None
        return True


def run(port, timeout):
    from pymavlink import mavutil
    # udp: listen mode, not udpout: and not any remote interface.
    connection = mavutil.mavlink_connection(
        f"udpin:127.0.0.1:{port}", source_system=255
    )
    source_lock = HeartbeatSourceLock(timeout)
    try:
        while True:
            msg = connection.recv_match(type="HEARTBEAT", blocking=True, timeout=0.5)
            now = time.monotonic()
            if source_lock.expire(now):
                print(json.dumps({"event": "heartbeat_timeout", "control_authorized": False}), flush=True)
            if msg is not None:
                try:
                    record = heartbeat_record(msg, now)
                except (AttributeError, TypeError, ValueError, OverflowError):
                    # A malformed decoded packet must not terminate monitoring.
                    continue
                if source_lock.observe(record, now):
                    print(json.dumps({"event": "heartbeat", **record}), flush=True)
    except KeyboardInterrupt:
        return 0
    finally:
        connection.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=14550)
    parser.add_argument("--timeout", type=float, default=3.0)
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error("port must be between 1024 and 65535")
    if not 0.5 <= args.timeout <= 60:
        parser.error("timeout must be between 0.5 and 60 seconds")
    return run(args.port, args.timeout)


if __name__ == "__main__":
    raise SystemExit(main())
