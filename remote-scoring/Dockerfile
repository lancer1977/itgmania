FROM python:3-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    REMOTE_SCORING_HOST=0.0.0.0 \
    REMOTE_SCORING_PORT=8765 \
    REMOTE_SCORING_DB=/data/remote-scoring.sqlite3

WORKDIR /app

RUN adduser --disabled-password --gecos "" --home /app appuser \
    && mkdir -p /data \
    && chown -R appuser:appuser /app /data

COPY --chown=appuser:appuser remote_scoring ./remote_scoring
COPY --chown=appuser:appuser scripts ./scripts
COPY --chown=appuser:appuser README.md ./README.md

USER appuser

EXPOSE 8765

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import json,urllib.request; data=json.load(urllib.request.urlopen('http://127.0.0.1:8765/health', timeout=2)); raise SystemExit(0 if data.get('ok') else 1)"

CMD ["python", "-m", "remote_scoring.server"]
