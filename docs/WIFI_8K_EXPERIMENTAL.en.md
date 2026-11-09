# WIFI_8K experimental control — 0.46

The cockpit and simulator implement two manually selected candidates: Legacy9 (9 bytes, UDP7099, 0101 heartbeat, XOR axes+flags) and E58_8 (8 bytes, UDP8090, 4276 initialization on auxiliary UDP8080, XOR axes only). Default command rate is 25 Hz. The SSID WIFI_8K_a83a9a does not establish compatibility with either format. The software never switches variants automatically.

Select Experimental/WIFI_8K, the candidate variant, and Simulation Mode to train against the included simulator. Center the vertical stick and press A for takeoff, B for landing, Space for motor cut. Mode2 uses the left stick for vertical/yaw and the right stick for pitch/roll. Cut requires a fresh neutral-stick takeoff request before rearming.

For hardware, turn Simulation Mode off, choose the physical Wi-Fi interface, scan, select the exact network, connect, and read the observed local IP/gateway. An explicit experimental real-control checkbox is disabled by default. Only a unique matching open network can be associated automatically; secured or ambiguous networks require selection first. No hardcoded gateway is assumed. Link loss suspends output. Optional identified HTTP(S)/RTSP/UDP video URLs use bundled FFmpeg; proprietary fragmented WIFI_8K video is not reconstructed.

Codec, settings, Wi-Fi state and full cockpit-to-simulator flight/cut tests passed for both formats. A local HTTP MJPEG video test passed. This computer could not see or associate with the user's SSID during native scans/direct association. No physical flight commands were sent, and hardware/protocol identity remains unconfirmed.

See the [complete Portuguese guide](WIFI_8K_EXPERIMENTAL.md) for configuration, limitations and primary format sources.
