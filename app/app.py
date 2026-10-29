import json
import os
import signal
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("PORT", "5000"))
VERSION = os.environ.get("APP_VERSION", "1.0.0")
SERVICE = "rollout-api"

if VERSION.startswith("2.") and not os.environ.get("NOTES_STORE_URL"):
    print(f"FATAL: {SERVICE} {VERSION} requires setting NOTES_STORE_URL, which is not set", flush=True)
    sys.exit(1)


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/health":
            self._send(200, {"service": SERVICE, "status": "ok", "version": VERSION, "pod": os.environ.get("HOSTNAME", "")})
        elif self.path == "/":
            self._send(200, {"service": SERVICE, "message": "notes service running"})
        else:
            self._send(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    print(f"{SERVICE} {VERSION} listening on 0.0.0.0:{PORT}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
