# Command log — Project 1 (source for the final documentation)

Only commands that **worked** go here, in the order they were run, with **what** each one did and **why** we did it.
Failed attempts and their fixes live in `docs/journal.md`. Screenshots live in `docs/screenshots/`.

Legend: **What** = what the command does · **Why** = why NairaFlow needs it · **Result** = what we saw

---

## Day 1 — Build the on-prem cluster, see the "before" picture

### 1.1 Make Docker's login helper findable (one-time Mac fix)
```bash
echo 'export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin"' >> ~/.zshrc
source ~/.zshrc
which docker-credential-desktop
```
- **What:** adds Docker Desktop's tools folder to the terminal's search path.
- **Why:** kind downloads its node image through Docker; Docker needs `docker-credential-desktop` to log in.
- **Result:** `/Applications/Docker.app/Contents/Resources/bin/docker-credential-desktop`

### 1.2 Create the cluster (our "data centre")
```bash
cd ~/Documents/nairaflow-lab
kind create cluster --config kind.yaml
kubectl cluster-info --context kind-nairaflow
kubectl get nodes
```
- **What:** kind ("Kubernetes in Docker") starts 2 Docker containers and turns them into a Kubernetes cluster: `nairaflow-control-plane` (the brain) and `nairaflow-worker` (where apps run). `kind.yaml` also maps host ports 8080/8443 for HTTPS on days 12–14.
- **Why:** NairaFlow runs on its own on-prem servers. The cluster is our copy of that data centre; everything later runs on it.
- **Result:** "Set kubectl context to kind-nairaflow"; control plane running; 2 nodes `Ready`.

### 1.3 Run the app the old, manual way
```bash
cd ~/Documents/nairaflow-starter
cp .env.example .env
sed -i '' 's/"8080:80"/"8081:80"/' docker-compose.yml
docker compose up --build -d
curl -s -X POST localhost:8000/transfers -H 'Content-Type: application/json' \
  -d '{"from_account":"ACC001","to_account":"ACC002","amount_kobo":150000}'
```
- **What:** builds and starts web, api, worker, Postgres and Redis on the Mac; sends a test transfer. Dashboard moved to 8081 because kind owns 8080.
- **Why:** the "before" picture: built by hand, root containers, plain HTTP, passwords in a file. We fix each of these later.
- **Result:** transfer `COMPLETED` on http://localhost:8081.

---

## Day 2 — Control changes, add our own runner, model threats

### 2.1 Point Git at GitLab (keep GitHub as a backup copy)
```bash
cd ~/Documents/nairaflow-starter
git remote rename origin github
git remote add origin https://gitlab.com/nairaflow-group/nairaflow-starter.git
git remote -v
```
- **What:** `origin` (where `git push` goes) = GitLab; `github` = optional portfolio copy.
- **Why:** GitLab is where our protected branches, pipelines and runner live.
- **Result:** `origin → gitlab.com/nairaflow-group/nairaflow-starter.git`, `github → github.com/Dcoder21/...`

### 2.2 Log Git in to GitLab
```bash
glab auth login                       # gitlab.com → Web → HTTPS → Yes to Git credentials
printf "protocol=https\nhost=gitlab.com\n\n" | git credential-osxkeychain erase
git config --global --unset-all credential.https://gitlab.com.helper
git config --global credential.https://gitlab.com.helper ''
git config --global --add credential.https://gitlab.com.helper '!glab auth git-credential'
```
- **What:** logs glab in, removes an old saved password from the macOS Keychain, and tells Git to ask glab for GitLab logins. Single quotes keep the `!` (zsh treats `!` in double quotes specially).
- **Why:** GitLab doesn't accept account passwords for Git over HTTPS; it needs a token.
- **Result:** `git fetch` / `git push` to GitLab work.

### 2.3 Protect `main` (GitLab UI)
- Settings → Repository → Protected branches: `main` push = **No one**, merge = **Maintainers**
- Settings → Merge requests: **Pipelines must succeed**
- **Why:** first fix for the 47-minute outage: every change is reviewed, tested and traceable.

### 2.4 Install the GitLab Runner in the cluster with Helm
```bash
helm repo add gitlab https://charts.gitlab.io && helm repo update
helm upgrade --install gitlab-runner gitlab/gitlab-runner \
  -n gitlab-runner --create-namespace \
  -f ~/Documents/nairaflow-lab/runner-values.yaml
kubectl get pods -n gitlab-runner -w
```
- **What:** Helm ("brew for Kubernetes") installs the runner's 7 objects: namespace, Deployment, pod, Secret (token), ConfigMap (config.toml), ServiceAccount, Role/RoleBinding.
- **Why:** GitLab gives the orders; the runner does the work **inside our cluster**, so NairaFlow's code is built on our machines. The `glrt-` token in the values file proves the runner is ours.
- **Result:** runner pod `Running`; green dot in GitLab.

### 2.5 Pre-load slow images into the cluster (when a pod is stuck on "Pulling")
```bash
IMG=registry.gitlab.com/gitlab-org/gitlab-runner:alpine-v19.5.3
docker pull --platform linux/arm64 $IMG
kind load docker-image $IMG --name nairaflow
kubectl delete pod -n gitlab-runner -l app=gitlab-runner
```
- **What:** downloads the image on the Mac (fast) and copies it into the kind nodes, then restarts the pod.
- **Why:** downloads from inside the cluster were stuck for 15+ minutes.
- **Result:** pod `Running` within seconds.

### 2.6 First pipeline + threat model
```bash
git checkout -b day2-runner
git add .gitlab-ci.yml docs/threat-model.md
git commit -m "Day 2: first pipeline and threat model"
git push -u origin day2-runner
glab mr create --fill --yes
```
- **What:** first `.gitlab-ci.yml` (runs pytest) + STRIDE threat model, through a merge request.
- **Why:** proves the chain push → GitLab → runner → pod → result; the threat model is our to-do list for the project.
- **Result:** `3 passed`.

---

## Day 3 — Infrastructure as Code (OpenTofu)

### 3.1 Set the GitLab group
```bash
sed -i '' 's/CHANGE_ME/nairaflow-group/' infra/envs/shared/terraform.tfvars
```
- **Why:** the `shared` environment creates repos inside our group.

### 3.2 CI variable `GITLAB_TOKEN` (GitLab UI)
- Personal access token, scope `api` → Settings → CI/CD → Variables → `GITLAB_TOKEN`, **Masked**, **not Protected**.
- **Why:** lets the pipeline create the `nairaflow-config` repo and open drift issues. Not Protected so merge request plans can read it.

### 3.3 Give the pipeline a limited key, and let the runner use it
```bash
kubectl apply -f infra/bootstrap/tofu-rbac.yaml
helm upgrade gitlab-runner gitlab/gitlab-runner -n gitlab-runner \
  -f ~/Documents/nairaflow-lab/runner-values.yaml
kubectl auth can-i create namespaces --as=system:serviceaccount:gitlab-runner:tofu-apply   # yes
kubectl auth can-i create pods --as=system:serviceaccount:gitlab-runner:tofu-apply         # no
```
- **What:** creates the `tofu-apply` ServiceAccount, allowed only to manage namespaces, quotas, limit ranges and network policies. The runner values add `service_account_overwrite_allowed` so tofu jobs can use it.
- **Why:** least privilege: a hacked pipeline can't do much.
- **Result:** namespaces = yes, pods = no.

### 3.4 First plan from the laptop (read-only practice)
```bash
export GITLAB_TOKEN=glpat-*** GITLAB_USER=Dcoder21 PROJECT_ID=<starter project ID>
export KUBE_CONFIG_PATH=~/.kube/config KUBE_CTX=kind-nairaflow
cd ~/Documents/nairaflow-starter/infra
./scripts/tofu-init.sh dev
cd envs/dev && tofu plan
```
- **What:** connects Tofu to state stored in GitLab, then shows what it **would** build.
- **Why:** you read the plan before anything changes; only the pipeline applies.
- **Result:** state lock acquired; namespace, quota, limit range, network policy to be created. Screenshot: `screenshots/day3-01-first-tofu-plan.png`

### 3.5 Lock provider versions for Mac and Linux
```bash
cd ~/Documents/nairaflow-starter/infra
for e in shared dev staging prod; do
  (cd envs/$e && tofu init -backend=false -input=false >/dev/null && \
   tofu providers lock -platform=darwin_arm64 -platform=linux_arm64 -platform=linux_amd64)
done
```
- **Why:** the laptop and the CI runner use the exact same provider versions.

### 3.6 Ask a provider what it really accepts (when syntax is unclear)
```bash
mkdir -p /tmp/glschema && cd /tmp/glschema
# main.tf with only required_providers { gitlab = { source = "gitlabhq/gitlab" } }
tofu init -input=false >/dev/null
tofu providers schema -json | jq '... gitlab_branch_protection ...'
```
- **Why:** documentation online and AI suggestions can be out of date; the schema is the truth for your version.
- **Result:** GitLab provider v19.5.0 wants `allowed_to_push = [{ access_level = "no one" }]`.

---

## Day 4 — The pipeline builds the infrastructure

### 4.1 Branch, commit, merge request
```bash
cd ~/Documents/nairaflow-starter
git switch -c day4-infra                  # carries uncommitted work onto a new branch
git add .gitignore .gitlab-ci.yml docker-compose.yml docs/ infra/
git status                                # no .env, runner-values.yaml, kind.yaml, CLAUDE.md
gitleaks protect --staged
git commit -m "Day 3-4: infrastructure as code, pipeline, threat model, journal"
git fetch origin && git rebase origin/main
git push -u origin day4-infra
glab mr create --fill --yes
```
- **Why:** infrastructure changes go through the same review + pipeline as app code.

### 4.2 Make jobs run on OUR runner only (GitLab UI)
- Settings → CI/CD → Runners → **Instance** tab → turn **off** instance runners.
- Edit our runner (✏️) → tick **Run untagged jobs**.
- Turned off GitLab Duo auto-review (it needs GitLab's cloud runners).
- **Why:** shared cloud runners can't reach our on-prem cluster. Screenshots: `day4-01-gitlab-runners-settings.png`, `day4-02-duo-job-stuck.png`

### 4.3 Use the Apple Silicon helper image
```bash
# runner-values.yaml → [runners.kubernetes]
#   helper_image = "registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper:arm64-v19.5.3"
helm upgrade gitlab-runner gitlab/gitlab-runner -n gitlab-runner \
  -f ~/Documents/nairaflow-lab/runner-values.yaml
```
- **Why:** kind nodes on an M-series Mac are `arm64`; the runner had asked for the Intel helper.

### 4.4 Rerun a pipeline
```bash
git commit --allow-empty -m "Rerun pipeline" && git push
kubectl get pods -n gitlab-runner -w      # watch job pods come and go
```

### 4.5 Merge, then apply from `main` (GitLab UI)
- Merge the MR → newest `main` pipeline → **infra** child pipeline → ▶ `apply: [shared]`, `[dev]`, `[staging]`, `[prod]`.
- **Why:** plan on the MR, apply only after merge, only when a human clicks.
- **Result:** all 4 applies passed. Screenshot: `day4-04-apply-jobs-passed.png`

### 4.6 Verify
```bash
kubectl get ns --show-labels | grep nairaflow
kubectl get resourcequota,limitrange,networkpolicy -n nairaflow-prod
glab repo view nairaflow-group/nairaflow-config
```
- **Result:** `nairaflow-dev`, `-staging`, `-prod` Active with `owner=platform-team`, `cost-centre=payments`, `env=...`; prod quota `pods 0/50, cpu 0/4, memory 0/8Gi`; `default-limits` limit range; `allow-trusted-ingress` network policy. Screenshot: `day4-05-namespaces-verified.png`

---

## Screenshots index
| File | Shows |
| --- | --- |
| `screenshots/day3-01-first-tofu-plan.png` | First `tofu plan` from VS Code: state lock + resources to create |
| `screenshots/day4-01-gitlab-runners-settings.png` | Our project runner online in GitLab |
| `screenshots/day4-02-duo-job-stuck.png` | Duo AI job stuck after shared runners were switched off |
| `screenshots/day4-03-plan-jobs-failed.png` | Plan jobs failing (I/O error during package install) |
| `screenshots/day4-04-apply-jobs-passed.png` | Apply jobs passed on `main` |
| `screenshots/day4-05-namespaces-verified.png` | kubectl proof: namespaces, labels, quota, limits, network policy |
