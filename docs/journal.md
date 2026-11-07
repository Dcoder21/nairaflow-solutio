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
- [ ] Day 5: blocked public-repo MR, drift issue, import drill
