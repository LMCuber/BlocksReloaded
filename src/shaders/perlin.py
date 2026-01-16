import pygame
import opensimplex as osim


def octave_noise2(x, y, octaves=4, persistence=0.5, lacunarity=2.0):
    value = 0
    amplitude = 1
    frequency = 12
    maxAmplitude = 0

    for _ in range(octaves):
        value += osim.noise2(x * frequency, y * frequency) * amplitude
        maxAmplitude += amplitude
        amplitude *= persistence
        frequency *= lacunarity

    return value / maxAmplitude


s = 256
surf = pygame.Surface((s, s))
for y in range(s):
    for x in range(s):
        h = (octave_noise2(x / s, y / s, octaves=20) + 1) * 0.5
        c = [h * 255] * 3
        surf.set_at((x, y), c)
pygame.image.save(surf, "res/perlin.png")
