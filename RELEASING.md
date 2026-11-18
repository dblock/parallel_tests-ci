# Releasing

## Prerequisites

Publication, tags/releases, authentication, trusted-publisher setup, and workflow dispatch each require explicit authorization.

The Rakefile uses [ruby-gem-release](https://github.com/dblock/ruby-gem-release) with `RubyConstant` and `Intridea` adapters; `.github/workflows/release.yml` is manual-only and restricted to `master`.

Before dispatch, verify:

- The target version is absent from RubyGems and its release tag does not exist.
- The version constant and Next changelog heading match.
- The `release` environment requires maintainer approval and is restricted to the default branch.
- RubyGems Trusted Publishing identifies this repository's `release.yml` and reusable-workflow repository `dblock/ruby-gem-release`. First publication needs a pending publisher and authorized `rubygems-owner` account ID.

Current PR-only branch rules block the automation's direct release-metadata pushes. Changing them requires separate approval; permitting fast-forward pushes affects every writer, not just automation. Retain force-push/deletion protections and ordinary development PRs.

## Validation

Run `bundle exec rake` and `bundle exec rake package`; inspect the archive. Test release-tool changes with isolated remotes and simulated publication, including failed pushes and recovery. Never use real registries or credentials in tests.

Released changelog headings use `## VERSION (YYYY/MM/DD)`, newest first. Keep an unpublished version unchanged; release tooling prepares the dated section and next development version.

## Publication and Recovery

Dispatch `release.yml` on `master` only after authorization and setup. It validates the prepared tree, retains the exact gem/recovery context, publishes that artifact, pushes release refs, creates the GitHub Release, and prepares the next development version.

Verify registry version/archive integrity, matching remote tag/commit, GitHub Release, and next development state. If interrupted, inspect those states and the retained artifact, then complete only missing steps. Delayed registry visibility is not permission to republish. Never overwrite published versions or move release tags; do not put long-lived RubyGems keys in repository secrets.
