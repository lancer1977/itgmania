# ITGmania Remote Scoring Backend

Small standard-library Python service for collecting ITGmania score submissions
from local game builds, sidecars, or repo automation.

## Run Locally

```bash
cd remote-scoring
export REMOTE_SCORING_WRITE_TOKEN=change-me
python3 -m remote_scoring.server
```

The service listens on `127.0.0.1:8765` by default and stores data in
`./remote-scoring.sqlite3`.

Environment variables:

- `REMOTE_SCORING_HOST`: bind host, default `127.0.0.1`
- `REMOTE_SCORING_PORT`: bind port, default `8765`
- `REMOTE_SCORING_DB`: SQLite path, default `remote-scoring.sqlite3`
- `REMOTE_SCORING_WRITE_TOKEN`: bearer token required for score submission,
  default `dev-token`

## Run With Docker Compose

```bash
cd remote-scoring
export REMOTE_SCORING_WRITE_TOKEN=change-me
docker compose up --build
```

Compose binds the service to `0.0.0.0:8765` inside the container, publishes it
to `${REMOTE_SCORING_PORT:-8765}` on the host, and stores SQLite data in the
named volume `remote-scoring-data` at `/data/remote-scoring.sqlite3`.

Verify a running service with the smoke script:

```bash
python3 scripts/smoke_http.py \
  --endpoint http://127.0.0.1:${REMOTE_SCORING_PORT:-8765} \
  --token "$REMOTE_SCORING_WRITE_TOKEN"
```

The smoke script checks `/health`, submits an idempotent score, and verifies the
score appears in a leaderboard response.

## API

### `GET /health`

Returns service and database status.

### `POST /v1/scores`

Requires `Authorization: Bearer <REMOTE_SCORING_WRITE_TOKEN>`.

```json
{
  "score_id": "optional-client-idempotency-key",
  "player_guid": "profile-guid",
  "player_name": "Dancer",
  "machine_guid": "cabinet-guid",
  "song_title": "Example Song",
  "song_artist": "Example Artist",
  "song_group": "Pack Name",
  "song_hash": "optional-song-hash",
  "chart_key": "dance-single:Challenge:12",
  "chart_hash": "optional-chart-hash",
  "steps_type": "dance-single",
  "difficulty": "Challenge",
  "meter": 12,
  "played_at": "2026-07-05T20:00:00Z",
  "score": 987654,
  "percent_dp": 0.987654,
  "grade": "Tier02",
  "max_combo": 812,
  "judgments": {
    "W1": 500,
    "W2": 12,
    "Miss": 0
  },
  "modifiers": "1.5x, Overhead",
  "disqualified": false,
  "metadata": {
    "source": "itgmania"
  }
}
```

### `GET /v1/leaderboards`

Query parameters:

- `chart_hash`: preferred chart identity for exact chart leaderboards
- `song_hash`: song identity when chart hash is unavailable
- `song_title` and `chart_key`: fallback identity pair
- `limit`: 1-100, default 50
- `include_disqualified`: `true` or `false`, default `false`

Example:

```bash
curl 'http://127.0.0.1:8765/v1/leaderboards?song_title=Example%20Song&chart_key=dance-single:Challenge:12'
```

### `GET /v1/scores/{score_id}`

Returns one stored score by id.

## Integration Notes

The schema mirrors ITGmania high score concepts without requiring a game-engine
link yet: profile GUID, machine GUID, grade, score, percent DP, combo,
judgments, modifiers, timestamp, and disqualification state.

For a game-side uploader, send the request after `HighScore` data is committed
locally. For a sidecar or repo automation, reuse `score_id` as an idempotency
key so retries do not duplicate records.
