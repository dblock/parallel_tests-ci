<img src="assets/logo.svg" alt="A solid blue cube beside eight outlined cubes" width="160">

# Parallel Tests CI

[![Test](https://github.com/dblock/parallel_tests-ci/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/parallel_tests-ci/actions/workflows/test.yml) [![Lint](https://github.com/dblock/parallel_tests-ci/actions/workflows/lint.yml/badge.svg)](https://github.com/dblock/parallel_tests-ci/actions/workflows/lint.yml) [![Package](https://github.com/dblock/parallel_tests-ci/actions/workflows/package.yml/badge.svg)](https://github.com/dblock/parallel_tests-ci/actions/workflows/package.yml) [![Coverage](https://coveralls.io/repos/github/dblock/parallel_tests-ci/badge.svg?branch=master)](https://coveralls.io/github/dblock/parallel_tests-ci?branch=master)

Shared GitHub Actions integration for timing-based CI sharding with [parallel_tests](https://github.com/grosser/parallel_tests).

Automatically restore timing history, generate a shard matrix, measure each run, and publish the next trusted baseline. No timing commands, report files, tokens, or hosted service to manage.

## Installation

For an existing RSpec project using Ruby 3.3 or newer, add the gem to your Gemfile and update your lockfile normally. This version is not yet published to RubyGems; use the development source:

```ruby
gem 'parallel_tests-ci', github: 'dblock/parallel_tests-ci', branch: 'master', require: false
```

## Usage

Add the shared workflow to your CI:

```yaml
name: Test
on: [push, pull_request]

permissions:
  contents: read
  actions: read

jobs:
  test:
    name: Test
    uses: dblock/parallel_tests-ci/.github/workflows/rspec.yml@master
    with:
      shards: 8 # Number of test shards (1-256), capped at the number of matching spec files.
```

Ruby comes from your version file by default. Each shard runs on its own Ubuntu runner. The first run uses file sizes; successful default-branch pushes establish timings automatically, and PRs, including forks, read that history without updating it. Use matching gem/workflow refs; these development refs should be pinned to matching releases when available.

Worker jobs appear as `Test / 1 of 8`, `Test / 2 of 8`, and so on. GitHub supplies the caller job's name as the prefix; the total reflects the actual shard count, capped at the number of matching spec files.

## Configuration

| Input             | Default                           | Purpose                                                                                     |
| ---               | ---                               | ---                                                                                         |
| `ruby-version`    | Empty                             | Use the caller's version file unless overridden.                                            |
| `shards`          | `4`                               | Workers (1-256), capped at matching file count.                                             |
| `worker-name`     | `{shard.number} of {shard.count}` | Worker label template; empty uses the default.                                              |
| `pattern`         | `spec/**/*_spec.rb`               | Spec-file glob, relative to the repository.                                                 |
| `rspec-options`   | `[]`                              | JSON array of RSpec arguments.                                                              |
| `environment`     | `{}`                              | JSON object of non-secret environment variables.                                            |
| `before-bundle`   | Empty                             | Shell setup before gems in every job.                                                       |
| `setup`           | Empty                             | Shell setup before specs in each worker.                                                    |
| `artifacts`       | Empty                             | Extra files to retain, including hidden files and failure diagnostics.                      |
| `artifact-prefix` | `parallel-tests-ci`               | Unique artifact prefix for multiple calls; letters, numbers, underscores, and hyphens only. |

For example, `worker-name: 'RSpec {shard.number}/{shard.count} ({plan.group_by})'` produces `Test / RSpec 1/8 (runtime)`.

See [Workflow Inputs](DESIGN.md#workflow-inputs) for template variables, secret environments, setup rules, and retries.

## Contributing

See [Contributing](CONTRIBUTING.md), [Coding Guidance](AGENTS.md), [Design](DESIGN.md), [Changelog](CHANGELOG.md), and [Releasing](RELEASING.md).

## License

Distributed under the [MIT License](LICENSE.txt).
