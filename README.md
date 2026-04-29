# bundlegames-ci-actions

Reusable GitHub Composite Actions shared across BundleGames repos. One place to own supply-chain policy (SHA-pinned third-party actions, toolchain versions, permissions), one place to upgrade.

## Destined for its own repo

Today this lives under `shared/packages/` for convenience. The intent is for each folder under `actions/` to be consumable as `uses: Rotten-Games/bundlegames-ci-actions/<name>@<sha-or-tag>` from any repo. When you push this to its own GitHub repo, consumer workflows reference it by path.

## Available actions

| Action | What it does |
|---|---|
| `actions/mvnw-verify` | Checkout, setup Temurin JDK, cache Maven, run `./mvnw -B verify` with configurable test group. Used by every JVM backend CI. |
| `actions/package-tag-release` | On tag push to a multi-package Unity UPM repo, validate the tagged package's `package.json` version matches the tag suffix. Catches drift. |
| `actions/unity-edit-mode-tests` | Runs `game-ci/unity-test-runner`. Gated on `UNITY_LICENSE` / `UNITY_EMAIL` / `UNITY_PASSWORD` secrets being present; no-op when they aren't (so the workflow can stay enabled before licensing). |
| `actions/docker-build-ecr` | Build, tag with git SHA, push to AWS ECR via OIDC. |
| `actions/aws-ecs-deploy` | Force a fresh rollout of an ECS service (`update-service --force-new-deployment`) via OIDC. Pairs with `docker-build-ecr`. Optional `wait-for-stable` blocks until the service reaches steady state. |
| `actions/pre-commit-check` | Run `pre-commit run --all-files` with a standardized hook set. |
| `actions/trivy-scan` | Trivy fs/image vulnerability scan with DB caching, public ECR mirror, optional SARIF upload to GitHub Code Scanning. One pin to bump fleet-wide. |

## Conventions

- **Pin everything.** Every `uses:` inside these composites uses a full-length SHA. Dependabot keeps them fresh via `.github/dependabot.yml`.
- **Minimal inputs.** Each action takes the smallest set of inputs consumers actually need to vary. Defaults match the BundleGames toolchain (Java 25 Temurin, Maven 3.9+, etc.).
- **Narrow permissions.** `permissions: contents: read` unless explicitly documented otherwise.
- **Editor licensing explicit.** `unity-edit-mode-tests` refuses to run without `UNITY_LICENSE`; consumers can keep the workflow enabled but the job skips with a clean message until licensing lands.

## Consumer examples

### CI

```yaml
# .github/workflows/ci.yml in a JVM backend repo
name: ci
on: [push, pull_request]
jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: Rotten-Games/bundlegames-ci-actions/actions/mvnw-verify@v1
        with:
          test-group: unit
  integration:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: Rotten-Games/bundlegames-ci-actions/actions/mvnw-verify@v1
        with:
          test-group: integration
```

### Production deploy (build + rollout)

```yaml
# .github/workflows/prod.yml — manually triggered ECS rollout
name: prod-deploy
on: { workflow_dispatch: {} }

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-24.04
    environment: production
    steps:
      - uses: Rotten-Games/bundlegames-ci-actions/actions/docker-build-ecr@v1
        with:
          aws-region: ${{ secrets.AWS_REGION }}
          aws-role-arn: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          ecr-repository: ${{ secrets.ECR_REPOSITORY }}
          additional-tags: latest

      - uses: Rotten-Games/bundlegames-ci-actions/actions/aws-ecs-deploy@v1
        with:
          aws-region: ${{ secrets.AWS_REGION }}
          aws-role-arn: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          ecs-cluster: ${{ secrets.ECS_CLUSTER }}
          ecs-service: ${{ secrets.ECS_SERVICE }}
          wait-for-stable: "true"
```

## Versioning

- Minor or breaking changes to any action → new tag `v1`, `v2`, …
- Bug fixes that don't change the input/output contract → retag the current major in place (same policy as our Unity packages).
- Consumers pin to `@v1` (moves with fixes) or `@<sha>` (locked).

## Supply-chain notes

- `.github/dependabot.yml` keeps pinned `uses:` SHAs current.
- `.github/workflows/self-lint.yml` runs `actionlint` + `shellcheck` on every PR.
- Never add a new third-party `uses:` without a Dependabot entry for it.
