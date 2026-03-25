shader_type canvas_item;

// === PIXELATION ===
uniform float pixel_scale : hint_range(1.0, 8.0, 1.0) = 2.0;

// === COLOR QUANTIZATION ===
uniform float color_levels : hint_range(2.0, 32.0, 1.0) = 16.0;
uniform bool enable_dithering = true;
uniform float dither_strength : hint_range(0.0, 2.0) = 0.5;

// === SCANLINES ===
uniform bool enable_scanlines = true;
uniform float scanline_intensity : hint_range(0.0, 0.5) = 0.08;
uniform float scanline_count : hint_range(100.0, 1080.0) = 540.0;

// === VIGNETTE ===
uniform bool enable_vignette = true;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_softness : hint_range(0.1, 1.0) = 0.5;

// === CHROMATIC ABERRATION ===
uniform bool enable_chromatic = true;
uniform float chromatic_amount : hint_range(0.0, 5.0) = 1.2;

// === COLOR GRADING ===
uniform float contrast : hint_range(0.5, 2.0) = 1.2;
uniform float saturation : hint_range(0.0, 2.0) = 1.3;
uniform float brightness : hint_range(0.5, 1.5) = 1.05;
uniform vec3 color_tint = vec3(1.0, 0.98, 0.95);

// === SCREEN SHAKE ===
uniform float shake_intensity : hint_range(0.0, 20.0) = 0.0;
uniform float shake_speed : hint_range(1.0, 50.0) = 25.0;

// === DAMAGE FLASH ===
uniform float damage_flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 damage_flash_color : source_color = vec3(0.8, 0.05, 0.05);

// === DISTANCE FOG ===
uniform bool enable_fog = false;
uniform vec3 fog_color : source_color = vec3(0.05, 0.02, 0.1);
uniform float fog_start : hint_range(0.0, 1.0) = 0.3;
uniform float fog_end : hint_range(0.0, 1.0) = 0.85;

// === FILM GRAIN ===
uniform bool enable_grain = false;
uniform float grain_intensity : hint_range(0.0, 0.3) = 0.08;
uniform float grain_speed : hint_range(1.0, 100.0) = 30.0;

// Bayer 4x4 ordered dithering matrix
float bayer4x4(vec2 position) {
    int x = int(mod(position.x, 4.0));
    int y = int(mod(position.y, 4.0));
    int index = x + y * 4;

    if (index == 0) return 0.0 / 16.0;
    if (index == 1) return 8.0 / 16.0;
    if (index == 2) return 2.0 / 16.0;
    if (index == 3) return 10.0 / 16.0;
    if (index == 4) return 12.0 / 16.0;
    if (index == 5) return 4.0 / 16.0;
    if (index == 6) return 14.0 / 16.0;
    if (index == 7) return 6.0 / 16.0;
    if (index == 8) return 3.0 / 16.0;
    if (index == 9) return 11.0 / 16.0;
    if (index == 10) return 1.0 / 16.0;
    if (index == 11) return 9.0 / 16.0;
    if (index == 12) return 15.0 / 16.0;
    if (index == 13) return 7.0 / 16.0;
    if (index == 14) return 13.0 / 16.0;
    return 5.0 / 16.0;
}

// Simple hash for shake randomness
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;

    // === SCREEN SHAKE ===
    if (shake_intensity > 0.0) {
        float shake_x = (hash(vec2(TIME * shake_speed, 0.0)) - 0.5) * 2.0;
        float shake_y = (hash(vec2(0.0, TIME * shake_speed)) - 0.5) * 2.0;
        uv += vec2(shake_x, shake_y) * shake_intensity / screen_size;
        uv = clamp(uv, vec2(0.0), vec2(1.0));
    }

    // === PIXELATION ===
    vec2 pixel_uv = floor(uv * screen_size / pixel_scale) * pixel_scale / screen_size;

    // === CHROMATIC ABERRATION ===
    vec3 color;
    if (enable_chromatic) {
        float r = texture(TEXTURE, pixel_uv + vec2(chromatic_amount, 0.0) / screen_size).r;
        float g = texture(TEXTURE, pixel_uv).g;
        float b = texture(TEXTURE, pixel_uv - vec2(chromatic_amount, 0.0) / screen_size).b;
        color = vec3(r, g, b);
    } else {
        color = texture(TEXTURE, pixel_uv).rgb;
    }

    // === COLOR GRADING ===
    // Brightness
    color *= brightness;

    // Contrast (around 0.5 midpoint)
    color = (color - 0.5) * contrast + 0.5;

    // Saturation
    float gray = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(gray), color, saturation);

    // Color tint
    color *= color_tint;

    // === DITHERING + COLOR QUANTIZATION ===
    if (enable_dithering) {
        vec2 pixel_pos = uv * screen_size;
        float dither = (bayer4x4(pixel_pos) - 0.5) * dither_strength / color_levels;
        color += dither;
    }

    // Quantize to limited color levels
    color = floor(color * color_levels + 0.5) / color_levels;

    // === SCANLINES ===
    if (enable_scanlines) {
        float scanline = sin(uv.y * scanline_count * 3.14159);
        scanline = scanline * 0.5 + 0.5;
        scanline = mix(1.0 - scanline_intensity, 1.0, scanline);
        color *= scanline;
    }

    // === VIGNETTE ===
    if (enable_vignette) {
        vec2 vig_uv = uv * (1.0 - uv);
        float vig = vig_uv.x * vig_uv.y * 15.0;
        vig = pow(vig, vignette_softness);
        vig = clamp(vig, 0.0, 1.0);
        color *= mix(1.0 - vignette_intensity, 1.0, vig);
    }

    // === DAMAGE FLASH ===
    if (damage_flash_intensity > 0.0) {
        // Flash edges more than center (ULTRAKILL style)
        vec2 center_dist = abs(uv - 0.5) * 2.0;
        float edge_mask = max(center_dist.x, center_dist.y);
        edge_mask = pow(edge_mask, 1.5);
        float flash = damage_flash_intensity * mix(0.5, 1.0, edge_mask);
        color = mix(color, damage_flash_color, flash);
    }

    // === DISTANCE FOG (radial UV-based approximation) ===
    if (enable_fog) {
        float dist = length(uv - vec2(0.5));
        float fog_factor = smoothstep(fog_start, fog_end, dist * 2.0);
        color = mix(color, fog_color, fog_factor);
    }

    // === FILM GRAIN ===
    if (enable_grain) {
        float noise = hash(uv * screen_size + vec2(TIME * grain_speed, 0.0)) * 2.0 - 1.0;
        color += vec3(noise * grain_intensity);
    }

    // Clamp final output
    color = clamp(color, 0.0, 1.0);

    COLOR = vec4(color, 1.0);
}
