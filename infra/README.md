# nairaflow-infra

Infrastructure as Code for the NairaFlow lab (Project 1, days 3–5). Lives in `infra/` of the nairaflow-starter repo; its pipeline is `infra/.gitlab-ci.yml`, started by the root pipeline when `infra/` changes.

| Folder | What it holds |
| --- | --- |
| `modules/namespace` | Namespace + labels, quota, default limits, network policy |
| `modules/gitlab-repo` | Private GitLab repo with a protected `main` |
| `envs/shared` | GitLab repos (e.g. `nairaflow-config`) and the day 5 import drill |
| `envs/dev`, `envs/staging`, `envs/prod` | One namespace per environment, one state each |
| `policy/` | Rego guardrails + tests (Conftest) |
| `bootstrap/` | One-time RBAC for the pipeline |

Rules: never run `tofu apply` from a laptop. Changes go through a merge request; the pipeline plans, checks policy, and applies after merge.

Lock file tip: after the first `tofu init`, run
`tofu providers lock -platform=darwin_arm64 -platform=linux_arm64 -platform=linux_amd64`
in each env folder and commit `.terraform.lock.hcl`, so your Mac and the CI runner agree.
