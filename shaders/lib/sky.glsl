/*
    Plixar Shaders - sky.glsl
    Analytic atmospheric scattering + sun/moon disc + time-of-day color grading.
    Requires common.glsl and uniforms.glsl.
*/

#ifndef PLIXAR_SKY
#define PLIXAR_SKY

// World-space sun direction (camera-relative view dir -> world).
vec3 getSunDir() {
    return normalize(mat3(gbufferModelViewInverse) * normalize(sunPosition));
}
vec3 getMoonDir() {
    return normalize(mat3(gbufferModelViewInverse) * normalize(moonPosition));
}

// Returns the dominant light direction (sun by day, moon by night).
vec3 getShadowLightDir() {
    return normalize(mat3(gbufferModelViewInverse) * normalize(shadowLightPosition));
}

// 0 at sunrise/sunset, 1 at noon/midnight. Used to fade lighting/sky.
float dayFactor() {
    vec3 s = getSunDir();
    return saturate(s.y);
}

// Smooth day/night blend; 1 = full day, 0 = full night.
float timeBlend() {
    vec3 s = getSunDir();
    return smoothstep(-0.08, 0.20, s.y);
}

// Sunlight tint (Derivative/Sora-style: soft warm, never harsh white):
//   horizon (warm amber) -> low (gold) -> noon (gentle creamy warm).
vec3 sunlightColor() {
    float h = saturate(getSunDir().y);
    vec3 horizonRed = vec3(1.00, 0.38, 0.22);
    vec3 golden     = vec3(1.00, 0.68, 0.42);
    vec3 noon       = vec3(1.00, 0.93, 0.82);   // creamy, not pure white

    vec3 c = mix(horizonRed, golden, smoothstep(0.0, 0.12, h));
    c = mix(c, noon, smoothstep(0.10, 0.45, h));
    // Tint cooler & dimmer when it's raining.
    c = mix(c, vec3(0.62, 0.68, 0.80), rainStrength * 0.6);
    return c;
}

vec3 moonlightColor() {
    return mix(vec3(0.32, 0.44, 0.66), vec3(0.22, 0.30, 0.47), rainStrength);
}

// Ambient / sky color used to fill shadows. Derivative-style: luminous,
// strongly sky-colored, soft blue daytime fill so shadows read airy not black.
vec3 ambientColor() {
    float t = timeBlend();
    vec3 dayAmb   = vec3(0.52, 0.66, 0.86);     // brighter, bluer sky fill
    vec3 nightAmb = vec3(0.07, 0.10, 0.18);
    vec3 c = mix(nightAmb, dayAmb, t);
    return mix(c, vec3(0.34, 0.37, 0.42), rainStrength * 0.7);
}

// ---------------------------------------------------------------------------
//  Cheap sky color for fog tinting: just the day/night gradient + sun glow.
//  Skips the sun/moon discs, stars and twinkle -- those are invisible behind
//  fog anyway, so this saves a lot of work on every foggy fragment.
// ---------------------------------------------------------------------------
vec3 skyGradient(vec3 dir) {
    float t = timeBlend();
    float up = saturate(dir.y * 0.5 + 0.5);

    vec3 zenith  = mix(vec3(0.01, 0.02, 0.05), vec3(0.16, 0.34, 0.72), t);
    vec3 horizon = mix(vec3(0.04, 0.06, 0.12), vec3(0.62, 0.74, 0.92), t);

    vec3 sky = mix(zenith, horizon, pow(1.0 - up, 2.2));

    float sunCos = saturate(dot(dir, getSunDir()));
    sky += sunlightColor() * (pow(sunCos, 8.0) * 0.6 + pow(sunCos, 2.0) * 0.15) * t;

    sky = mix(sky, vec3(luma(sky)) * vec3(0.6, 0.64, 0.7), rainStrength * 0.7);
    return sky * SKY_INTENSITY;
}

// ---------------------------------------------------------------------------
//  Procedural sky (Preetham-ish analytic gradient + scattering).
//  dir: normalized world-space view direction.
// ---------------------------------------------------------------------------
vec3 computeSky(vec3 dir) {
    vec3 sunDir  = getSunDir();
    vec3 moonDir = getMoonDir();
    float t = timeBlend();

    float up = saturate(dir.y * 0.5 + 0.5);

    // Base gradient: zenith -> horizon.
    vec3 dayZenith   = vec3(0.16, 0.34, 0.72);
    vec3 dayHorizon  = vec3(0.62, 0.74, 0.92);
    vec3 nightZenith = vec3(0.01, 0.02, 0.05);
    vec3 nightHorizon= vec3(0.04, 0.06, 0.12);

    vec3 zenith  = mix(nightZenith, dayZenith, t);
    vec3 horizon = mix(nightHorizon, dayHorizon, t);

    float grad = pow(1.0 - up, 2.2);
    vec3 sky = mix(zenith, horizon, grad);

    // Mie-ish forward scattering halo around the sun -> warm horizon glow.
    float sunCos = saturate(dot(dir, sunDir));
    float mie = pow(sunCos, 8.0) * 0.6 + pow(sunCos, 2.0) * 0.15;
    vec3 glow = sunlightColor() * mie * t;
    sky += glow;

    // Sunset reddening along the horizon band.
    float horizonBand = pow(1.0 - abs(dir.y), 6.0);
    float lowSun = saturate(1.0 - sunDir.y * 3.0) * t;
    sky = mix(sky, sky + vec3(0.55, 0.18, 0.05), horizonBand * lowSun * 0.5);

    // Sun disc.
    float sunDisc = smoothstep(0.9995, 0.99975, sunCos);
    sky += sunlightColor() * sunDisc * 12.0 * t;

    // Moon disc + faint glow.
    float moonCos = saturate(dot(dir, moonDir));
    float moonDisc = smoothstep(0.9997, 0.99985, moonCos);
    sky += vec3(0.9, 0.95, 1.0) * moonDisc * 6.0 * (1.0 - t);
    sky += moonlightColor() * pow(moonCos, 64.0) * 0.4 * (1.0 - t);

    // Stars at night (only above horizon).
    if (dir.y > 0.0) {
        vec2 starUv = dir.xz / (dir.y + 0.15);
        float star = hash12(floor(starUv * 80.0));
        star = step(0.997, star) * smoothstep(0.0, 0.3, dir.y);
        float twinkle = 0.6 + 0.4 * sin(frameTimeCounter * 3.0 + star * 50.0);
        sky += vec3(star * twinkle) * (1.0 - t) * 0.9;
    }

    // Rain desaturates & greys the sky.
    sky = mix(sky, vec3(luma(sky)) * vec3(0.6, 0.64, 0.7), rainStrength * 0.7);

    return sky * SKY_INTENSITY;
}

#endif // PLIXAR_SKY
