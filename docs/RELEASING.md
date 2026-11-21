# Releasing

A release is a tag. Pushing a `v*` tag runs [`.github/workflows/release.yml`](../.github/workflows/release.yml): it first proves the release path against a throwaway registry, then publishes `ghcr.io/<owner>/<repo>:<version>` with an SBOM, SLSA provenance, a keyless cosign signature and a GitHub attestation, and verifies all of them. The image is pushed by digest, with no tag; the version tags (`X.Y.Z` and `X.Y`) are added last, on that same digest, only once it has passed the checks (no Claude Code, no fixable critical vulnerability) and is signed and verified. A release that fails on the way leaves an untagged digest that nobody pulls by version. Nothing is published by a merge or a pull request.

> **Publishing has a switch.** The workflow builds and publishes only the `base` target: no Claude Code, no plugin ([PRODUCT-IMAGE.md](PRODUCT-IMAGE.md)); its acceptance job fails if `base` contains either. The publish job runs only when the repository variable `PUBLISH_IMAGE` is `true` (it is, since 2026-11-19, with Docker Hub as `pixan/agent-kernel`); set to anything else, a tag runs the acceptance job against a throwaway registry and publishes nothing.

## Docker Hub too (optional)

The same image, same digest, is also pushed to Docker Hub and signed there when these are set in the repository's **Settings → Secrets and variables → Actions**:

1. On Docker Hub, create a public repository, for example `NAMESPACE/agent-kernel`, and a personal access token with **Read & Write** on it.
2. Variable `DOCKERHUB_REPOSITORY` = `NAMESPACE/agent-kernel`.
3. Secrets `DOCKERHUB_USERNAME` (the Docker Hub user) and `DOCKERHUB_TOKEN` (that token, pasted only there).

Without the variable, only `ghcr.io` gets the image. GitHub's attestation is stored next to the `ghcr.io` copy; the cosign signature is on both, so `cosign verify docker.io/NAMESPACE/agent-kernel:1.1.0` with the same two flags as below works too.

## Cut a release

1. In a pull request, move "Unreleased" in [CHANGELOG.md](../CHANGELOG.md) under the new version.
2. Tag the merge commit and push the tag:

   ```bash
   git tag -s v1.1.0 -m "v1.1.0"   # use -a if you do not sign tags
   git push origin v1.1.0
   ```

   Or, without a terminal: **Releases → Draft a new release**, a new tag `v1.1.0` on `main`, title `v1.1.0`, label **Latest**, **Publish release** (how 1.0.0 and 1.1.0 were made; a tag made this way is not signed). The repository's releases are immutable: once published, the tag cannot change.

3. Watch the workflow. Without `PUBLISH_IMAGE` only the acceptance job runs; the publish job shows as skipped. A new package is **private** at first: after the first publish, make it public in the package settings (irreversible) and check it is linked to the repository.
4. Run the verification below once from a machine that has no trust in the workflow.

## Verify an image

```bash
cosign verify ghcr.io/OWNER/REPO:1.1.0 \
  --certificate-identity-regexp '^https://github.com/OWNER/REPO/\.github/workflows/release\.yml@refs/tags/v.+$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/OWNER/REPO:1.1.0 --repo OWNER/REPO
docker buildx imagetools inspect ghcr.io/OWNER/REPO:1.1.0 --format '{{json .SBOM}}'
```

In production, pin the image by digest (`ghcr.io/OWNER/REPO@sha256:...`).

## Notes

- The publish job builds again, so it does not trust the earlier checks: before signing, it checks the digest it pushed (no Claude Code, no fixable CRITICAL vulnerability). If either fails the job stops, and the pushed digest stays unsigned: it is not a release, and the verification below rejects it.
- Signatures and attestations are written to a public transparency log, so the workflow's identity is public. The repository is public.
- Do not create a GitHub Release by hand without signed assets: OpenSSF Scorecard's Signed-Releases check scores an unsigned release 0, and no release at all as not applicable.
- The acceptance job signs with a throwaway key and skips the transparency log, so it can run on every pull request. What only a tag exercises is the keyless identity and the attestation; the last step of the publish job verifies both.
