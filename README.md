# Parallel Tests CI

[![Test](https://github.com/dblock/parallel_tests-ci/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/parallel_tests-ci/actions/workflows/test.yml) [![Lint](https://github.com/dblock/parallel_tests-ci/actions/workflows/lint.yml/badge.svg)](https://github.com/dblock/parallel_tests-ci/actions/workflows/lint.yml) [![Package](https://github.com/dblock/parallel_tests-ci/actions/workflows/package.yml/badge.svg)](https://github.com/dblock/parallel_tests-ci/actions/workflows/package.yml) [![Coverage](https://coveralls.io/repos/github/dblock/parallel_tests-ci/badge.svg?branch=master)](https://coveralls.io/github/dblock/parallel_tests-ci?branch=master)

Shared GitHub Actions integration for timing-based CI sharding with [parallel_tests](https://github.com/grosser/parallel_tests).

**Status:** Scaffold only. Timing-history management and the consumer reusable workflow are not implemented or released.

## Installation

The gem has not been published. For contributor setup, see [Contributing](CONTRIBUTING.md#setup-and-validation).

## Usage

There is no consumer integration yet. The intended experience is to add the gem and reference one shared GitHub workflow, without manually running commands or managing timing logs. See [Design](DESIGN.md) for the agreed first-version scope.

## Contributing

See [Contributing](CONTRIBUTING.md), [Coding Guidance](AGENTS.md), [Design](DESIGN.md), [Changelog](CHANGELOG.md), and [Releasing](RELEASING.md).

## License

Distributed under the [MIT License](LICENSE.txt).
