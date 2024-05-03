# Hare x Lynx

A simulation of predator and prey population dynamics between hare and lynx written in zig.

## Getting Started

try it out at: https://z3n1th.kozow.com/projects/hare-lynx/

### Dependencies

- zig (I'm on 0.13.0-dev.46+3648d7df1)
- emscripten (for web build)
- SDL2

### Building

just build with `zig run`

for native:

```shell
zig build run
```

*note: Windows is not supported currently, don't want to know how to link everything properly*

for wasm:

```shell
zig build -Dtarget=wasm32-emscripten serve
```

you may need to trick emscripten into caching SDL port and headers before building

```shell
emcc -sUSE_SDL=2 -c [empty text file here]
```

## Screenshots

![](https://github.com/ZakarY2HM6f/hare-lynx-simulation/blob/master/screenshots/screenshot01.gif)
