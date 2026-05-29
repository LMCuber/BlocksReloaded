import pygame
import numpy as np
import opensimplex
import uuid

# --- CONFIGURATION ---
WINDOW_SIZE = 800    # The physical window size (800x800)
GRID_SIZE = 256       # The logical noise resolution (64x64)

SCALE = 0.05         # Zoom level (adjusted for smaller grid)
OCTAVES = 3
PERSISTENCE = 0.5
LACUNARITY = 2.0
THRESHOLD = 0.5

def generate_octave_noise_map(width, height, seed=42, discrete=True, worm=False):
    gen = opensimplex.OpenSimplex(seed=seed)
    
    x_idx = np.arange(width)
    y_idx = np.arange(height)
    
    noise_map = np.zeros((height, width))
    amplitude = 1.0
    frequency = 1.0
    max_val = 0.0

    # Optimization: vectorize once outside the loop
    v_noise = np.vectorize(gen.noise2)

    for _ in range(OCTAVES):
        layer = v_noise(x_idx[None, :] * SCALE * frequency, 
                        y_idx[:, None] * SCALE * frequency)
        
        noise_map += layer * amplitude
        max_val += amplitude
        amplitude *= PERSISTENCE
        frequency *= LACUNARITY

    # normalize to [-1, 1]
    noise_map /= max_val
    # normalize to [0, 1]
    noise_map = (noise_map + 1) / 2

    if worm:
        noise_map = -np.abs(noise_map * 2 - 1) + 1
    print(np.sum(noise_map > 0.5))
    print(np.sum(noise_map > 0))
    
    # 255 for White (land/noise), 0 for Black (background/under threshold)
    final_img = np.where(noise_map > 0.88, 255, 0).astype(np.uint8)
    return np.stack([final_img] * 3, axis=-1)

def main():
    pygame.init()
    # Display window is big
    screen = pygame.display.set_mode((WINDOW_SIZE, WINDOW_SIZE))
    pygame.display.set_caption(f"Noise Grid: {GRID_SIZE}x{GRID_SIZE}")

    # Initial generation at small resolution
    def get_new_surface():
        # 1. Generate the small data array
        raw_array = generate_octave_noise_map(GRID_SIZE, GRID_SIZE, int(uuid.uuid4()), discrete=False, worm=True)
        # 2. Create small surface
        small_surf = pygame.surfarray.make_surface(raw_array.swapaxes(0, 1))
        # 3. Scale up to window size (use SCALED or NEAREST to keep it pixelated)
        return pygame.transform.scale(small_surf, (WINDOW_SIZE, WINDOW_SIZE))

    surface = get_new_surface()

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    surface = get_new_surface()

        screen.blit(surface, (0, 0))
        pygame.display.flip()

    pygame.quit()

if __name__ == "__main__":
    main()