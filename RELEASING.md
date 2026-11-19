# Releasing

## Prerequisites

Publication, tags/releases, authentication, trusted-publisher setup, and workflow dispatch each require explicit authorization.

The Rakefile uses [ruby-gem-release](https://github.com/dblock/ruby-gem-release) with `RubyConstant` and `Intridea` adapters; `.github/workflows/release.yml` is manual-only and restricted to `master`.

Before dispatch, verify:

- The target version is absent from RubyGems and its release tag does not exist.
- The version constant and Next changelog heading match.
- The `release` environment accepts only the `master` branch, with no required reviewers or deployment approval gate.
- RubyGems Trusted Publishing identifies this repository's `release.yml` and reusable-workflow repository `dblock/ruby-gem-release`. First publication needs a pending publisher and authorized `rubygems-owner` account ID.

The approved branch rules permit fast-forward pushes by all writers, not just automation, while blocking force pushes and branch deletion with no bypass actors. Authorized release automation pushes release metadata and the next development version directly to `master`; ordinary development still uses PRs.

### First Publication

Create a [pending trusted publisher](https://rubygems.org/profile/oidc/pending_trusted_publishers) in the intended RubyGems account:

| Field                     | Value               |
| ---                       | ---                 |
| Gem                       | `parallel_tests-ci` |
| Repository Owner          | `dblock`            |
| Repository Name           | `parallel_tests-ci` |
| Workflow Filename         | `release.yml`       |
| Environment               | `release`           |
| Workflow Repository Owner | `dblock`            |
| Workflow Repository Name  | `ruby-gem-release`  |

Verify the saved publisher, then supply the numeric RubyGems account ID from that page as `rubygems-owner`. No API key is needed. After explicit publication and dispatch authorization:

```sh
gh workflow run release.yml --repo github.com/dblock/parallel_tests-ci --ref master -f rubygems-owner=YOUR_ACCOUNT_ID
```

An authorized dispatch proceeds without a separate environment approval. Setup alone does not dispatch or publish.

## Validation

Run `bundle exec rake spec lint package`; inspect the archive. The release workflow runs the same command against the prepared release. Test release-tool changes with isolated remotes and simulated publication, including failed pushes and recovery. Never use real registries or credentials in tests.

Released changelog headings use `## VERSION (YYYY/MM/DD)`, newest first. Keep an unpublished version unchanged; release tooling prepares the dated section and next development version.

## Publication and Recovery

Dispatch `release.yml` on `master` only after authorization and setup. It validates the prepared tree, retains the exact gem/recovery context, publishes that artifact, pushes release refs, creates the GitHub Release, and prepares the next development version.

Verify registry version/archive integrity, matching remote tag/commit, GitHub Release, and next development state. If interrupted, inspect those states and the retained artifact, then complete only missing steps. Delayed registry visibility is not permission to republish. Never overwrite published versions or move release tags; do not put long-lived RubyGems keys in repository secrets.
