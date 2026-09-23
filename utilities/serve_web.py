"""Serve the Godot web preview on this computer only.

Usage from the project directory:
    python utilities/serve_web.py
    python utilities/serve_web.py --port 8766 --directory builds/web

The default export directory is builds/web beside this script's parent directory.
Open the printed URL in a browser. Press Ctrl+C to stop the server.
"""

from __future__ import annotations

import argparse
import functools
import os
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit


class PreviewHandler(SimpleHTTPRequestHandler):
    """Read-only file serving, contained within one resolved export directory."""

    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript; charset=utf-8",
        ".mjs": "text/javascript; charset=utf-8",
        ".html": "text/html; charset=utf-8",
        ".pck": "application/octet-stream",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def _contained_path(self) -> Path:
        root = Path(self.directory).resolve()
        decoded = unquote(urlsplit(self.path).path, errors="strict")
        parts = decoded.replace("\\", "/").split("/")
        if "\x00" in decoded or any(p == ".." or ":" in p for p in parts):
            raise ValueError("Invalid path")
        target = root.joinpath(*(p for p in parts if p not in ("", "."))).resolve()
        target.relative_to(root)
        if target.is_dir():
            for name in ("index.html", "index.htm"):
                candidate = target / name
                if candidate.exists():
                    target = candidate.resolve()
                    target.relative_to(root)
                    break
        return target

    def send_head(self):
        try:
            target = self._contained_path()
        except (ValueError, OSError, RuntimeError, UnicodeError):
            self.send_error(HTTPStatus.FORBIDDEN, "Path is outside the preview")
            return None
        if target.is_dir():
            self.send_error(HTTPStatus.FORBIDDEN, "Directory listing is disabled")
            return None
        try:
            source = target.open("rb")
        except OSError:
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return None
        try:
            stat = os.fstat(source.fileno())
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", self.guess_type(str(target)))
            self.send_header("Content-Length", str(stat.st_size))
            self.send_header("Last-Modified", self.date_time_string(stat.st_mtime))
            self.end_headers()
            return source
        except BaseException:
            source.close()
            raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument(
        "--directory",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "builds" / "web",
    )
    args = parser.parse_args()
    if not 0 <= args.port <= 65535:
        parser.error("--port must be between 0 and 65535")
    directory = args.directory.resolve()
    if not directory.is_dir():
        parser.error(f"Export directory does not exist: {directory}")
    handler = functools.partial(PreviewHandler, directory=str(directory))
    with ThreadingHTTPServer(("127.0.0.1", args.port), handler) as server:
        print(f"Godot preview: http://127.0.0.1:{server.server_port}/", flush=True)
        print(f"Serving: {directory}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
