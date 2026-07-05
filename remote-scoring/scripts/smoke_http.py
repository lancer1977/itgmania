#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import urllib.parse
import urllib.request
from datetime import UTC, datetime


def request_json(
    url: str,
    *,
    method: str = "GET",
    token: str | None = None,
    payload: dict | None = None,
    timeout: float = 5.0,
) -> dict:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Accept": "application/json"}
    if payload is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Smoke test an ITGmania remote-scoring backend.")
    parser.add_argument("--endpoint", default="http://127.0.0.1:8765")
    parser.add_argument("--token", default="dev-token")
    parser.add_argument("--timeout", type=float, default=5.0)
    args = parser.parse_args()

    endpoint = args.endpoint.rstrip("/")
    health = request_json(f"{endpoint}/health", timeout=args.timeout)
    assert health.get("ok") is True, health

    score = {
        "score_id": "smoke-itgmania-remote-scoring",
        "player_guid": "smoke-player",
        "player_name": "Smoke",
        "machine_guid": "smoke-cabinet",
        "song_title": "Smoke Song",
        "song_artist": "Smoke Artist",
        "song_group": "Smoke Pack",
        "song_hash": "smoke-song-hash",
        "chart_key": "dance-single:challenge:10",
        "chart_hash": "smoke-chart-hash",
        "steps_type": "dance-single",
        "difficulty": "challenge",
        "meter": 10,
        "played_at": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
        "score": 987654,
        "percent_dp": 0.987654,
        "grade": "Tier02",
        "max_combo": 512,
        "judgments": {"w1": 500, "w2": 10, "miss": 0},
        "disqualified": False,
        "metadata": {"source": "remote-scoring-smoke"},
    }
    submitted = request_json(
        f"{endpoint}/v1/scores",
        method="POST",
        token=args.token,
        payload=score,
        timeout=args.timeout,
    )
    assert submitted.get("score_id") == score["score_id"], submitted

    query = urllib.parse.urlencode({
        "song_title": score["song_title"],
        "chart_key": score["chart_key"],
    })
    leaderboard = request_json(f"{endpoint}/v1/leaderboards?{query}", timeout=args.timeout)
    entries = leaderboard.get("entries", [])
    assert entries, leaderboard
    assert entries[0]["score"]["score_id"] == score["score_id"], leaderboard

    print(json.dumps({
        "ok": True,
        "health": health,
        "score_id": score["score_id"],
        "leaderboard_entries": len(entries),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
