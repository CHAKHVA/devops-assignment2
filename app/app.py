import json
import logging
import time

from flask import Flask
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest

app = Flask(__name__)

# Suppress default Werkzeug logs
logging.getLogger("werkzeug").setLevel(logging.ERROR)

requests_total = Counter("app_requests_total", "Total number of requests")
errors_total = Counter("app_errors_total", "Total number of errors")


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
    requests_total.inc()
    log_request("/", 200)
    return {"status": "ok"}, 200


@app.route("/error")
def error():
    requests_total.inc()
    errors_total.inc()
    log_request("/error", 500)
    return {"status": "error", "message": "simulated error"}, 500


@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
