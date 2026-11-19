<img src="assets/logo.svg" alt="A solid green cube beside eight outlined cubes in perspective" width="160">

# Parallel Tests CI

[![Gem Version](https://img.shields.io/gem/v/parallel_tests-ci.svg)](https://rubygems.org/gems/parallel_tests-ci) [![Test](https://github.com/dblock/parallel_tests-ci/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/parallel_tests-ci/actions/workflows/test.yml) [![Lint](https://github.com/dblock/parallel_tests-ci/actions/workflows/lint.yml/badge.svg)](https://github.com/dblock/parallel_tests-ci/actions/workflows/lint.yml) [![Package](https://github.com/dblock/parallel_tests-ci/actions/workflows/package.yml/badge.svg)](https://github.com/dblock/parallel_tests-ci/actions/workflows/package.yml) [![Coverage](https://coveralls.io/repos/github/dblock/parallel_tests-ci/badge.svg?branch=master)](https://coveralls.io/github/dblock/parallel_tests-ci?branch=master)

Runtime-balanced RSpec shards for GitHub Actions, powered by [parallel_tests](https://github.com/grosser/parallel_tests). Timing history is collected and reused automatically.

## Installation

Requires Ruby 3.3+ and RSpec. Add to your Gemfile and run `bundle install`:

```ruby
gem 'parallel_tests-ci', '0.1.0', require: false
```

## Usage

Add `.github/workflows/test.yml`:

```yaml
name: Test
on: [push, pull_request]

permissions:
  contents: read
  actions: read

jobs:
  test:
    name: Test
    uses: dblock/parallel_tests-ci/.github/workflows/rspec.yml@v0.1.0
    with:
      shards: 8
```

Ruby comes from your version file; workers use Ubuntu by default. The first run groups by file size. Successful default-branch pushes supply timings for later runs; PRs read them without updating history. Jobs appear as `Test / 1 of 8`, capped at matching file count. Keep gem and workflow versions matched.

## Configuration

### Runners and Execution

| Input             | Default         | Purpose                                                                       |
| ---               | ---             | ---                                                                           |
| `runs-on`         | `ubuntu-latest` | Runner label or JSON label array for all jobs; Linux and macOS supported.     |
| `timeout-minutes` | `360`           | Minutes per job, including setup; positive integer, subject to runner limits. |
| `max-parallel`    | `256`           | Concurrent workers (1-256), subject to runner availability.                   |
| `fail-fast`       | `false`         | Cancel other workers when a worker fails.                                     |
| `fetch-depth`     | `1`             | Checkout history depth in all jobs; `0` fetches all history and tags.         |
| `ruby-version`    | Empty           | Override the caller's Ruby version file.                                      |
| `bundler-cache`   | `true`          | Cache gems in all jobs; `false` still installs gems.                          |

### Suite and Setup

| Input           | Default                           | Purpose                                          |
| ---             | ---                               | ---                                              |
| `shards`        | `4`                               | Workers (1-256), capped at matching file count.  |
| `worker-name`   | `{shard.number} of {shard.count}` | Worker label template; empty uses the default.   |
| `pattern`       | `spec/**/*_spec.rb`               | Repository-relative spec glob.                   |
| `rspec-options` | `[]`                              | JSON array of RSpec arguments.                   |
| `environment`   | `{}`                              | JSON object of non-secret environment variables. |
| `before-bundle` | Empty                             | Shell setup before gems in every job.            |
| `setup`         | Empty                             | Shell setup before specs in each worker.         |

### Artifacts

| Input                     | Default             | Purpose                                                                              |
| ---                       | ---                 | ---                                                                                  |
| `artifacts`               | Empty               | Extra files to retain, including hidden files and failure diagnostics.               |
| `artifact-prefix`         | `parallel-tests-ci` | Unique per call; letters, numbers, underscores, and hyphens only.                    |
| `artifact-retention-days` | `30`                | Days to retain plans, measurements, and test artifacts; `0` uses repository default. |
| `baseline-retention-days` | `90`                | Days to retain trusted history; `0` uses repository default.                         |

See [Workflow Inputs](DESIGN.md#workflow-inputs) for templates, secret environments, and setup rules, and [Plans and Retries](DESIGN.md#plans-and-retries) for rerun behavior.

## Demo

[Posebook](https://github.com/dblock/posebook), a custom Rails CMS, runs 1,142 examples across eight workers. Times below are reported by RSpec and exclude setup and spec loading.

<img src="assets/demo.svg" alt="Slowest worker RSpec time: serial 395s, custom sharding 61.62s, parallel_tests alone 70.71s, parallel_tests-ci cold runs 79.11s and 79.03s, warm runs 57.59s and 62.90s" width="480">

- [Single-worker run](https://github.com/dblock/posebook/actions/runs/44218105420): No parallel tests; 395s.
- [#178](https://github.com/dblock/posebook/pull/178): Introduce custom sharding, no `parallel_tests`; slowest worker 61.62s.
- [#181](https://github.com/dblock/posebook/pull/181): `parallel_tests` alone, without `parallel_tests-ci`; slowest worker 70.71s.
- [#185](https://github.com/dblock/posebook/pull/185): Initial cold run; slowest worker 79.11s.
- [#186](https://github.com/dblock/posebook/pull/186): Repeat cold run, identical assignments; slowest worker 79.03s.
- [#187](https://github.com/dblock/posebook/pull/187): Warm history redistributed 85/95 files; slowest successful worker 57.59s.
- [#188](https://github.com/dblock/posebook/pull/188): Same warm assignments; slowest worker 62.90s.

## Contributing

See [Contributing](CONTRIBUTING.md), [Coding Guidance](AGENTS.md), [Design](DESIGN.md), [Changelog](CHANGELOG.md), and [Releasing](RELEASING.md).

## License

Distributed under the [MIT License](LICENSE.txt).
