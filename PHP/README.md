# Cockpit Drone — PHP multiplayer relay (MVP)

Requires PHP 8.1+ and HTTPS. Copy the `PHP/` directory to the hosting account and route requests to `index.php` (Apache rewrite rules in `.htaccess`). The server relays telemetry and simulation events; it does not simulate physics or collisions.

Configure `config.php` with exactly one storage backend: `files`, `mysql` or `apcu`. For MySQL, import `schema.sql` first and configure `DRONE_MYSQL_DSN`, `DRONE_MYSQL_USER`, `DRONE_MYSQL_PASSWORD`. For files, set `DRONE_DATA_DIR` to a **writable directory outside the public web root**. APCu must be enabled for web PHP workers and may not be consistent across separate processes/servers; MySQL is recommended on shared hosting.

Endpoints (all JSON, except GET):
- `POST /connect` -> `{"token":"...","expires_in":120}`
- `POST /telemetry` with Bearer token and `{"lat":-21.17,"lon":-47.81,"alt":10}`
- `GET /nearby` with Bearer token -> nearby participants within 2000 m
- `POST /events` with Bearer token and event object -> event ID
- `GET /events?after=0` with Bearer token -> nearby events
- `POST /disconnect` with Bearer token
- `GET /health` -> backend status

Tokens are random and their SHA-256 hashes are stored. Session expiry is renewed on telemetry updates. Inactivity timeout defaults to 120 seconds. Events are kept for 120 seconds in files/APCu and queried within that window in MySQL.

Security and operational limitations: this is an initial implementation, **not production hardened or Hostinger-tested**. Add rate limiting, authentication/authorization appropriate to your threat model, data retention cleanup, file backend load testing and pagination. File event IDs are time-derived and may collide under concurrent requests; APCu indexes may be process-local; file scanning is O(number of sessions). Events are filtered by the **current** location of their sender, not the event's original location. Use MySQL for multiple workers and higher concurrency. Never expose `config.php`, `schema.sql` or the data directory publicly.
