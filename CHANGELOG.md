# Changelog

## 0.2.2 (Next)

- [#52](https://github.com/dblock/parallel_tests-ci/pull/52): Define the shared workflow's repeated setup steps once with YAML anchors - [@dblock](https://github.com/dblock).
- Your contribution here.

## 0.2.1 (2026/11/20)

- [#51](https://github.com/dblock/parallel_tests-ci/pull/51): Use the floating `ruby/setup-ruby@v1` tag in the shared workflow so newly released Ruby versions work without a new release - [@dblock](https://github.com/dblock).

## 0.2.0 (2026/11/20)

- [#17](https://github.com/dblock/parallel_tests-ci/pull/17): Remove the release environment approval gate while retaining the master-only restriction - [@dblock](https://github.com/dblock).
- [#18](https://github.com/dblock/parallel_tests-ci/pull/18): Add a RubyGems version badge to README - [@dblock](https://github.com/dblock).
- [#24](https://github.com/dblock/parallel_tests-ci/pull/24): Remove the second warm run from the Posebook demo - [@dblock](https://github.com/dblock).
- [#25](https://github.com/dblock/parallel_tests-ci/pull/25): Remove the second cold run from the Posebook demo - [@dblock](https://github.com/dblock).
- [#26](https://github.com/dblock/parallel_tests-ci/pull/26): Add a standalone GitHub Action that outputs RSpec shard assignments - [@dblock](https://github.com/dblock).
- [#27](https://github.com/dblock/parallel_tests-ci/pull/27): Shorten workflow input descriptions in the README - [@dblock](https://github.com/dblock).
- [#28](https://github.com/dblock/parallel_tests-ci/pull/28): Shorten the project guides and README demo - [@dblock](https://github.com/dblock).
- [#30](https://github.com/dblock/parallel_tests-ci/pull/30): Add automatic Minitest sharding and timing history. RSpec checks now include `Shard Tests` in their names; update any required checks when upgrading - [@dblock](https://github.com/dblock).
- [#31](https://github.com/dblock/parallel_tests-ci/pull/31): Separate framework runners from the shared sharding lifecycle - [@dblock](https://github.com/dblock).
- [#33](https://github.com/dblock/parallel_tests-ci/pull/33): Enable Minitest timing collection with a Gemfile require and detect the loaded framework by default - [@dblock](https://github.com/dblock).
- [#34](https://github.com/dblock/parallel_tests-ci/pull/34): Select automatic, file size, or runtime grouping in workflows and the standalone action - [@dblock](https://github.com/dblock).
- [#36](https://github.com/dblock/parallel_tests-ci/pull/36): Add a complete Minitest workflow example and keep release references current - [@dblock](https://github.com/dblock).
- [#38](https://github.com/dblock/parallel_tests-ci/pull/38): Replace `rspec-options` with framework-neutral `test-options` for RSpec and Minitest - [@dblock](https://github.com/dblock).
- [#40](https://github.com/dblock/parallel_tests-ci/pull/40): Separate installed-consumer checks by framework - [@dblock](https://github.com/dblock).
- [#41](https://github.com/dblock/parallel_tests-ci/pull/41): Name the synthetic RSpec fixture directory consistently with Minitest - [@dblock](https://github.com/dblock).
- [#42](https://github.com/dblock/parallel_tests-ci/pull/42): Separate RSpec runner integration checks from shared lifecycle specs - [@dblock](https://github.com/dblock).
- [#43](https://github.com/dblock/parallel_tests-ci/pull/43): Verify framework selection consistently for installed consumers - [@dblock](https://github.com/dblock).
- [#44](https://github.com/dblock/parallel_tests-ci/pull/44): Use the shared parallel_tests runner for framework-neutral file grouping - [@dblock](https://github.com/dblock).
- [#45](https://github.com/dblock/parallel_tests-ci/pull/45): Separate GitHub workflow specs and exercise both framework runners - [@dblock](https://github.com/dblock).
- [#46](https://github.com/dblock/parallel_tests-ci/pull/46): Organize framework-specific specs and fixtures around shared runner contracts - [@dblock](https://github.com/dblock).
- [#47](https://github.com/dblock/parallel_tests-ci/pull/47): Support Minitest in the standalone shard matrix action and align framework defaults and plans - [@dblock](https://github.com/dblock).
- [#48](https://github.com/dblock/parallel_tests-ci/pull/48): Pass standalone action inputs to Ruby as JSON and fix the upgrade heading - [@dblock](https://github.com/dblock).
- [#50](https://github.com/dblock/parallel_tests-ci/pull/50): Fix release validation against the prepared changelog and future README versions - [@dblock](https://github.com/dblock).

## 0.1.0 (2026/11/19)

- [#2](https://github.com/dblock/parallel_tests-ci/pull/2): Add runtime-balanced RSpec shards and automatic trusted timing history - [@dblock](https://github.com/dblock).
- [#4](https://github.com/dblock/parallel_tests-ci/pull/4): Add an editable cube logo and PNG - [@dblock](https://github.com/dblock).
- [#5](https://github.com/dblock/parallel_tests-ci/pull/5): Label workers with position and actual total - [@dblock](https://github.com/dblock).
- [#6](https://github.com/dblock/parallel_tests-ci/pull/6): Add namespaced worker-name templates - [@dblock](https://github.com/dblock).
- [#7](https://github.com/dblock/parallel_tests-ci/pull/7): Pass workflow inputs to Ruby as JSON - [@dblock](https://github.com/dblock).
- [#8](https://github.com/dblock/parallel_tests-ci/pull/8): Configure runners, execution, caching, checkout, and artifact retention - [@dblock](https://github.com/dblock).
- [#10](https://github.com/dblock/parallel_tests-ci/pull/10): Document versioned 0.1.0 usage and shorten all guides - [@dblock](https://github.com/dblock).
- [#11](https://github.com/dblock/parallel_tests-ci/pull/11): Simplify test setup and output assertions, isolate validation cases, and scope consumer environment variables - [@dblock](https://github.com/dblock).
- [#12](https://github.com/dblock/parallel_tests-ci/pull/12): Remove the automatic Danger review message and skip new comments for empty reports - [@dblock](https://github.com/dblock).
- [#13](https://github.com/dblock/parallel_tests-ci/pull/13): Refine the cube logo with consistent 3D perspective and Test badge greens - [@dblock](https://github.com/dblock).
- [#14](https://github.com/dblock/parallel_tests-ci/pull/14): Link Posebook demo runs with cold and warm timing results and a test execution chart - [@dblock](https://github.com/dblock).
- [#16](https://github.com/dblock/parallel_tests-ci/pull/16): Document approved release protections and first-publication setup, and validate the installed package before release - [@dblock](https://github.com/dblock).
