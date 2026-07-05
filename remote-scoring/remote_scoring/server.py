from __future__ import annotations

import json
import os
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlparse

from .storage import ScoreStore


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
DEFAULT_DB = "remote-scoring.sqlite3"
DEFAULT_WRITE_TOKEN = "dev-token"


def json_bytes(payload: object) -> bytes:
    return json.dumps(payload, sort_keys=True).encode("utf-8")


def parse_bool(value: str | None, default: bool = False) -> bool:
    if value is None:
        return default
    return value.lower() in {"1", "true", "yes", "on"}


class RemoteScoringHandler(BaseHTTPRequestHandler):
    server_version = "ITGmaniaRemoteScoring/0.1"

    @property
    def store(self) -> ScoreStore:
        return self.server.store  # type: ignore[attr-defined]

    @property
    def write_token(self) -> str:
        return self.server.write_token  # type: ignore[attr-defined]

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self.respond_json(
                HTTPStatus.OK,
                {
                    "ok": True,
                    "service": "itgmania-remote-scoring",
                    "database": str(self.store.path),
                },
            )
            return

        if parsed.path == "/v1/leaderboards":
            self.handle_leaderboard(parsed.query)
            return

        if parsed.path.startswith("/v1/scores/"):
            score_id = unquote(parsed.path.removeprefix("/v1/scores/"))
            score = self.store.get_score(score_id)
            if score is None:
                self.respond_error(HTTPStatus.NOT_FOUND, "score not found")
                return
            self.respond_json(HTTPStatus.OK, {"score": score})
            return

        self.respond_error(HTTPStatus.NOT_FOUND, "route not found")

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/v1/scores":
            self.respond_error(HTTPStatus.NOT_FOUND, "route not found")
            return

        auth = self.headers.get("Authorization", "")
        if auth != f"Bearer {self.write_token}":
            self.respond_error(HTTPStatus.UNAUTHORIZED, "invalid bearer token")
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.respond_error(HTTPStatus.BAD_REQUEST, "invalid content length")
            return

        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
            stored = self.store.submit_score(payload)
        except json.JSONDecodeError:
            self.respond_error(HTTPStatus.BAD_REQUEST, "invalid JSON")
            return
        except ValueError as exc:
            self.respond_error(HTTPStatus.UNPROCESSABLE_ENTITY, str(exc))
            return

        status = HTTPStatus.OK if stored.duplicate else HTTPStatus.CREATED
        self.respond_json(
            status,
            {
                "score_id": stored.score_id,
                "duplicate": stored.duplicate,
                "score": stored.payload,
            },
        )

    def handle_leaderboard(self, query: str) -> None:
        params = parse_qs(query)

        def one(key: str) -> str | None:
            values = params.get(key)
            return values[0] if values else None

        try:
            limit = int(one("limit") or "50")
        except ValueError:
            self.respond_error(HTTPStatus.BAD_REQUEST, "limit must be an integer")
            return

        try:
            entries = self.store.leaderboard(
                chart_hash=one("chart_hash"),
                song_hash=one("song_hash"),
                song_title=one("song_title"),
                chart_key=one("chart_key"),
                limit=limit,
                include_disqualified=parse_bool(one("include_disqualified")),
            )
        except ValueError as exc:
            self.respond_error(HTTPStatus.BAD_REQUEST, str(exc))
            return

        self.respond_json(HTTPStatus.OK, {"entries": entries})

    def respond_json(self, status: HTTPStatus, payload: object) -> None:
        body = json_bytes(payload)
        self.send_response(status.value)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def respond_error(self, status: HTTPStatus, message: str) -> None:
        self.respond_json(status, {"error": message})

    def log_message(self, format: str, *args: object) -> None:
        if os.environ.get("REMOTE_SCORING_ACCESS_LOG") == "1":
            super().log_message(format, *args)


class RemoteScoringServer(ThreadingHTTPServer):
    def __init__(self, server_address: tuple[str, int], store: ScoreStore, token: str):
        super().__init__(server_address, RemoteScoringHandler)
        self.store = store
        self.write_token = token


def main() -> None:
    host = os.environ.get("REMOTE_SCORING_HOST", DEFAULT_HOST)
    port = int(os.environ.get("REMOTE_SCORING_PORT", str(DEFAULT_PORT)))
    db_path = os.environ.get("REMOTE_SCORING_DB", DEFAULT_DB)
    token = os.environ.get("REMOTE_SCORING_WRITE_TOKEN", DEFAULT_WRITE_TOKEN)

    server = RemoteScoringServer((host, port), ScoreStore(db_path), token)
    print(f"ITGmania remote scoring listening on http://{host}:{port}")
    print(f"SQLite database: {db_path}")
    server.serve_forever()


if __name__ == "__main__":
    main()
