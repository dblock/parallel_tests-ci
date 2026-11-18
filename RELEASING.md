# Releasing

## Status and Authorization

Release tooling is provisional. Version `0.1.0` is unreleased, RubyGems Trusted Publishing is not configured, and no release environment has been authorized. Implementation and documentation do not authorize publication.

The Rakefile uses [ruby-gem-release](https://github.com/dblock/ruby-gem-release) 0.6 with its `RubyConstant` version adapter and `Intridea` changelog adapter. `.github/workflows/release.yml` references the matching `v0.6.0` reusable workflow and is manual-only. These files document and prepare the intended flow; they do not authorize credentials, environment setup, trusted publishing, tags/releases, or dispatch.

## Validation

Before any authorized release, verify registry state and ensure the version has not already been published. Keep an unpublished version unchanged. The version constant in `lib/parallel_tests/ci/version.rb` and the Next heading in `CHANGELOG.md` must match. Use `## VERSION (YYYY/MM/DD)` for released sections, newest release first, and append attributed contributions above the final dash-style placeholder.

Run `bundle exec rake`, `bundle exec rake package`, and inspect the built archive. Validate release-tool changes using isolated remotes and simulated publication rather than a real registry. Verify release preparation, failed remote pushes, retries, and recovery without overwriting existing tags or versions.

## Future Trusted-Publishing Setup

With separate explicit authorization, configure a `release` environment restricted to the default branch, maintainer approval, and RubyGems Trusted Publishing for the actual caller repository and `release.yml`. The RubyGems configuration must also identify the reusable workflow repository `dblock/ruby-gem-release`. First publication uses a pending trusted publisher and the authorized RubyGems owner ID. Do not request tokens or authentication codes in chat, or store long-lived RubyGems API keys in repository secrets.

The current branch rules require PRs and block force pushes and deletion with no bypass actors. The standard release flow needs direct release and next-development commits on `master`; it is not ready to run under these rules. An explicitly authorized release-setup change must remove the PR requirement while retaining active force-push/deletion protections and no bypass actors. That change permits ordinary fast-forward pushes by every writer, not only release automation; ordinary development must still use PRs. Verify effective rules and update this guide, AGENTS, and Contributing when the setup is actually authorized.

## Authorized Publication and Recovery

After authorization and setup, use the standard manually dispatched workflow on the default branch. Its intended sequence validates and prepares the version/changelog, tests the prepared tree, preserves the exact gem and recovery context, publishes that artifact, pushes matching release refs, creates the GitHub Release, and prepares/pushes the next development version. Preserve the reusable workflow's artifact verification and recovery behavior.

Confirm registry version and archive integrity, matching remote tag/commit, GitHub Release, and next development state. Publication and delayed registry visibility are different outcomes: investigate before retrying and never republish an existing version or move an existing release tag. Recover by inspecting the registry, refs, and retained exact artifact, then completing only missing steps. Report verification limits plainly.
