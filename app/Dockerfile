FROM python:3.13-slim

# Do not buffer stdout/stderr so JSON logs are flushed immediately for Promtail.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py gunicorn.conf.py ./

# Directory for prometheus_client multiprocess metrics (shared across workers).
ENV PROMETHEUS_MULTIPROC_DIR=/tmp/prometheus_multiproc

# Run as a non-root user for a smaller attack surface.
RUN useradd --no-create-home --uid 10001 appuser \
    && mkdir -p "$PROMETHEUS_MULTIPROC_DIR" \
    && chown appuser:appuser "$PROMETHEUS_MULTIPROC_DIR"
USER appuser

EXPOSE 5000

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:5000/health').status==200 else 1)"

# Production-grade WSGI server instead of the Flask dev server.
CMD ["gunicorn", "--config", "gunicorn.conf.py", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
