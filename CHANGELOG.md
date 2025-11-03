# Changelog

All notable changes to this project will be documented in this file.

## [2.1.0](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v2.0.0...console-inline.nvim-v2.1.0) (2025-11-03)


### Features

* add advanced placement and source map features ([47cb28b](https://github.com/CoMfUcIoS/console-inline.nvim/commit/47cb28beab05dba72ce4065dde0c5d4c2f80c7bf))
* add mapping_status when source maps are disabled ([94659c0](https://github.com/CoMfUcIoS/console-inline.nvim/commit/94659c06e8357fa496bf1235ddf4adf95da76e0b))
* **config:** add advanced opts to README example ([8da73bd](https://github.com/CoMfUcIoS/console-inline.nvim/commit/8da73bd59c23aa8493cd5511f50b62c2c3a2f36a))
* **index:** add reindex command and workspace deps ([d6b185e](https://github.com/CoMfUcIoS/console-inline.nvim/commit/d6b185e3de1b5b7ea02711f7293de5d226217cef))
* **index:** add reindex function for buffer rebuild ([36e5883](https://github.com/CoMfUcIoS/console-inline.nvim/commit/36e58838b48088e373a15fee518faaaa5b253607))


### Bug Fixes

* **render:** improve console method detection logic ([c187813](https://github.com/CoMfUcIoS/console-inline.nvim/commit/c1878130b5aaa02b9db5d40ffbbaf6b1d8397983))

## [2.0.0](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v1.3.1...console-inline.nvim-v2.0.0) (2025-10-30)


### ⚠ BREAKING CHANGES

* **render:** last_msg_by_buf_line now stores entry objects instead of plain text.

### Features

* add env toggles for dev-only activation ([38f1663](https://github.com/CoMfUcIoS/console-inline.nvim/commit/38f1663a54e0d8d538309b973e70f588b57216f2))
* add project filters for log rendering control ([93f3d0a](https://github.com/CoMfUcIoS/console-inline.nvim/commit/93f3d0a3575cce82bae312ecdba77164f345dd1e))
* browser relay, screenshots, and doc updates ([c7168b9](https://github.com/CoMfUcIoS/console-inline.nvim/commit/c7168b9e2406b9c40e7103e06243c7b5d18951b4))
* **ci:** add auto merge and improve npm publish workflow ([ee9ddf2](https://github.com/CoMfUcIoS/console-inline.nvim/commit/ee9ddf2ac29e7c131432a1078b89602d53cbae84))
* **ci:** add manual trigger to npm publish workflow ([678a725](https://github.com/CoMfUcIoS/console-inline.nvim/commit/678a725aef51bb36ab573383d08682de7dc482f2))
* **ci:** update npm publish workflow for service package ([78e1bbd](https://github.com/CoMfUcIoS/console-inline.nvim/commit/78e1bbdddfb3ca85a555cb568b15976bb36971b4))
* **commands:** add ConsoleInlinePopup for full payload view ([37742e3](https://github.com/CoMfUcIoS/console-inline.nvim/commit/37742e358c4511519b6246151266969fdec58210))
* **docs:** add demo status warning in browser example ([f3180a5](https://github.com/CoMfUcIoS/console-inline.nvim/commit/f3180a56b54a5dec69a3476f0635b5679bbfb821))
* **history:** add console output history and Telescope picker ([55f9617](https://github.com/CoMfUcIoS/console-inline.nvim/commit/55f961714a863a9763f46bb12409832f90f39e4c))
* migrate to service package and update usage docs ([4280ece](https://github.com/CoMfUcIoS/console-inline.nvim/commit/4280ece8a53876a628a4fee207b14fcec0fdaf5a))
* **network:** add inline network request logging ([57fb277](https://github.com/CoMfUcIoS/console-inline.nvim/commit/57fb27798d90a1e735aefb3e7c7a12d5d546a40b))
* **pattern_overrides:** add ignore_case support ([b939afa](https://github.com/CoMfUcIoS/console-inline.nvim/commit/b939afafdcdb2f86b43787bd5d33f2d688c45c79))
* persist and restore logs across buffer reloads ([ca23506](https://github.com/CoMfUcIoS/console-inline.nvim/commit/ca23506bfb29126b43b3239c46dca275ca8df00e))
* **popup:** add customizable popup formatter option ([3cc0a0d](https://github.com/CoMfUcIoS/console-inline.nvim/commit/3cc0a0da2fecc4f5a19af872f75cb2d79e139e45))
* **render:** add pattern_overrides for log styling ([da3a3a2](https://github.com/CoMfUcIoS/console-inline.nvim/commit/da3a3a22011580d24593da85ef9be7b053c4dc80))
* **render:** show message repeat count and fix queue ([87d1a3d](https://github.com/CoMfUcIoS/console-inline.nvim/commit/87d1a3dbc9304562de984f7621bf0b384b62dad9))
* **service:** capture runtime errors inline in Neovim ([44d7759](https://github.com/CoMfUcIoS/console-inline.nvim/commit/44d7759984f6b82a403a38f5c4897b66dfbc7e3f))
* surface console.time durations inline ([5469b9d](https://github.com/CoMfUcIoS/console-inline.nvim/commit/5469b9d108f44c286636872b07d27b749cb055e8))
* **trace:** inline stack traces for console.trace ([39b20ef](https://github.com/CoMfUcIoS/console-inline.nvim/commit/39b20ef1adece19a92af8bf2b15b685289c80f6b))
* **ui:** add automatic hover popups for log entries ([b864d77](https://github.com/CoMfUcIoS/console-inline.nvim/commit/b864d77891faaff53e5816626ea9e16830843353))


### Bug Fixes

* canonicalize file keys for queued messages ([4a05913](https://github.com/CoMfUcIoS/console-inline.nvim/commit/4a0591340efb1ea24d0e456d2876e8691934ada6))
* **ci:** allow comfucios to trigger auto-merge workflow ([95275bb](https://github.com/CoMfUcIoS/console-inline.nvim/commit/95275bbb7c7e656937d6a4165430982619c51508))
* **ci:** update tag filter for npm publish workflow ([1df85bd](https://github.com/CoMfUcIoS/console-inline.nvim/commit/1df85bd2c276296cea2881290d1e4a11a9a8934c))
* **config:** simplify hover option handling in setup ([0fcfd5d](https://github.com/CoMfUcIoS/console-inline.nvim/commit/0fcfd5d7961cd20483315196c8f512b3a5201357))
* **docs:** update plugin repo to comfucios/console-inline ([8649e64](https://github.com/CoMfUcIoS/console-inline.nvim/commit/8649e643a2c48356ea2887061216e20dd124b58b))
* improve code style and update service version ([0384612](https://github.com/CoMfUcIoS/console-inline.nvim/commit/03846126b962c75c0197f56c2be586ce5d2b0d7e))
* **render:** skip remote paths in render_message ([8e2861d](https://github.com/CoMfUcIoS/console-inline.nvim/commit/8e2861d1c543fe5c1b4ce16e5eba7d6a542f33be))


### Maintenance

* **config:** add dependabot and update release-please ([4b747e0](https://github.com/CoMfUcIoS/console-inline.nvim/commit/4b747e0dc67b3bf5c971d7fa3ffb5b8b783a15c5))
* **config:** update service version and release settings ([3b5ffe5](https://github.com/CoMfUcIoS/console-inline.nvim/commit/3b5ffe509ebe20c393ecb399694e8705ace2cc32))
* **license:** add GPL-3.0-or-later headers to all files ([a772895](https://github.com/CoMfUcIoS/console-inline.nvim/commit/a772895ea99edb433ebf8dfe10b1405d10bf19b6))
* **license:** add GPLv3 license file ([9847cae](https://github.com/CoMfUcIoS/console-inline.nvim/commit/9847cae1f666bf50dfecae22decd2eb6b48a233b))
* **license:** update to GPL-3.0-or-later ([5a6dab9](https://github.com/CoMfUcIoS/console-inline.nvim/commit/5a6dab99fcda41c8cb8e1b83c580c4840460f266))
* **lint:** allow unscoped and undefined variables in selene ([a0193fa](https://github.com/CoMfUcIoS/console-inline.nvim/commit/a0193fa2369ff2764f350023713ff65ea23c4196))
* release main ([58837e2](https://github.com/CoMfUcIoS/console-inline.nvim/commit/58837e23bdae0484d0747afd44d35204154a8416))
* release main ([0779219](https://github.com/CoMfUcIoS/console-inline.nvim/commit/0779219dd4c28a7ac5a5e8e102a1e5f9e2834e42))
* release main ([0f191e1](https://github.com/CoMfUcIoS/console-inline.nvim/commit/0f191e18bfa7860c3c9fa628767524d250ddd46a))
* release main ([29f3b48](https://github.com/CoMfUcIoS/console-inline.nvim/commit/29f3b487ac5594978c813bdd450505a71047d90f))
* release main ([fa376de](https://github.com/CoMfUcIoS/console-inline.nvim/commit/fa376de3504019c0ac215f38cacaef80cf9d9b19))
* release main ([3c9f5a5](https://github.com/CoMfUcIoS/console-inline.nvim/commit/3c9f5a5e2dde66ff8585815804f8a21417bb052e))
* release main ([54fbb7e](https://github.com/CoMfUcIoS/console-inline.nvim/commit/54fbb7e503dc3150cc9a96d35c7922e26de37aa3))
* release main ([8d12187](https://github.com/CoMfUcIoS/console-inline.nvim/commit/8d121877050b05134b528eb391a30b273e5a24d2))
* release main ([5d298e7](https://github.com/CoMfUcIoS/console-inline.nvim/commit/5d298e705c45294bc4bc2bfd7f0e28dec2a2eb81))
* release main ([9df3470](https://github.com/CoMfUcIoS/console-inline.nvim/commit/9df3470ecc0f6f1dd27deeff7d2e406575ba158f))
* release main ([8d393ae](https://github.com/CoMfUcIoS/console-inline.nvim/commit/8d393ae94d3634d9b3329520d4b8ad9c0dce6f01))
* release main ([9daeef6](https://github.com/CoMfUcIoS/console-inline.nvim/commit/9daeef64ea6609ce33018ac6c63dd0e77f2da472))
* release main ([477ee94](https://github.com/CoMfUcIoS/console-inline.nvim/commit/477ee94a22b3aa54b1cedcf7847ad7f5a1be2896))
* release main ([34baa43](https://github.com/CoMfUcIoS/console-inline.nvim/commit/34baa431171be65462f58576b1fffaaa237c9eb1))
* release main ([21e4aa8](https://github.com/CoMfUcIoS/console-inline.nvim/commit/21e4aa80e6567e3947dbffeb9cee403a3022f757))
* release main ([543452b](https://github.com/CoMfUcIoS/console-inline.nvim/commit/543452b9586e306094058809d509c224a9bbd499))
* release main ([63dff1d](https://github.com/CoMfUcIoS/console-inline.nvim/commit/63dff1d1140bce803d87e3595b50e67113c8b6ac))
* release main ([23392e3](https://github.com/CoMfUcIoS/console-inline.nvim/commit/23392e38deb3a5493da72ce81a0979916d0ae5f6))
* release main ([5bb10ce](https://github.com/CoMfUcIoS/console-inline.nvim/commit/5bb10cee40defe4eb9ce8f76f0633cd31d99f3de))
* release main ([5645ff1](https://github.com/CoMfUcIoS/console-inline.nvim/commit/5645ff16982764cbbb41b71846f16466880a4ffe))
* release main ([#12](https://github.com/CoMfUcIoS/console-inline.nvim/issues/12)) ([9b31467](https://github.com/CoMfUcIoS/console-inline.nvim/commit/9b31467528c700ea9bc7a6dc210325a818390623))
* release main ([#13](https://github.com/CoMfUcIoS/console-inline.nvim/issues/13)) ([330a91a](https://github.com/CoMfUcIoS/console-inline.nvim/commit/330a91af1192b87626fcc4bad2a6941ef1bdb4fb))
* release main ([#14](https://github.com/CoMfUcIoS/console-inline.nvim/issues/14)) ([0b01368](https://github.com/CoMfUcIoS/console-inline.nvim/commit/0b01368210bd5b3fdda042e407d7728aaa8ea267))
* release main ([#15](https://github.com/CoMfUcIoS/console-inline.nvim/issues/15)) ([381e6cc](https://github.com/CoMfUcIoS/console-inline.nvim/commit/381e6cc8e51dee6aed7aa828e91cbd5f1e333946))
* release main ([#16](https://github.com/CoMfUcIoS/console-inline.nvim/issues/16)) ([b057953](https://github.com/CoMfUcIoS/console-inline.nvim/commit/b057953025e03a3150a64db434c2ebb16ec2ee69))
* **selene:** update config for Neovim global 'vim' ([30d9cc7](https://github.com/CoMfUcIoS/console-inline.nvim/commit/30d9cc76773757c9a2d4954d6d4ecd0eb408ec67))


### Documentation

* **readme:** add CI and Lint badges to README ([3c2fe7f](https://github.com/CoMfUcIoS/console-inline.nvim/commit/3c2fe7f07de2913765a6aaa4316ef431c379d570))
* **readme:** add Console Ninja inspiration note ([72a03c5](https://github.com/CoMfUcIoS/console-inline.nvim/commit/72a03c57f32379e8b4bbda9d492d3cd0e8e37e12))
* **readme:** add developer setup for pre-commit hooks ([31a88af](https://github.com/CoMfUcIoS/console-inline.nvim/commit/31a88afef2e25f30e1d11800770f3ba79ccf8815))
* **readme:** add horizontal rule at end of file ([cfa0b42](https://github.com/CoMfUcIoS/console-inline.nvim/commit/cfa0b428ae457d84bb127196f769c58dd8bbb76a))
* **readme:** add mermaid diagram for plugin flow ([24294b4](https://github.com/CoMfUcIoS/console-inline.nvim/commit/24294b43b4b3e6c69a211a863fabcca8f808c9ca))
* **readme:** add popup screenshot for long payloads ([c085dc8](https://github.com/CoMfUcIoS/console-inline.nvim/commit/c085dc8e570983deb3f186dc6cbba74fbbcb8d70))
* **readme:** add screenshot for console-inline usage ([98bcf3e](https://github.com/CoMfUcIoS/console-inline.nvim/commit/98bcf3e466946573adfdd59e0e6bc9179e70fdcf))
* **readme:** add support section with donation link ([31057d7](https://github.com/CoMfUcIoS/console-inline.nvim/commit/31057d75ac47da4b685960bc75738558d1a57c20))
* **readme:** clarify usage and config for service ([7d87d4b](https://github.com/CoMfUcIoS/console-inline.nvim/commit/7d87d4bee99e8bd706176d9756319a45bd8898ef))
* update usage examples and release token config ([71b2b9b](https://github.com/CoMfUcIoS/console-inline.nvim/commit/71b2b9b219a88ddd617db57201f689565af847ac))

## [1.3.1](https://github.com/CoMfUcIoS/console-inline.nvim/compare/console-inline.nvim-v1.3.0...console-inline.nvim-v1.3.1) (2025-10-30)


### Documentation

* **readme:** add support section with donation link ([84ce926](https://github.com/CoMfUcIoS/console-inline.nvim/commit/84ce926b8f7f1cd5a157eb477b0017ca13324658))

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
