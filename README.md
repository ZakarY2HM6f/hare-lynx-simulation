# Hare x Lynx

a simulation of predator and prey population dynamics between hare and lynx written in zig.

## Getting Started

try it out at: https://z3n1th.kozow.com/projects/hare-lynx/

### Dependencies

- zig 0.12.0
- emscripten (for web build)
- SDL2

### Building

just build with `zig build`

#### Native

rename build_config.template.json to build_config.json

```shell
mv build_config.json build_config.json
```

fill in the paths to SDL as instructed in the config file

```shell
zig build run
```

#### Wasm

```shell
zig build -Dtarget=wasm32-emscripten serve
```

you may need to trick emscripten into caching SDL port and headers before building

```shell
emcc -sUSE_SDL=2 -c [empty text file here]
```

## Screenshots

![](https://github.com/ZakarY2HM6f/hare-lynx-simulation/blob/master/screenshots/screenshot01.gif)
