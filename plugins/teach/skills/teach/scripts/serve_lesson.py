#!/usr/bin/env python3
"""Serve one Teach lesson on the local machine only."""

from __future__ import annotations

import argparse
import functools
import http.server
import socket
import sys
import threading
import urllib.parse
import webbrowser
from pathlib import Path


def port_is_available(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        return probe.connect_ex(("127.0.0.1", port)) != 0


def choose_port(preferred: int) -> int:
    if preferred == 0 or port_is_available(preferred):
        return preferred
    for candidate in range(preferred + 1, preferred + 21):
        if port_is_available(candidate):
            return candidate
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lesson", help="Path to a lesson directory or index.html")
    parser.add_argument("--port", type=int, default=4173, help="Preferred local port (default: 4173)")
    parser.add_argument("--no-open", action="store_true", help="Do not open the browser automatically")
    args = parser.parse_args()

    target = Path(args.lesson).expanduser().resolve()
    if target.is_file():
        directory = target.parent
        page = target.name
    elif target.is_dir():
        directory = target
        page = "index.html"
    else:
        print(f"Lesson not found: {target}", file=sys.stderr)
        return 2

    if not (directory / page).is_file():
        print(f"Lesson page not found: {directory / page}", file=sys.stderr)
        return 2

    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(directory))
    port = choose_port(args.port)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    actual_port = server.server_address[1]
    url = f"http://127.0.0.1:{actual_port}/{urllib.parse.quote(page)}"

    print(f"Teach is running at {url}")
    print("Press Ctrl+C to stop the local server.")

    if not args.no_open:
        threading.Timer(0.35, lambda: webbrowser.open(url)).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nTeach stopped.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
