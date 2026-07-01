import json
import logging
import time

from flask import Flask
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)

app = Flask(__name__)

# Suppress default Werkzeug logs; we emit our own structured JSON logs.
logging.getLogger("werkzeug").setLevel(logging.ERROR)

requests_total = Counter(
    "app_requests_total", "Total number of requests", ["endpoint", "status"]
)
errors_total = Counter("app_errors_total", "Total number of errors")
request_latency = Histogram(
    "app_request_latency_seconds",
    "Request latency in seconds",
    ["endpoint"],
)


def log_request(endpoint: str, status: int) -> None:
    print(
        json.dumps(
            {
                "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "level": "ERROR" if status >= 400 else "INFO",
                "endpoint": endpoint,
                "status": status,
            }
        ),
        flush=True,
    )


@app.route("/")
def index():
    with request_latency.labels(endpoint="/").time():
        requests_total.labels(endpoint="/", status=200).inc()
        log_request("/", 200)
        return {"status": "ok"}, 200


@app.route("/error")
def error():
    with request_latency.labels(endpoint="/error").time():
        requests_total.labels(endpoint="/error", status=500).inc()
        errors_total.inc()
        log_request("/error", 500)
        return {"status": "error", "message": "simulated error"}, 500


@app.route("/health")
def health():
    # Lightweight liveness/readiness probe used by Docker healthchecks
    # and post-deployment verification. Intentionally unmetered/unlogged
    # to avoid polluting request metrics with probe traffic.
    return {"status": "healthy"}, 200


@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
