#version 120
/*
    Plixar Shaders - final.fsh
    Output stage: composite bloom, filmic tone mapping, exposure, color grade
    (saturation + subtle teal/orange split), vignette, and ordered dithering
    to kill 8-bit banding.
*/

#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;

// Lottes-style tonemap: rolls off highlights cleanly without the heavy
// desaturation and midtone-darkening of Narkowicz ACES. Keeps the bright,
// vivid look the popular packs have. Normalised so white maps to white.
vec3 tonemap(vec3 x) {
    const float p = 1.2;    // shoulder contrast
    const float w = 1.5;    // white point (input that maps to 1.0)
    vec3 z = pow(x, vec3(p));
    float wp = pow(w, p);
    return (z * (1.0 + wp)) / ((z + 1.0) * wp);
}

void main() {
    vec3 color = texture2D(colortex0, texcoord).rgb;

    // --- Bloom ---
#ifdef BLOOM_ENABLED
    vec3 bloom = texture2D(colortex3, texcoord).rgb;
    color += bloom * BLOOM_STRENGTH;
#endif

    // --- Exposure ---
    color *= EXPOSURE;

    // --- Tone mapping ---
#ifdef TONEMAP_ENABLED
    color = tonemap(color);
#else
    color = color / (color + 1.0);     // cheap Reinhard for low-end
#endif
    color = saturate(color);

    // --- Color grade ---
    float l = luma(color);

    // Vibrance: boost saturation more in dull areas, less in already-saturated
    // ones -- gives the punchy-but-not-neon look without clipping colors.
    float sat = SATURATION;
    vec3 gray = vec3(l);
    float satMask = 1.0 - saturate(distance(color, gray) * 1.5);
    color = mix(gray, color, sat + satMask * 0.25);

    // Soft split-tone: cool airy shadows, warm highlights (subtle).
    vec3 shadowTint    = vec3(0.95, 0.99, 1.05);
    vec3 highlightTint = vec3(1.05, 1.01, 0.96);
    color *= mix(shadowTint, highlightTint, smoothstep(0.0, 1.0, l));

    // Gentle filmic contrast: lift shadows a touch, add a soft S for pop.
    color = pow(color, vec3(0.95));
    color = smoothstep(0.0, 1.0, color) * 0.25 + color * 0.75;

    // --- Vignette ---
#ifdef VIGNETTE
    vec2 q = texcoord - 0.5;
    float vig = smoothstep(1.1, 0.5, length(q) * 1.25);
    color *= mix(1.0, vig, 0.18);
#endif

    // --- Dither to break up banding in dark gradients. ---
    float dither = (hash12(gl_FragCoord.xy) - 0.5) / 255.0;
    color += dither;

    gl_FragColor = vec4(saturate(color), 1.0);
}
