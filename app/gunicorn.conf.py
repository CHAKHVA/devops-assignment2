"""Gunicorn configuration.

Enables prometheus_client multiprocess mode so metrics from all workers are
aggregated correctly. When a worker exits, its process-local metric files are
marked dead so stale gauges are not double-counted.
"""

from prometheus_client import multiprocess


def child_exit(server, worker):  # noqa: ARG001 (gunicorn hook signature)
    multiprocess.mark_process_dead(worker.pid)
