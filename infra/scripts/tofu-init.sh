#!/usr/bin/env bash
# Connect a local folder to the GitLab-managed state, for local plans only.
# Usage:  export GITLAB_TOKEN=glpat-...  GITLAB_USER=yourname  PROJECT_ID=12345
#         ./scripts/tofu-init.sh dev
set -euo pipefail
ENV="${1:?usage: tofu-init.sh shared|dev|staging|prod}"
ADDR="https://gitlab.com/api/v4/projects/${PROJECT_ID:?set PROJECT_ID}/terraform/state/${ENV}"
cd "envs/${ENV}"
tofu init -reconfigure \
  -backend-config="address=${ADDR}" \
  -backend-config="lock_address=${ADDR}/lock" \
  -backend-config="unlock_address=${ADDR}/lock" \
  -backend-config="username=${GITLAB_USER:?set GITLAB_USER}" \
  -backend-config="password=${GITLAB_TOKEN:?set GITLAB_TOKEN}" \
  -backend-config="lock_method=POST" \
  -backend-config="unlock_method=DELETE" \
  -backend-config="retry_wait_min=5"
