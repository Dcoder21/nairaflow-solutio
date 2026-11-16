# Project 1 dry-run journal — Nuel

One entry per day: what I did, what broke, how I fixed it, and what to tell interns.

## Day 1 — Cluster and the "before" picture (Fri 6 Nov 2026)

**Did**
- Installed the Mac toolbox with Homebrew (kubectl, kind, helm, k9s, glab, opentofu, tflint, checkov, conftest, trivy, syft, cosign, gitleaks, semgrep, argocd, kubeseal, istioctl, cmctl, openssl@3, testssl, mitmproxy). Already had Docker Desktop.
- Created the kind cluster `nairaflow` (1 control plane + 1 worker) from `kind.yaml`, with host ports 8080/8443 mapped for the gateway later.
- Ran the app the manual way with Docker Compose and sent a test transfer.

**Broke → fixed**
- `kind create cluster` failed: `docker-credential-desktop: executable file not found in $PATH`. Terminal couldn't find Docker Desktop's login helper. Fix: added `/Applications/Docker.app/Contents/Resources/bin` to PATH in `~/.zshrc`.
- Port 8080 is now owned by the kind cluster, so the Compose dashboard moved to 8081 (`docker-compose.yml`).

**Tell interns**
- Day 1 is "see the problem before the solution": the app works but is built by hand, runs as root, uses plain HTTP and keeps passwords in a file.
- kind = Kubernetes in Docker: each node is a Docker container, so you get a free on-prem-style cluster you can rebuild in 2 minutes.

## Day 2 — Protect main, runner, threat model

**Did**
- Moved the repo to GitLab (`nairaflow-group/nairaflow-starter`). Kept GitHub as a second remote called `github` (portfolio copy); `origin` = GitLab.
- Logged Git in with `glab auth login` (HTTPS, Git credentials = yes).
- Protected `main` (push: no one, merge: maintainers) and turned on "Pipelines must succeed".
- Installed the GitLab Runner in the cluster with Helm (namespace `gitlab-runner`, Kubernetes executor). First pipeline (`pytest`) passed: 3 tests.
- Started the STRIDE threat model in `docs/threat-model.md`.

**Broke → fixed**
- Pushes were going to GitHub: `origin` still pointed there. Fix: renamed it to `github`, added GitLab as `origin`.
- `git push` failed with an authentication error, then hung waiting for a login. Fix: `glab auth login` so Git uses the GitLab login.
- Runner pod stuck on "Pulling image" for 15+ minutes (gitlab-runner:alpine-v19.5.3). Fix: `docker pull` on the Mac, `kind load docker-image` into the cluster, delete the pod.
- Runner token was in a stray one-line file inside the repo folder. Moved it into the full values file in `nairaflow-lab` and git-ignored `runner-values.yaml`, `kind.yaml`, `CLAUDE.md`. Checked history: never committed.

**Tell interns**
- GitLab gives the orders; the runner does the work inside our cluster; the token proves the runner is ours; Helm is how we installed it ("brew for Kubernetes").
- Protected branches + required pipelines = the first fix for the 47-minute outage: every change is reviewed and traceable.

## Day 3 — Infrastructure as Code (Sat 7 Nov 2026)

**Did**
- Decided on one repo: infra code lives in `infra/` of nairaflow-starter, with its own child pipeline (`infra/.gitlab-ci.yml`) that only runs when `infra/` changes.
- Created a personal access token (api scope) and saved it as the masked CI variable `GITLAB_TOKEN`.
- Applied `infra/bootstrap/tofu-rbac.yaml`: the pipeline's least-privilege account `tofu-apply` (can manage namespaces, quotas, limit ranges, network policies; cannot create pods). Upgraded the runner so jobs can use it.
- Connected OpenTofu to GitLab-managed state (`scripts/tofu-init.sh dev`) and ran the first `tofu plan` on `envs/dev`: state lock acquired, plan shows the namespace, quota, limit range and network policy to be created.

**Broke → fixed**
- `kubectl auth can-i ... namespaces` printed "resource 'namespaces' is not namespace scoped": harmless warning, answer was still yes.
- Couldn't switch to `main`: uncommitted changes in `.gitlab-ci.yml` and `docs/threat-model.md` on the `day2-runner` branch. Fix: carry them onto a new `day4-infra` branch and commit them there.
- `git fetch` / `git push` failed with "HTTP Basic: Access denied": macOS Keychain still held an old GitLab password and Git used it before glab. Fix: erased the Keychain entry and set Git's credential helper for gitlab.com to `!glab auth git-credential`.
- Then `git: 'credential-glab' is not a git command`: zsh ate the `!` inside double quotes. Fix: set the helper with single quotes: `'!glab auth git-credential'`.

**Tell interns**
- Tofu is a remote control for anything with an API. Here it configures our on-prem platform (cluster + GitLab), not a cloud.
- `plan` shows what would change; only the pipeline applies, after review.
- "(known after apply)" = values Kubernetes assigns once the thing exists.

## Day 4 — The infrastructure pipeline (Sat 7 Nov 2026)

**Did**
- Committed infra/, the new root pipeline, threat model and journal on branch `day4-infra`; opened MR !2.

**Broke → fixed**
- `tflint` failed with 4 warnings: the modules didn't declare which OpenTofu version and provider versions they need. Fix: added `versions.tf` to both modules.
- The job ran on GitLab's shared SaaS runner (`saas-linux-small-amd64`), not on our runner in the kind cluster. Shared runners can't reach our on-prem cluster, so plan/apply would fail there. Fix: disabled instance (shared) runners for the project, so every job runs on our own runner.
- Shared GitLab runners were also enabled, plus a GitLab Duo (AI review) job from the Ultimate trial that got stuck once shared runners were off. Fix: turned off instance runners, cancelled the Duo job and turned off Duo auto-review; ticked "Run untagged jobs" on our runner (it had never run a job).
- First job on our own runner failed: `gitlab-runner-helper:x86_64-v19.5.3 ... no match for platform in manifest`. The runner asked for the Intel (x86_64) helper image, but our kind nodes are Apple Silicon (arm64). Fix: set `helper_image` to the `arm64-v19.5.3` tag in runner-values.yaml and `helm upgrade` the runner.
- `plan [shared]` failed: "Unable to find GitLab token". `GITLAB_TOKEN` was marked Protected, and protected variables are only given to pipelines on protected branches (like `main`), not to merge request pipelines. Fix: unticked "Protect variable" (kept Masked) so MR plans can read it. Trade-off noted: any branch pipeline can now use the token, so only maintainers should be able to push branches.
- `plan [shared]` then failed: "feature unavailable `push_access_level` ... Use `allowed_to_push` instead". The newer GitLab provider replaced those two settings with `allowed_to_push` / `allowed_to_merge` blocks. Fix: updated the gitlab-repo module (and the import drill example).
- `plan [shared]` failed again: "Blocks of type allowed_to_push are not expected here". Instead of guessing, asked the provider for its real schema (`tofu providers schema -json` in a throwaway folder): GitLab provider v19.5.0 takes `allowed_to_push = [{ access_level = "no one" }]`, a set assigned with `=`, not a block. Fixed the module and pinned the provider to `~> 19.5`.
- dev/staging/prod plans failed inside `apk add`: "Failed to create usr/lib/libunistring.so... I/O error" (step took ~5 minutes). Disk was only 1% used, so not a full disk: a one-off write error inside the kind node while 3 jobs installed packages at the same time on the laptop. Fix: retried the jobs, and added a 3-attempt retry around `apk add` in the pipeline so a single hiccup doesn't fail the plan.

**Tell interns**
- Linters fail on warnings by design: a module that doesn't pin its versions can break silently when a provider releases a new version.
- Always check *which* runner picked up your job (top of the job log). For on-prem work, jobs must run on runners inside your network.

**Result**
- MR pipeline green (api-tests + infra child pipeline), merged to `main`.
- On the `main` pipeline, clicked ▶ apply: shared, dev, staging, prod — all passed. The pipeline (not me) built the 3 namespaces and the private `nairaflow-config` repo.

## Next
- [x] Provider lock files for Mac + Linux
- [x] Day 4: commit infra, MR, pipeline green, apply from `main`, 3 namespaces exist
- [x] Day 5: blocked public-repo MR, drift issue, import drill

## Day 6 — Harden the api image

**Broke → fixed**
- Hardened container crashed: `PermissionError: [Errno 13] Permission denied: '/app/main.py'`. `main.py` on the Mac had permissions `-rw-------` (owner only). `COPY` keeps those permissions and makes root the owner, so user 65532 couldn't read it. Fix: `COPY --chmod=0444 main.py .` (read-only for everyone: the app can read its code but can't change it).

- Results: 1.73 GB → 282 MB; OS findings 282 (15 CRITICAL) → 49 HIGH (0 CRITICAL, 48 with no fix yet); root → user 65532. starlette 0.41.3 (3 HIGH) fix deferred to Day 8.

**Tell interns**
- Running as non-root exposes permission mistakes that root hid. That's a good thing: fix the permissions, never go back to root.

## Day 7 — Build all images in CI with Buildah

**Broke → fixed**
- `.gitlab-ci.yml` was silently reset to the old Day 2 version: VS Code had the file open in a stale tab and saved over the update. Fix: restored the file; always close and reopen a tab after a file is changed outside the editor.
- Buildah failed on the web image: `short-name resolution enforced but cannot prompt without a TTY`. Docker assumes `nginxinc/nginx-unprivileged` means Docker Hub; Buildah refuses to guess which registry a short name means (a guess could pull an impostor image from another registry). Fix: fully qualified names in every Dockerfile: `docker.io/nginxinc/nginx-unprivileged...` and `docker.io/library/python:3.12-slim...`.

**Tell interns**
- Always write the registry in image names. It's both a Buildah requirement and a supply-chain protection: you say exactly where the image comes from.

## Day 8 — Security scanning in CI

**Broke → fixed**
- Buildah image pinned to the wrong digest: `$D` still held the nginx digest from Day 7 because the new lookup didn't run, so `sed` reused it. Build jobs couldn't pull the image. Fix: `unset D`, look up again, `echo $D` before using it.
- `semgrep` crashed: `ModuleNotFoundError: No module named 'pkg_resources'`. Semgrep 1.95 depends on an OpenTelemetry module that imports `pkg_resources`, which comes from setuptools, and `python:3.12-slim` doesn't include setuptools. Fix: `pip install "setuptools<80" "semgrep==1.95.0"`.
- `gitleaks` passed on the first run: no secrets anywhere in the Git history.

**Tell interns**
- Shell variables live until the terminal closes: always `echo` a variable before using it in a command that edits files.
- A tool crashing is not the same as a tool finding something. Read whether the error is about your code or about the tool itself.

## Day 9 — SBOM and image signing (Mon 9 Nov 2026)

- Generated a Cosign key pair in `nairaflow-lab` (never in the repo). `cosign.pub` committed; `cosign.key` saved as CI variable `COSIGN_PRIVATE_KEY` (Type **File**, Protected).
- New `sign` stage, `sbom-sign` job (main only, ×3 images): Syft CycloneDX SBOM → `cosign sign` → SBOM + SLSA provenance attestations → verify in the pipeline.
- Build job now saves each image's digest, so we sign the exact bytes (`@sha256:…`), not a movable tag.

**Problems and fixes**
- "file name is too long": the key variable was Type *Variable*, so cosign got the key text instead of a file path. Fix: change it to Type **File** and retry.
- Local verify gave `DENIED: access forbidden`: the registry is private. Fix: log in with a read-only token (`read_registry` scope).
- zsh `parse error near \n`: `<digest>` was a placeholder, and `<` is a shell symbol. Fix: verify by commit-SHA tag; cosign resolves it to the digest.

**Result:** verified from the Mac: `api:59ac272a…` → digest `sha256:4b07ead9…`, "signatures were verified against the specified public key".

**Tell interns**
- Public key in the repo, private key only in a protected **File** variable.
- Tags can move; digests can't. Always sign the digest.

## Day 10 — Database with CloudNativePG (Mon 9 Nov 2026) — in progress

**Goal of Day 10:** run the signed images as a working app on Kubernetes, with its database and queue. Part A = the database.

- Installed the CloudNativePG operator with Helm (chart 0.29.1, app 1.30.1) in its own namespace `cnpg-system`. Screenshot: `screenshots/day10-01-cnpg-crds-installed.jpg`
- `infra/envs/dev/main.tf`: added `cnpg-system` to `allow_from_namespaces` so the operator can reach the database pods through our default-deny network policy. Changed through MR + pipeline, not kubectl.
- `deploy/db/postgres.yaml`: ConfigMap with the schema + seed accounts (tables handed to user `nairaflow`), and a CNPG `Cluster` called `pg` (1 instance, 1Gi, requests/limits for the quota). The operator generates the password into Secret `pg-app` — no password in Git.

- Proof: `psql` in `pg-1` lists all 4 seed accounts (ACC001–ACC004). Screenshot: `screenshots/day10-05-accounts-seeded.jpg`

**Part B — Redis**
- `deploy/redis/redis.yaml`: plain Deployment + Service (a queue, not the system of record, so no operator or disk). Image pinned by digest (`redis:8-alpine@sha256:7958cfbb…`), non-root 999, read-only root filesystem, all capabilities dropped, no service-account token, resources for the quota.
- Password: random, created with `kubectl create secret generic redis-auth ... $(openssl rand -hex 24)` — never typed, never in Git; Redis starts with `--requirepass $(REDIS_PASSWORD)`.
- Proof: `redis-cli ping` without the password → `NOAUTH Authentication required`; with it → `PONG`. Screenshot: `screenshots/day10-06-redis-auth-noauth-pong.jpg`

**Part C — Pull secret**
- GitLab deploy token `k8s-pull-dev` (scope `read_registry` only, with expiry) — belongs to the project, not a person, can only read images.
- Stored in the cluster as `kubectl create secret docker-registry gitlab-registry -n nairaflow-dev ...` (token read with `read -s`, never in Git or shell history).
- Proof: pod without the pass → `ImagePullBackOff`; same pod with `imagePullSecrets: gitlab-registry` → `pulled ok`. Test pods deleted. Screenshot: `screenshots/day10-07-pull-secret-before-after.jpg`

**Part D — Helm chart (`deploy/charts/nairaflow`)**
- One chart for api, worker and web. `values.yaml` = shared settings; `values-dev.yaml` = the image digests for dev.
- Images pinned by digest (the chart refuses to render without one) and checked with `cosign verify` before install — Day 9 pays off.
- Passwords only from Secrets: `DATABASE_URL` from `pg-app` (CNPG), `REDIS_URL` built from `redis-auth` via `$(REDIS_PASSWORD)`. Pull pass `gitlab-registry` on every pod.
- Same hardening as Redis: non-root, read-only root filesystem (+ `/tmp` emptyDir), all capabilities dropped, seccomp RuntimeDefault, no service-account token, resources for the quota. api readiness `/readyz`, liveness `/healthz`.
- `helm upgrade --install nairaflow ... -n nairaflow-dev -f values-dev.yaml --wait` → api, worker, web `1/1 Running`.

**Part F — End to end**
- `kubectl port-forward -n nairaflow-dev svc/web 8090:8080`, then through nginx: `/api/accounts` (4 accounts) → `POST /api/transfers` (`PENDING`) → worker log `processed <id>` → Postgres row `COMPLETED`. Screenshots: `screenshots/day10-08-end-to-end-transfer-completed.jpg`, `screenshots/day10-09-dashboard-in-kubernetes.jpg` (dashboard via port-forward: ACC001 ₦498,500, ACC002 ₦251,500, transfer ₦1,500 COMPLETED)

**Problems and fixes**
- `cosign verify` went to Docker Hub (`index.docker.io/v2//api`): `$R` was empty in a new terminal tab. Fix: set `R=...` again and `echo $R` first.
- `namespaces "nairaflow-dev" not found`: kubectl was pointed at a second test cluster (`kind-nairaflow-lab`, made while testing the intern walkthrough). Creating a kind cluster switches kubectl to it automatically. Fix: `kubectl config use-context kind-nairaflow`. Lesson: check `kubectl config current-context` first when things "disappear".
- Main pipeline `build: [api]` failed on push: `use of closed network connection`. Cause: home internet dropped during upload (runner lives on the Mac). Fix: Retry the job. Possible hardening: `retry: max 2` on the build job.
- Cluster stuck with `Instance Status Extraction Error: HTTP communication issue`. Cause: the MR was merged but **apply-dev was never run**, so the network policy still blocked `cnpg-system` from the pod's status port. Checked with `kubectl get networkpolicy ... | grep metadata.name` (only 2 names). Fix: ran ▶ apply-dev on the main infra pipeline; the operator got through on its own and the cluster went healthy. Screenshots: `day10-02-cnpg-http-communication-issue.jpg`, `day10-03-apply-dev-green.jpg`, `day10-04-gate-open-cluster-healthy.jpg`

**Tell interns**
- Merging code does not change the cluster. The apply job does.
- A default-deny policy blocks your own tools too: add each namespace on purpose, never switch the policy off.
- "Closed connection / timeout / reset" = network problem, not code. Retry first.
