/*
    Plixar Shaders - common.glsl
    Shared constants, settings defaults, and helper functions.
    Included by nearly every program.
*/

#ifndef PLIXAR_COMMON
#define PLIXAR_COMMON

// ---------------------------------------------------------------------------
//  Settings (overridable from the in-game GUI via shaders.properties)
//
//  Boolean toggles are BARE #defines (no #ifndef guard). That is what lets the
//  loader and the profile '!' syntax actually disable them -- it comments the
//  line out. Wrapping them in #ifndef would re-enable them every time, so
//  don't do that here. (Slider/value macros below DO use #ifndef.)
// ---------------------------------------------------------------------------
#define SHADOWS_ENABLED    // [SHADOWS_ENABLED]
#define AO_ENABLED         // [AO_ENABLED]
#define WATER_WAVES        // [WATER_WAVES]
#define WATER_REFLECTIONS  // [WATER_REFLECTIONS]
#define WATER_REFRACTION   // [WATER_REFRACTION]
#define FOG_ENABLED        // [FOG_ENABLED]
#define GODRAYS_ENABLED    // [GODRAYS_ENABLED]
#define BLOOM_ENABLED      // [BLOOM_ENABLED]
#define TONEMAP_ENABLED    // [TONEMAP_ENABLED]
#define VIGNETTE           // [VIGNETTE]

#ifndef SHADOW_SOFTNESS
    #define SHADOW_SOFTNESS 1.5      // [0.0 0.5 1.0 1.5 2.0 3.0 4.0]
#endif
#ifndef SHADOW_BIAS
    #define SHADOW_BIAS 0.0008       // [0.0002 0.0004 0.0008 0.0012 0.0020]
#endif
#ifndef SUN_INTENSITY
    #define SUN_INTENSITY 2.7        // [1.0 1.5 2.0 2.2 2.7 3.2 3.6 4.0]
#endif
#ifndef AMBIENT_STRENGTH
    #define AMBIENT_STRENGTH 0.7     // [0.10 0.20 0.30 0.35 0.45 0.55 0.7 0.85 1.0]
#endif
#ifndef WATER_OPACITY
    #define WATER_OPACITY 0.72       // [0.40 0.55 0.72 0.85 0.95]
#endif
#ifndef FOG_DENSITY
    #define FOG_DENSITY 1.0          // [0.5 0.75 1.0 1.5 2.0 3.0]
#endif
#ifndef GODRAYS_SAMPLES
    #define GODRAYS_SAMPLES 24       // [8 12 16 24 32 48]
#endif
#ifndef SKY_INTENSITY
    #define SKY_INTENSITY 1.0        // [0.5 0.75 1.0 1.25 1.5]
#endif
#ifndef BLOOM_STRENGTH
    #define BLOOM_STRENGTH 0.45      // [0.10 0.25 0.45 0.60 0.80 1.00]
#endif
#ifndef EXPOSURE
    #define EXPOSURE 1.0             // [0.6 0.8 1.0 1.12 1.25 1.4 1.6]
#endif
#ifndef SATURATION
    #define SATURATION 1.05          // [0.8 0.9 1.0 1.05 1.15 1.25 1.4]
#endif

// ---------------------------------------------------------------------------
//  Shadow map sizing / quality.
//  SHADOW_RES / PCF_SAMPLES are set by the active profile (see
//  shaders.properties). Lower = faster.
// ---------------------------------------------------------------------------
#ifndef SHADOW_RES
    #define SHADOW_RES 1024          // [512 1024 2048 3072 4096]
#endif
#ifndef PCF_SAMPLES
    #define PCF_SAMPLES 6            // [1 4 6 9 12 16]
#endif

const int   shadowMapResolution = SHADOW_RES;
const float shadowDistance      = 64.0;     // shorter = less to render = faster
const bool  shadowHardwareFiltering = false;
const float sunPathRotation     = -25.0;    // tilts the sun path for nicer angles

// ---------------------------------------------------------------------------
//  Constants
// ---------------------------------------------------------------------------
const float PI      = 3.14159265359;
const float TAU     = 6.28318530718;
const float EPS     = 1e-4;

// ---------------------------------------------------------------------------
//  Math / color helpers
// ---------------------------------------------------------------------------
float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec2  saturate(vec2 x)  { return clamp(x, 0.0, 1.0); }
vec3  saturate(vec3 x)  { return clamp(x, 0.0, 1.0); }

float luma(vec3 c) { return dot(c, vec3(0.2125, 0.7154, 0.0721)); }

// sRGB <-> linear (Mojang stores albedo in sRGB-ish space)
vec3 toLinear(vec3 c)  { return pow(c, vec3(2.2)); }
vec3 toGamma(vec3 c)   { return pow(c, vec3(1.0 / 2.2)); }

// Cheap, stable hash for dithering / blue-ish noise.
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Interleaved gradient noise — great for soft shadow / dither offsets.
float ign(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

vec2 rotate2(vec2 v, float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c) * v;
}

#endif // PLIXAR_COMMON
