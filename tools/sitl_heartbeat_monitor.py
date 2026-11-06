#!/usr/bin/env python3
"""Read-only MAVLink heartbeat monitor for local ArduPilot SITL.

Requires: pip install pymavlink
Only binds to 127.0.0.1. Does not send commands or arm vehicles.
"""
import argparse
import json
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
    vehicle_type = int(message.type)
    # MAV_TYPE_GCS=6 and generic/autopilot peripheral types are not vehicles.
    category = VEHICLE_TYPES.get(vehicle_type, "unsupported")
    return {
        "timestamp_monotonic": time.monotonic() if now is None else now,
        "system_id": message.get_srcSystem(),
        "component_id": message.get_srcComponent(),
        "vehicle_type": vehicle_type,
        "vehicle_class": category,
        "autopilot": int(message.autopilot),
        "base_mode": int(message.base_mode),
        "custom_mode": int(message.custom_mode),
        "armed_reported": bool(int(message.base_mode) & 128),
        "control_authorized": False,
    }


def run(port, timeout):
    from pymavlink import mavutil
    # udp: listen mode, not udpout: and not any remote interface.
    connection = mavutil.mavlink_connection(
        f"udpin:127.0.0.1:{port}", source_system=255
    )
    last_seen = None
    try:
        while True:
            msg = connection.recv_match(type="HEARTBEAT", blocking=True, timeout=0.5)
            now = time.monotonic()
            if msg is not None:
                record = heartbeat_record(msg, now)
                if record is not None:
                    last_seen = now
                    print(json.dumps({"event": "heartbeat", **record}), flush=True)
            if last_seen is not None and now - last_seen > timeout:
                print(json.dumps({"event": "heartbeat_timeout", "control_authorized": False}), flush=True)
                last_seen = None
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
