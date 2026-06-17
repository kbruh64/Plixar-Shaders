/*
    Plixar Shaders - shadows.glsl
    Distorted shadow map sampling with PCF soft shadows and colored
    (translucent) shadow support.
    Requires common.glsl, uniforms.glsl, space.glsl.
*/

#ifndef PLIXAR_SHADOWS
#define PLIXAR_SHADOWS

#ifdef SHADOWS_ENABLED

// Sample shadow at one distorted shadow-clip position.
// Returns sunlight visibility, tinted by colored shadow (water/glass).
vec3 sampleShadowColored(vec3 shadowClip, float bias) {
    vec2 distorted = distortShadow(shadowClip.xy);
    vec2 uv = distorted * 0.5 + 0.5;

    // Outside the shadow map -> treat as lit. Explicit bounds test for AMD.
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec3(1.0);

    float z = shadowClip.z * 0.5 + 0.5 - bias;

    // Opaque occluder test.
    float opaque = step(z, texture2D(shadowtex1, uv).r);
    if (opaque > 0.5) return vec3(1.0);

    // Something blocks the sun. Is it translucent (colored)?
    float anyOccluder = step(z, texture2D(shadowtex0, uv).r);
    if (anyOccluder > 0.5) {
        // Only a translucent thing is in the way -> tint the sunlight.
        vec4 sc = texture2D(shadowcolor0, uv);
        return mix(vec3(1.0), sc.rgb, sc.a);
    }

    return vec3(0.0); // fully occluded
}

// Soft PCF shadow with contact hardening + a distance early-out so far pixels
// (where soft edges are invisible) only cost one tap. This is both prettier
// AND faster than uniform PCF.
vec3 getShadow(vec3 worldPos, float NdotL, float dist) {
    // Steeper slope -> larger bias to kill peter-panning / acne.
    float slope = clamp(1.0 - NdotL, 0.0, 1.0);
    float bias = SHADOW_BIAS * (1.0 + slope * 4.0);

    vec3 base = worldToShadow(worldPos);

    float radius = SHADOW_SOFTNESS / float(shadowMapResolution) * 6.0;

    // Far away, or softness/taps disabled: a single sample is indistinguishable
    // and saves the whole PCF loop on most of the screen.
    float farFade = saturate(dist / (shadowDistance * 0.6));
    if (radius <= 0.0 || PCF_SAMPLES <= 1 || farFade > 0.85) {
        return sampleShadowColored(base, bias);
    }

    // Contact hardening: crisp near the camera, softer with distance.
    radius *= mix(0.5, 1.6, farFade);

    float jitter = ign(gl_FragCoord.xy + frameTimeCounter) * TAU;

    // Spiral PCF: tap count comes from the active profile (PCF_SAMPLES).
    vec3 sum = vec3(0.0);
    for (int i = 0; i < PCF_SAMPLES; i++) {
        float a = float(i) / float(PCF_SAMPLES) * TAU + jitter;
        float r = sqrt((float(i) + 0.5) / float(PCF_SAMPLES)) * radius;
        vec2 offset = vec2(cos(a), sin(a)) * r;
        sum += sampleShadowColored(base + vec3(offset, 0.0), bias);
    }
    return sum / float(PCF_SAMPLES);
}

#else
vec3 getShadow(vec3 worldPos, float NdotL, float dist) { return vec3(1.0); }
#endif // SHADOWS_ENABLED

#endif // PLIXAR_SHADOWS
