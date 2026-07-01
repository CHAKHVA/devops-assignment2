from app import app


def client():
    app.testing = True
    return app.test_client()


def test_index_returns_ok():
    resp = client().get("/")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_error_returns_500():
    resp = client().get("/error")
    assert resp.status_code == 500
    assert resp.get_json()["status"] == "error"


def test_health_returns_healthy():
    resp = client().get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "healthy"}


def test_metrics_exposes_prometheus_data():
    resp = client().get("/metrics")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "app_requests_total" in body
    assert "app_request_latency_seconds" in body
