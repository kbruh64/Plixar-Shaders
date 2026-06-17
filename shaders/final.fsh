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

// ACES filmic approximation (Narkowicz).
vec3 acesTonemap(vec3 x) {
    const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
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
    color = acesTonemap(color);
#else
    // Cheap Reinhard so low-end still rolls off highlights instead of the
    // ugly hard white clamp -- one divide, basically free.
    color = color / (color + 1.0);
#endif

    // --- Color grade ---
    // Saturation.
    float l = luma(color);
    color = mix(vec3(l), color, SATURATION);

    // Derivative-style split-tone: cool airy shadows, soft warm highlights.
    vec3 shadowTint    = vec3(0.93, 0.99, 1.07);
    vec3 highlightTint = vec3(1.06, 1.01, 0.94);
    color *= mix(shadowTint, highlightTint, smoothstep(0.0, 1.0, l));

    // Gentle shadow lift so dark areas keep detail, then a very light
    // S-curve for a bit of pop (much weaker than before to avoid crushing).
    color = pow(color, vec3(0.92));                       // lift shadows
    color = color * color * (3.0 - 2.0 * color) * 0.15 + color * 0.85;

    // --- Vignette ---
#ifdef VIGNETTE
    vec2 q = texcoord - 0.5;
    float vig = smoothstep(1.05, 0.45, length(q) * 1.25);
    color *= mix(1.0, vig, 0.22);
#endif

    // --- Dither to break up banding in dark gradients. ---
    float dither = (hash12(gl_FragCoord.xy) - 0.5) / 255.0;
    color += dither;

    gl_FragColor = vec4(saturate(color), 1.0);
}
