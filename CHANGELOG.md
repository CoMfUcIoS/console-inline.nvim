# Changelog

All notable changes to this project will be documented in this file.

## [1.3.0](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v1.2.0...console-inline.nvim-v1.3.0) (2025-10-30)


### Features

* **network:** add inline network request logging ([8ce44b7](https://github.com/CoMfUcIoS/console-inline.nvim/commit/8ce44b7bf29bb2fadebc22e79f938419ce186ebb))
* **service:** capture runtime errors inline in Neovim ([2ed6cd5](https://github.com/CoMfUcIoS/console-inline.nvim/commit/2ed6cd52fbb8562a8929821e12e07db167b540ea))
* **ui:** add automatic hover popups for log entries ([2bca42f](https://github.com/CoMfUcIoS/console-inline.nvim/commit/2bca42fbee45b2649213053019e5b627f8d3bb60))


### Bug Fixes

* **config:** simplify hover option handling in setup ([7ed45e0](https://github.com/CoMfUcIoS/console-inline.nvim/commit/7ed45e07de97ee007df635868525e4adc09f106b))

## [1.2.0](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v1.1.1...console-inline.nvim-v1.2.0) (2025-10-30)


### Features

* surface console.time durations inline ([a830f1a](https://github.com/CoMfUcIoS/console-inline.nvim/commit/a830f1a44996e4a77b5794f4b5a99b01249e4d9d))
* **trace:** inline stack traces for console.trace ([74f204c](https://github.com/CoMfUcIoS/console-inline.nvim/commit/74f204ca3654fbfada9c3f683d5385f7414b3f7a))


### Documentation

* **readme:** add horizontal rule at end of file ([2df7fde](https://github.com/CoMfUcIoS/console-inline.nvim/commit/2df7fde670bbf613901332ed99621789bbd05d82))

## [1.1.1](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v1.1.0...console-inline.nvim-v1.1.1) (2025-10-30)


### Documentation

* **readme:** add Console Ninja inspiration note ([6ba0fe7](https://github.com/CoMfUcIoS/console-inline.nvim/commit/6ba0fe7eede12ee0f947f177c4f48fa1a5270df8))

## [1.1.0](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v1.0.0...console-inline.nvim-v1.1.0) (2025-10-29)


### Features

* add project filters for log rendering control ([fb220a2](https://github.com/CoMfUcIoS/console-inline.nvim/commit/fb220a244abfdac09b8487100bf01865ca40acac))
* **history:** add console output history and Telescope picker ([ba93f80](https://github.com/CoMfUcIoS/console-inline.nvim/commit/ba93f806bd2a6bb0603e7ce4c37b7d56faf9883f))
* **pattern_overrides:** add ignore_case support ([2a88f8c](https://github.com/CoMfUcIoS/console-inline.nvim/commit/2a88f8c67f27065acf2e556fce16a0b1d0de4b22))
* **render:** add pattern_overrides for log styling ([b571809](https://github.com/CoMfUcIoS/console-inline.nvim/commit/b571809f6ad2e07a7bb98a464702b7317a525b3a))


### Bug Fixes

* **render:** skip remote paths in render_message ([faf3120](https://github.com/CoMfUcIoS/console-inline.nvim/commit/faf312027cdd34b871059e9db77fe9a606d2868e))

## [1.0.0](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v0.7.1...console-inline.nvim-v1.0.0) (2025-10-29)


### ⚠ BREAKING CHANGES

* **render:** last_msg_by_buf_line now stores entry objects instead of plain text.

### Features

* add env toggles for dev-only activation ([34d1686](https://github.com/CoMfUcIoS/console-inline.nvim/commit/34d168661a3eab74f9a9aa9c9f9f02d068af369c))
* **commands:** add ConsoleInlinePopup for full payload view ([b619280](https://github.com/CoMfUcIoS/console-inline.nvim/commit/b619280e35c90ea78b64c70868b62420985df42d))
* **popup:** add customizable popup formatter option ([3fad159](https://github.com/CoMfUcIoS/console-inline.nvim/commit/3fad159a0527eb53fe3446e86f495bf672dd5cb8))
* **render:** show message repeat count and fix queue ([6486e5b](https://github.com/CoMfUcIoS/console-inline.nvim/commit/6486e5b5bb986f9d88c23a378e4440ef802e29c2))


### Bug Fixes

* improve code style and update service version ([a60c02b](https://github.com/CoMfUcIoS/console-inline.nvim/commit/a60c02bcf247d4580b6d35b659b38915dba45d87))


### Documentation

* **readme:** add popup screenshot for long payloads ([694f227](https://github.com/CoMfUcIoS/console-inline.nvim/commit/694f22728d5d1140f216f8b70ebecebd1bd40bac))

## [0.7.1](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v0.7.0...console-inline.nvim-v0.7.1) (2025-10-28)


### Bug Fixes

* **ci:** allow comfucios to trigger auto-merge workflow ([6ee344a](https://github.com/CoMfUcIoS/console-inline.nvim/commit/6ee344a87a34698fc9bea0c69f752e9a21c83527))


### Documentation

* update usage examples and release token config ([3e622e1](https://github.com/CoMfUcIoS/console-inline.nvim/commit/3e622e18330226f58a964774ccccf86088cd592c))

## [0.7.0](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v0.6.0...console-inline.nvim-v0.7.0) (2025-10-28)


### Features

* **docs:** add demo status warning in browser example ([0d3a945](https://github.com/CoMfUcIoS/console-inline.nvim/commit/0d3a94507ec793ce952220fca3b1bc527ff780db))

## [0.6.0](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v0.5.1...console-inline.nvim-v0.6.0) (2025-10-28)


### Features

* **ci:** add manual trigger to npm publish workflow ([53601f6](https://github.com/CoMfUcIoS/console-inline.nvim/commit/53601f675c065b1fb8fe60d1a00c41d4d178047f))

## [0.5.1](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v0.5.0...console-inline.nvim-v0.5.1) (2025-10-28)


### Documentation

* **readme:** add mermaid diagram for plugin flow ([9f549c7](https://github.com/CoMfUcIoS/console-inline.nvim/commit/9f549c7b8daf63aa0f3c2b811e096f0803d0f28d))

## [0.5.0](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v0.4.0...console-inline.nvim-v0.5.0) (2025-10-28)


### Features

* browser relay, screenshots, and doc updates ([ba2d563](https://github.com/CoMfUcIoS/console-inline.nvim/commit/ba2d5639842539ab36deb52981b31b10450a151c))


### Bug Fixes

* canonicalize file keys for queued messages ([5611782](https://github.com/CoMfUcIoS/console-inline.nvim/commit/5611782d622c6846ed4c8eb3e9f626325026e94f))
* **ci:** update tag filter for npm publish workflow ([2d5e14f](https://github.com/CoMfUcIoS/console-inline.nvim/commit/2d5e14fdffa992b68424c0096635e96a3c71d21c))


### Maintenance

* **config:** update service version and release settings ([2676013](https://github.com/CoMfUcIoS/console-inline.nvim/commit/2676013f5815ea6b39a82c49fca2b9b4fb5d8a2a))
* release main ([f750f4e](https://github.com/CoMfUcIoS/console-inline.nvim/commit/f750f4edadc22ccb66fdc8311e50dbedf9eb1f2a))
* release main ([0f3c19b](https://github.com/CoMfUcIoS/console-inline.nvim/commit/0f3c19b5fa827fab48b2acbb32fcd9a4c7bc8746))


### Documentation

* **readme:** add developer setup for pre-commit hooks ([323b9eb](https://github.com/CoMfUcIoS/console-inline.nvim/commit/323b9eb2ec78539552155dbd5784f3c3af4eacb5))

## [0.4.0](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v0.3.0...console-inline.nvim-v0.4.0) (2025-10-28)


### Features

* browser relay, screenshots, and doc updates ([ba2d563](https://github.com/CoMfUcIoS/console-inline.nvim/commit/ba2d5639842539ab36deb52981b31b10450a151c))
* **ci:** update npm publish workflow for service package ([b3c82a6](https://github.com/CoMfUcIoS/console-inline.nvim/commit/b3c82a6093dcf623535faddfc05809be1eea1825))


### Bug Fixes

* **ci:** update tag filter for npm publish workflow ([2d5e14f](https://github.com/CoMfUcIoS/console-inline.nvim/commit/2d5e14fdffa992b68424c0096635e96a3c71d21c))


### Maintenance

* release main ([0819858](https://github.com/CoMfUcIoS/console-inline.nvim/commit/0819858bec42d6991a9067002efd6fd0ebba5082))
* release main ([907e8fd](https://github.com/CoMfUcIoS/console-inline.nvim/commit/907e8fd0e927c655378557dde02a4d6c8932c2dc))


### Documentation

* **readme:** clarify usage and config for service ([cc43676](https://github.com/CoMfUcIoS/console-inline.nvim/commit/cc43676c4b14af2b627cc8ba599efd5ef6f9b6fd))

## [0.4.0](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v0.3.0...console-inline.nvim-v0.4.0) (2025-10-27)


### Features

* **ci:** update npm publish workflow for service package ([b3c82a6](https://github.com/CoMfUcIoS/console-inline.nvim/commit/b3c82a6093dcf623535faddfc05809be1eea1825))


### Documentation

* **readme:** clarify usage and config for service ([cc43676](https://github.com/CoMfUcIoS/console-inline.nvim/commit/cc43676c4b14af2b627cc8ba599efd5ef6f9b6fd))

## [0.3.0](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v0.2.0...console-inline.nvim-v0.3.0) (2025-10-27)


### Features

* migrate to service package and update usage docs ([6ce50eb](https://github.com/CoMfUcIoS/console-inline.nvim/commit/6ce50eb09f0677df517f1a4c0f45d55efc64798c))
* persist and restore logs across buffer reloads ([ce2299e](https://github.com/CoMfUcIoS/console-inline.nvim/commit/ce2299eab4b074c26404b9a2587bf213fc9c0fda))


### Documentation

* **readme:** add screenshot for console-inline usage ([439a04e](https://github.com/CoMfUcIoS/console-inline.nvim/commit/439a04eba01874290860bba2305e923bbf62b4f5))

## [0.2.0](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v0.1.0...console-inline.nvim-v0.2.0) (2025-10-27)


### Features

* **ci:** add auto merge and improve npm publish workflow ([dd52b59](https://github.com/CoMfUcIoS/console-inline.nvim/commit/dd52b594f05285ac983fe51e40b7b27c8a597c29))


### Maintenance

* **config:** add dependabot and update release-please ([aa63ff7](https://github.com/CoMfUcIoS/console-inline.nvim/commit/aa63ff7e12a783a85983e6a3a4346b25d7c43852))


### Documentation

* **readme:** add CI and Lint badges to README ([22a3ab9](https://github.com/CoMfUcIoS/console-inline.nvim/commit/22a3ab9f638b1752b105117a4fbb7b5402ec5de8))

## [Unreleased]

- Initial development

## [v0.1.0] - 2025-10-27

- First public release: zero-config inline console logs
