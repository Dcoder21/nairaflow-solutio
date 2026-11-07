# syntax=docker/dockerfile:1
# NairaFlow worker — hardened image (Project 1, Day 7). Same pattern as the api.
ARG PYTHON_IMAGE=docker.io/library/python:3.12-slim@sha256:4840d514c583a4d3d8cad3940e68dee6f0f6f3635c12fcd0a3d74c21a5b93a54

# ---------- Stage 1: builder ----------
FROM ${PYTHON_IMAGE} AS builder
ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt
RUN pip uninstall -y pip setuptools wheel || true

# ---------- Stage 2: runtime ----------
FROM ${PYTHON_IMAGE} AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Debian security updates that have a fix
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/*

# No pip at runtime; unprivileged user with a fixed ID
RUN (python -m pip uninstall -y pip setuptools wheel || true) \
 && groupadd --system --gid 65532 nonroot \
 && useradd --system --uid 65532 --gid nonroot --no-create-home \
      --shell /usr/sbin/nologin nonroot

WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY --chmod=0444 worker.py .

USER 65532:65532
CMD ["python", "worker.py"]
