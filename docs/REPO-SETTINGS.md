# Repository settings for maintainers

Settings that cannot live in the repository's files. Checked against the public repository on 2026-11-17.

| # | Setting | State | Why | How |
|---|---|---|---|---|
| 1 | Private vulnerability reporting | on | [SECURITY.md](../SECURITY.md) tells reporters to use it | `gh api -X PUT repos/OWNER/REPO/private-vulnerability-reporting` |
| 2 | Dependabot security updates | **off** | Security fixes arrive as PRs that pass CI | `gh api -X PUT repos/OWNER/REPO/vulnerability-alerts` then `gh api -X PUT repos/OWNER/REPO/automated-security-fixes` |
| 3 | Ruleset on `main` | **none** | Nobody publishes without a green CI; no force push, no deletion | See below |
| 4 | Secret scanning and push protection | on | | |
| 5 | Actions: default workflow permissions | check | Read-only by default; workflows ask for more | Settings, Actions, General |
| 6 | OpenSSF Best Practices badge | not registered | A public, reviewable checklist | Sign in at bestpractices.dev with GitHub and register the repository |
| 7 | Container package visibility | after the first release | Public so anyone can pull. **Irreversible** | Package settings, Danger Zone, Change visibility |
| 8 | Immutable releases | **off** | A published release and its tag cannot be changed afterwards | Settings, General, Releases |
| 9 | Renovate | **not installed** | Updates every pinned version by pull request and merges it when CI is green (`renovate.json`) | Install the Renovate app (github.com/apps/renovate) on this repository only |

## Ruleset for `main`

Create it with `gh api -X POST repos/OWNER/REPO/rulesets --input ruleset.json`, or paste it into the UI's import, and check the preview:

```json
{
  "name": "main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
      } },
    { "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [ { "context": "lint" }, { "context": "build" } ]
      } }
  ]
}
```

Every change goes through a pull request with a green CI, but no approving review is required: with one maintainer that would block every merge. OpenSSF Scorecard rewards a second human reviewer (its Code-Review and the higher tiers of Branch-Protection), so a project with a second maintainer should add a `pull_request` rule with one required approval.
