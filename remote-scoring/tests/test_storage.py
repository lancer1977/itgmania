from __future__ import annotations

import pytest

from remote_scoring.storage import ScoreStore


def sample_score(**overrides):
    payload = {
        "score_id": "score-1",
        "player_guid": "player-a",
        "player_name": "AAA",
        "song_title": "Remote Test",
        "chart_key": "dance-single:Challenge:12",
        "score": 950000,
        "percent_dp": 0.95,
        "max_combo": 400,
        "played_at": "2026-07-05T20:00:00Z",
        "judgments": {"W1": 400, "Miss": 0},
    }
    payload.update(overrides)
    return payload


def test_submit_score_is_idempotent(tmp_path):
    store = ScoreStore(tmp_path / "scores.sqlite3")

    first = store.submit_score(sample_score())
    second = store.submit_score(sample_score(score=990000, percent_dp=0.99))

    assert first.score_id == "score-1"
    assert first.duplicate is False
    assert second.duplicate is True
    assert second.payload["score"] == 950000


def test_leaderboard_orders_scores_and_excludes_disqualified(tmp_path):
    store = ScoreStore(tmp_path / "scores.sqlite3")
    store.submit_score(sample_score(score_id="a", player_guid="a", percent_dp=0.96))
    store.submit_score(sample_score(score_id="b", player_guid="b", percent_dp=0.98))
    store.submit_score(
        sample_score(
            score_id="c",
            player_guid="c",
            percent_dp=1.0,
            disqualified=True,
        )
    )

    entries = store.leaderboard(
        song_title="Remote Test",
        chart_key="dance-single:Challenge:12",
    )

    assert [entry["score"]["player_guid"] for entry in entries] == ["b", "a"]
    assert [entry["rank"] for entry in entries] == [1, 2]


def test_leaderboard_can_include_disqualified(tmp_path):
    store = ScoreStore(tmp_path / "scores.sqlite3")
    store.submit_score(sample_score(score_id="a", percent_dp=0.96))
    store.submit_score(sample_score(score_id="b", percent_dp=1.0, disqualified=True))

    entries = store.leaderboard(
        song_title="Remote Test",
        chart_key="dance-single:Challenge:12",
        include_disqualified=True,
    )

    assert [entry["score"]["score_id"] for entry in entries] == ["b", "a"]


def test_validation_requires_core_identity(tmp_path):
    store = ScoreStore(tmp_path / "scores.sqlite3")
    payload = sample_score()
    del payload["chart_key"]

    with pytest.raises(ValueError, match="chart_key is required"):
        store.submit_score(payload)


def test_score_history_filters_by_player_and_orders_recent_first(tmp_path):
    store = ScoreStore(tmp_path / "scores.sqlite3")
    store.submit_score(
        sample_score(
            score_id="old",
            player_guid="player-a",
            played_at="2026-07-05T20:00:00Z",
            percent_dp=0.99,
        )
    )
    store.submit_score(
        sample_score(
            score_id="new",
            player_guid="player-a",
            played_at="2026-07-05T21:00:00Z",
            percent_dp=0.90,
        )
    )
    store.submit_score(sample_score(score_id="other", player_guid="player-b"))

    scores = store.score_history(player_guid="player-a")

    assert [score["score_id"] for score in scores] == ["new", "old"]


def test_score_history_filters_chart_and_excludes_disqualified(tmp_path):
    store = ScoreStore(tmp_path / "scores.sqlite3")
    store.submit_score(
        sample_score(
            score_id="a",
            chart_hash="chart-a",
            song_group="Pack A",
            difficulty="Challenge",
            meter=12,
        )
    )
    store.submit_score(
        sample_score(
            score_id="b",
            chart_hash="chart-a",
            song_group="Pack A",
            difficulty="Challenge",
            meter=12,
            disqualified=True,
        )
    )
    store.submit_score(sample_score(score_id="c", chart_hash="chart-b"))

    scores = store.score_history(
        chart_hash="chart-a",
        song_group="Pack A",
        difficulty="Challenge",
        meter=12,
    )

    assert [score["score_id"] for score in scores] == ["a"]

    scores = store.score_history(chart_hash="chart-a", include_disqualified=True)

    assert [score["score_id"] for score in scores] == ["b", "a"]


def test_score_history_empty_results(tmp_path):
    store = ScoreStore(tmp_path / "scores.sqlite3")
    store.submit_score(sample_score(score_id="a", player_guid="player-a"))

    assert store.score_history(player_guid="missing") == []
