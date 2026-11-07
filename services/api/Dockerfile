# syntax=docker/dockerfile:1
# NairaFlow API — hardened image (Project 1, Day 6)
#
# Why each choice:
#  - Multi-stage: build tools stay in the builder; the final image only gets what it runs.
#  - Same base for both stages: the copied virtual environment needs the same Python version.
#  - Pinned by digest (see Day 6 step "pin"): the base can't change underneath us.
#  - Non-root user 65532: a broken-into container can't act as root.

ARG PYTHON_IMAGE=python:3.12-slim@sha256:4840d514c583a4d3d8cad3940e68dee6f0f6f3635c12fcd0a3d74c21a5b93a54

# ---------- Stage 1: builder (installs dependencies) ----------
FROM ${PYTHON_IMAGE} AS builder
ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt
# pip is not needed once dependencies are installed
RUN pip uninstall -y pip setuptools wheel || true

# ---------- Stage 2: runtime (only what the app needs) ----------
FROM ${PYTHON_IMAGE} AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Apply Debian security updates that have a fix (e.g. zlib1g), then clean up.
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/*

# Remove the base image's pip (not needed at runtime, frequent CVE source)
# and create an unprivileged user with a fixed ID.
RUN (python -m pip uninstall -y pip setuptools wheel || true) \
 && groupadd --system --gid 65532 nonroot \
 && useradd --system --uid 65532 --gid nonroot --no-create-home \
      --shell /usr/sbin/nologin nonroot

WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
# Read-only for everyone: the non-root user can read the code but not change it.
COPY --chmod=0444 main.py .

USER 65532:65532
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
