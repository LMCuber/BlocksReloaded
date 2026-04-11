# Blockingdom
is a game

## Technical info
- Language: LuaJIT 5.1
- Graphics library: [Love2D](https://love2d.org/)
- Entities: proprietary ECS heavily inspired by [esper](https://github.com/benmoran56/esper) for Python (added chunk support)
- World generation:
    - Resource management: chunking `N × N` areas (currently `16 × 16`)
    - Cave generation: 2D [simplex noise](https://en.wikipedia.org/wiki/Simplex_noise) / 2D [ridge](https://stackoverflow.com/questions/36796829/procedural-terrain-with-ridged-fractal-noise) noise
- Lighting: iterative BFS every `N` frames (currently `10`)

## Preview
<img src="previews/overworld.png" width="900" />
<img src="previews/cave.png" width="900" />
