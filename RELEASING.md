# Releasing

## Prerequisites

The Rakefile uses [ruby-gem-release](https://github.com/dblock/ruby-gem-release) with `RubyConstant` and `Intridea` adapters.

Before dispatch, verify:

- Publication, tags/releases, authentication, trusted-publisher setup, and workflow dispatch each have explicit authorization.
- Dispatch is manual via `release.yml` on `master`. The `release` environment accepts only `master`, with no required reviewers or deployment approval.
- The target version is absent from RubyGems and its release tag does not exist.
- The version constant and Next changelog heading match.
- RubyGems Trusted Publishing points to `release.yml` in this repository and the reusable workflow in `dblock/ruby-gem-release`. For a first publication, follow the setup below.

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

Verify the saved publisher, then supply the numeric RubyGems account ID as `rubygems-owner` at dispatch. No API key is needed:

```sh
gh workflow run release.yml --repo github.com/dblock/parallel_tests-ci --ref master -f rubygems-owner=YOUR_ACCOUNT_ID
```

## Validation

Run `bundle exec rake spec lint package`; inspect the archive. The release workflow runs the same command against the prepared release. Test release-tool changes with isolated remotes and simulated publication, including failed pushes and recovery. Never use real registries or credentials in tests.

Released changelog headings use `## VERSION (YYYY/MM/DD)`, newest first. Keep an unpublished version unchanged; release tooling prepares the dated section and next development version.

## Publication and Recovery

The workflow validates the prepared tree, retains the exact gem and recovery context, publishes that artifact, pushes release refs, creates the GitHub Release, and prepares the next development version.

Verify registry version/archive integrity, matching remote tag/commit, GitHub Release, and next development state. If interrupted, inspect those states and the retained artifact, then complete only missing steps. Delayed registry visibility is not permission to republish. Never overwrite published versions or move release tags; do not put long-lived RubyGems keys in repository secrets.

## GitHub Marketplace

The root `action.yml` describes the standalone shard matrix action, not the reusable workflow. With separate authorization, follow [GitHub's Marketplace publishing instructions](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/publish-in-github-marketplace) for a release tag containing that file. The owner must accept the Marketplace Developer Agreement. The gem release workflow does not create a Marketplace listing.
