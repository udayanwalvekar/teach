#!/usr/bin/env python3
"""Serve a Teach prompt fixture while deliberately stalling file downloads."""

from __future__ import annotations

import argparse
import functools
import http.server
import time
from pathlib import Path


class SlowHandler(http.server.SimpleHTTPRequestHandler):
    delay = 1.0

    def do_GET(self) -> None:
        if not self.path.endswith("/runtime/manifest.json"):
            time.sleep(self.delay)
        super().do_GET()

    def log_message(self, format: str, *args: object) -> None:
        pass


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--port-file", required=True)
    parser.add_argument("--delay", type=float, default=1.0)
    args = parser.parse_args()

    SlowHandler.delay = args.delay
    handler = functools.partial(SlowHandler, directory=args.root)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    Path(args.port_file).write_text(str(server.server_port), encoding="utf-8")
    server.serve_forever()


if __name__ == "__main__":
    main()
