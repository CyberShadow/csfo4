Fallout 4 Mods
==============

Mods:

 * [DLL loader](http://www.nexusmods.com/fallout4/mods/1844)
 * [Pip-Boy App Local Map Fix](http://www.nexusmods.com/fallout4/mods/644)
 * [Upscale](http://www.nexusmods.com/fallout4/mods/1850)

Directory layout:

 * `common`: Common code
 * `directx`: DirectX
 * `dxlog`: DirectX COM instrumenter/logger
 * `mapfix`: MapFix mod code
 * `proxy`: DLL loader
 * `testhost`: Test injection host
 * `upscale`: Upscale mod code

Building
--------

Requirements:

- [DMD](http://dlang.org/) 2.070
- [SlimD](https://github.com/CyberShadow/SlimD)
- [UniLink](http://goo.gl/i0rP1t)

Run `slimbuild` from within a component's directory to build it.
