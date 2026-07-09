from __future__ import annotations

import json
import sqlite3
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


REQUIRED_SCORE_FIELDS = (
    "player_guid",
    "song_title",
    "chart_key",
    "score",
    "percent_dp",
)


def utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def normalize_played_at(value: Any) -> str:
    if value is None or value == "":
        return utc_now()
    if not isinstance(value, str):
        raise ValueError("played_at must be an ISO-8601 string")
    normalized = value.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise ValueError("played_at must be an ISO-8601 string") from exc
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC).isoformat().replace("+00:00", "Z")


def require_string(payload: dict[str, Any], key: str) -> str:
    value = payload.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{key} is required")
    return value.strip()


def optional_string(payload: dict[str, Any], key: str) -> str | None:
    value = payload.get(key)
    if value is None:
        return None
    if not isinstance(value, str):
        raise ValueError(f"{key} must be a string")
    value = value.strip()
    return value or None


def optional_int(payload: dict[str, Any], key: str) -> int | None:
    value = payload.get(key)
    if value is None:
        return None
    if not isinstance(value, int) or isinstance(value, bool):
        raise ValueError(f"{key} must be an integer")
    return value


def require_int(payload: dict[str, Any], key: str) -> int:
    value = optional_int(payload, key)
    if value is None:
        raise ValueError(f"{key} is required")
    if value < 0:
        raise ValueError(f"{key} must be non-negative")
    return value


def require_percent(payload: dict[str, Any]) -> float:
    value = payload.get("percent_dp")
    if not isinstance(value, int | float) or isinstance(value, bool):
        raise ValueError("percent_dp is required")
    value = float(value)
    if value < 0 or value > 1.1:
        raise ValueError("percent_dp must be between 0 and 1.1")
    return value


def optional_object(payload: dict[str, Any], key: str) -> dict[str, Any]:
    value = payload.get(key)
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise ValueError(f"{key} must be an object")
    return value


@dataclass(frozen=True)
class StoredScore:
    score_id: str
    duplicate: bool
    payload: dict[str, Any]


class ScoreStore:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._initialize()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        return conn

    def _initialize(self) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS scores (
                    score_id TEXT PRIMARY KEY,
                    player_guid TEXT NOT NULL,
                    player_name TEXT,
                    machine_guid TEXT,
                    song_title TEXT NOT NULL,
                    song_artist TEXT,
                    song_group TEXT,
                    song_hash TEXT,
                    chart_key TEXT NOT NULL,
                    chart_hash TEXT,
                    steps_type TEXT,
                    difficulty TEXT,
                    meter INTEGER,
                    played_at TEXT NOT NULL,
                    score INTEGER NOT NULL,
                    percent_dp REAL NOT NULL,
                    grade TEXT,
                    max_combo INTEGER,
                    disqualified INTEGER NOT NULL,
                    payload_json TEXT NOT NULL,
                    created_at TEXT NOT NULL
                )
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_scores_chart_hash
                ON scores(chart_hash, disqualified, percent_dp DESC, score DESC)
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_scores_song_chart
                ON scores(song_title, chart_key, disqualified, percent_dp DESC, score DESC)
                """
            )

    def submit_score(self, payload: dict[str, Any]) -> StoredScore:
        normalized = self.validate_score(payload)
        payload_json = json.dumps(normalized, sort_keys=True, separators=(",", ":"))
        values = {
            "score_id": normalized["score_id"],
            "player_guid": normalized["player_guid"],
            "player_name": normalized.get("player_name"),
            "machine_guid": normalized.get("machine_guid"),
            "song_title": normalized["song_title"],
            "song_artist": normalized.get("song_artist"),
            "song_group": normalized.get("song_group"),
            "song_hash": normalized.get("song_hash"),
            "chart_key": normalized["chart_key"],
            "chart_hash": normalized.get("chart_hash"),
            "steps_type": normalized.get("steps_type"),
            "difficulty": normalized.get("difficulty"),
            "meter": normalized.get("meter"),
            "played_at": normalized["played_at"],
            "score": normalized["score"],
            "percent_dp": normalized["percent_dp"],
            "grade": normalized.get("grade"),
            "max_combo": normalized.get("max_combo"),
            "disqualified": 1 if normalized["disqualified"] else 0,
            "payload_json": payload_json,
            "created_at": utc_now(),
        }

        with self._connect() as conn:
            try:
                conn.execute(
                    """
                    INSERT INTO scores (
                        score_id, player_guid, player_name, machine_guid,
                        song_title, song_artist, song_group, song_hash,
                        chart_key, chart_hash, steps_type, difficulty, meter,
                        played_at, score, percent_dp, grade, max_combo,
                        disqualified, payload_json, created_at
                    ) VALUES (
                        :score_id, :player_guid, :player_name, :machine_guid,
                        :song_title, :song_artist, :song_group, :song_hash,
                        :chart_key, :chart_hash, :steps_type, :difficulty, :meter,
                        :played_at, :score, :percent_dp, :grade, :max_combo,
                        :disqualified, :payload_json, :created_at
                    )
                    """,
                    values,
                )
            except sqlite3.IntegrityError:
                existing = self.get_score(normalized["score_id"])
                if existing is None:
                    raise
                return StoredScore(normalized["score_id"], True, existing)

        return StoredScore(normalized["score_id"], False, normalized)

    def get_score(self, score_id: str) -> dict[str, Any] | None:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT payload_json FROM scores WHERE score_id = ?",
                (score_id,),
            ).fetchone()
        if row is None:
            return None
        return json.loads(row["payload_json"])

    def leaderboard(
        self,
        *,
        chart_hash: str | None = None,
        song_hash: str | None = None,
        song_title: str | None = None,
        chart_key: str | None = None,
        limit: int = 50,
        include_disqualified: bool = False,
    ) -> list[dict[str, Any]]:
        limit = max(1, min(limit, 100))
        filters: list[str] = []
        args: list[Any] = []

        if chart_hash:
            filters.append("chart_hash = ?")
            args.append(chart_hash)
        elif song_hash:
            filters.append("song_hash = ?")
            args.append(song_hash)
            if chart_key:
                filters.append("chart_key = ?")
                args.append(chart_key)
        elif song_title and chart_key:
            filters.append("song_title = ?")
            filters.append("chart_key = ?")
            args.extend([song_title, chart_key])
        else:
            raise ValueError(
                "provide chart_hash, song_hash, or song_title plus chart_key"
            )

        if not include_disqualified:
            filters.append("disqualified = 0")

        args.append(limit)
        query = f"""
            SELECT payload_json
            FROM scores
            WHERE {" AND ".join(filters)}
            ORDER BY percent_dp DESC, score DESC, max_combo DESC, played_at ASC
            LIMIT ?
        """
        with self._connect() as conn:
            rows = conn.execute(query, args).fetchall()

        entries = []
        for rank, row in enumerate(rows, start=1):
            score = json.loads(row["payload_json"])
            entries.append({"rank": rank, "score": score})
        return entries

    def score_history(
        self,
        *,
        player_guid: str | None = None,
        song_group: str | None = None,
        song_hash: str | None = None,
        song_title: str | None = None,
        chart_key: str | None = None,
        chart_hash: str | None = None,
        difficulty: str | None = None,
        meter: int | None = None,
        include_disqualified: bool = False,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        limit = max(1, min(limit, 100))
        filters: list[str] = []
        args: list[Any] = []

        equals_filters = {
            "player_guid": player_guid,
            "song_group": song_group,
            "song_hash": song_hash,
            "song_title": song_title,
            "chart_key": chart_key,
            "chart_hash": chart_hash,
            "difficulty": difficulty,
            "meter": meter,
        }
        for column, value in equals_filters.items():
            if value is not None and value != "":
                filters.append(f"{column} = ?")
                args.append(value)

        if not include_disqualified:
            filters.append("disqualified = 0")

        where = f"WHERE {' AND '.join(filters)}" if filters else ""
        args.append(limit)
        query = f"""
            SELECT payload_json
            FROM scores
            {where}
            ORDER BY played_at DESC, created_at DESC, percent_dp DESC, score DESC
            LIMIT ?
        """
        with self._connect() as conn:
            rows = conn.execute(query, args).fetchall()

        return [json.loads(row["payload_json"]) for row in rows]

    @staticmethod
    def validate_score(payload: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(payload, dict):
            raise ValueError("request body must be a JSON object")
        for field in REQUIRED_SCORE_FIELDS:
            if field not in payload:
                raise ValueError(f"{field} is required")

        normalized: dict[str, Any] = {
            "score_id": optional_string(payload, "score_id") or str(uuid.uuid4()),
            "player_guid": require_string(payload, "player_guid"),
            "song_title": require_string(payload, "song_title"),
            "chart_key": require_string(payload, "chart_key"),
            "score": require_int(payload, "score"),
            "percent_dp": require_percent(payload),
            "played_at": normalize_played_at(payload.get("played_at")),
            "disqualified": bool(payload.get("disqualified", False)),
            "judgments": optional_object(payload, "judgments"),
            "metadata": optional_object(payload, "metadata"),
        }

        for field in (
            "player_name",
            "machine_guid",
            "song_artist",
            "song_group",
            "song_hash",
            "chart_hash",
            "steps_type",
            "difficulty",
            "grade",
            "modifiers",
        ):
            value = optional_string(payload, field)
            if value is not None:
                normalized[field] = value

        for field in ("meter", "max_combo"):
            value = optional_int(payload, field)
            if value is not None:
                if value < 0:
                    raise ValueError(f"{field} must be non-negative")
                normalized[field] = value

        if not isinstance(normalized["disqualified"], bool):
            raise ValueError("disqualified must be a boolean")

        return normalized
