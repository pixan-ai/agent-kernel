# Contributing

## Principles

1. **Official components only.** Prefer a documented Claude Code setting, hook or plugin over new code.
2. **Smallest code that is safe.** A change that adds code says what it removes, or why nothing smaller works.
3. **Evidence over claims.** A security or behavior claim in the docs needs a label from [docs/FINDINGS.md](docs/FINDINGS.md): Lab, Docs, Code or Open.
4. **Surgical changes.** Touch only what the change requires.

## Foundations

- **Tests:** [Acceptance Pipeline Specification](https://github.com/unclebob/Acceptance-Pipeline-Specification) (Uncle Bob). A test exercises behavior and must be able to fail; CI never skips a test silently.
- **Execution:** [Karpathy guidelines](https://github.com/multica-ai/andrej-karpathy-skills): think before coding, simplicity first, surgical changes, goal-driven execution.
- **Current docs, not memory:** check Claude Code, Railway and Telegram behavior against current documentation (for agents: [Context7](https://context7.com)) before relying on it.

## Before you open a pull request

```bash
shellcheck bin/*.sh tests/*.sh
jq empty policy/managed-settings.json
hadolint Dockerfile
docker build -t agent-kernel .
bash tests/docs_test.sh
bash tests/workflows_test.sh
for t in start tools policy cron peer config backup sleep dream install unsent; do
  docker run --rm --user 0 --entrypoint bash -v "$PWD/tests:/tests:ro" agent-kernel "/tests/${t}_test.sh" || break
done
docker run --rm --network none --user 1001 --entrypoint bash -v "$PWD/tests:/tests:ro" agent-kernel /tests/media_test.sh
docker run --rm --user 1001 --entrypoint bash -v "$PWD/tests:/tests:ro" agent-kernel /tests/stack_test.sh   # downloads the optional stack
```

The tests that run inside the image start by emptying `/data`: run them only in a throwaway container as above, never with `docker exec` in a live agent, where they would delete its memory, settings and jobs.

A change to `bin/` comes with a test in `tests/` that runs the script and checks what it does (exit code, files, output). Break the value the test guards and make sure it turns red.

CI runs the same checks. Never commit `.env` or any real credential.

## Updates from Renovate

Renovate opens a pull request for every pinned version that moves and merges it itself once CI is green ([how updates work](docs/GETTING-STARTED.md#updates-and-how-to-go-back)). A Renovate pull request that stays red is a real finding: read the failing check before closing it or pinning the old version.

## The line budget

The scripts in `bin/` stay within 247 lines of code (comments and blank lines are not counted; `tests/docs_test.sh` checks it). A change that needs a line gives one back: first by removing what is no longer needed, not by joining statements until a line is hard to read.

## Commit messages

Imperative, one subject line, explain why in the body when it is not obvious.

A pull request's title becomes the commit on `main`, and hosts such as Railway show it to whoever runs an agent: say what changes for them ("Clearer error for a mistyped bot token"), not internal codes. Audit references (L7, A3…) go in the description and the CHANGELOG.
