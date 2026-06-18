#version 120
/*
    Plixar Shaders - gbuffers_water.fsh
    Forward-shaded translucents. Water gets normal-mapped ripples, a fresnel
    sky reflection, depth-based color, and specular sun glint. Drawn after the
    composite lighting of the opaque scene so it blends over a lit background.
*/

#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/space.glsl"
#include "/lib/sky.glsl"

uniform sampler2D texture;

varying vec2  texcoord;
varying vec2  lmcoord;
varying vec4  vColor;
varying vec3  vNormal;
varying vec3  viewPos;
varying vec3  worldPos;
varying float isWater;

// Complementary-style water surface: a height field built from several
// scrolling directional waves at two scales, giving a lively crisp surface.
float waterWaves(vec2 p, float t) {
    float h = 0.0;
    // Large, slow swells.
    h += sin(dot(p, vec2( 0.6,  0.8)) + t * 1.1) * 0.060;
    h += sin(dot(p, vec2(-0.7,  0.5)) + t * 1.7) * 0.040;
    h += sin(dot(p, vec2( 0.2, -0.9)) + t * 2.3) * 0.025;
    // Small, fast ripples (higher frequency) for the fine sparkle/detail.
    h += sin(dot(p, vec2( 2.3,  1.7)) + t * 3.1) * 0.012;
    h += sin(dot(p, vec2(-1.9,  2.4)) + t * 3.9) * 0.009;
    return h;
}

// Surface normal via central differences of the height field.
vec3 waterNormal(vec2 p, float t) {
    float e = 0.06;
    float hL = waterWaves(p - vec2(e, 0.0), t);
    float hR = waterWaves(p + vec2(e, 0.0), t);
    float hD = waterWaves(p - vec2(0.0, e), t);
    float hU = waterWaves(p + vec2(0.0, e), t);
    // Steepness controls how bumpy the surface reads.
    float steep = 7.0;
    return normalize(vec3(-(hR - hL) * steep, 1.0, -(hU - hD) * steep));
}

/* DRAWBUFFERS:0 */
void main() {
    vec4 albedo = texture2D(texture, texcoord) * vColor;

    vec3 viewDir = normalize(-viewPos);
    vec3 N = normalize(vNormal);

    if (isWater > 0.5) {
        vec2 wxz = (worldPos + cameraPosition).xz;
        vec3 wn = waterNormal(wxz, frameTimeCounter);
        // Bring the world-space wave normal into view space.
        N = normalize(mat3(gbufferModelView) * wn);
        if (dot(N, viewDir) < 0.0) N = -N;

        vec3 worldNormal = wn;
        vec3 worldViewDir = normalize(mat3(gbufferModelViewInverse) * viewDir);

        // --- Water depth: how much water the view ray passes through. Reads the
        //     opaque depth behind the surface so shallow water reads clear and
        //     deep water reads dark/blue (Complementary's signature gradient).
        float surfDepth = gl_FragCoord.z;
        float backDepthHW = texture2D(depthtex1, gl_FragCoord.xy * texelSize).r;
        float backDist = linearizeDepth(backDepthHW);
        float surfDist = linearizeDepth(surfDepth);
        float waterDepth = max(backDist - surfDist, 0.0);
        float depthFade = saturate(waterDepth * 0.18);     // 0 shallow .. 1 deep

        // --- Fresnel (Schlick) — more reflective at grazing angles.
        float fres = pow(1.0 - saturate(dot(N, viewDir)), 5.0);
        fres = mix(0.02, 1.0, fres);

        // --- Reflected sky.
        vec3 refl = reflect(-worldViewDir, worldNormal);
        refl.y = abs(refl.y);
#ifdef WATER_REFLECTIONS
        // Full sky (with sun glow) for the reflective Complementary look.
        vec3 skyRefl = computeSky(refl);
#else
        vec3 skyRefl = skyGradient(refl);
#endif

        // --- Dual sun specular: a tight bright sparkle + a softer broad glint.
        vec3 L = getShadowLightDir();
        vec3 H = normalize(L + worldViewDir);
        float NdotH = saturate(dot(worldNormal, H));
        float sparkle = pow(NdotH, 600.0) * 18.0;          // tight, bright
        float glint   = pow(NdotH, 120.0) * 3.0;           // soft halo
        vec3 sunSpec = sunlightColor() * (sparkle + glint) * timeBlend();

        // --- Water body color: bright teal shallow -> deep blue absorption.
        //     Brighter than physically-deep water so it reads vivid (matching
        //     the popular packs) rather than muddy after tone mapping.
        vec3 shallow = vec3(0.22, 0.62, 0.70);
        vec3 mid     = vec3(0.08, 0.36, 0.52);
        vec3 deep    = vec3(0.02, 0.14, 0.30);
        vec3 waterCol = mix(shallow, mid, smoothstep(0.0, 0.45, depthFade));
        waterCol = mix(waterCol, deep, smoothstep(0.4, 1.0, depthFade));
        // Sky access brightens open water a touch.
        waterCol *= mix(0.8, 1.25, lmcoord.y);

        // --- Compose: tint -> sky reflection by fresnel, add the sparkle.
        vec3 col = mix(waterCol, skyRefl, fres) + sunSpec;

        // Shallow edges are more transparent (you see the bottom); deep water
        // and grazing angles are more opaque/reflective.
        float alpha = mix(0.25, WATER_OPACITY, depthFade);
        alpha = mix(alpha, 1.0, fres * 0.8);
        gl_FragData[0] = vec4(col, clamp(alpha, 0.04, 1.0));
        return;
    }

    // --- Other translucents (stained glass, ice): simple lit pass-through. ---
    if (albedo.a < 0.01) discard;

    vec3 lin = toLinear(albedo.rgb);
    // Cheap diffuse from the lightmap so glass isn't flat.
    float skyL = lmcoord.y;
    float blockL = lmcoord.x;
    vec3 light = ambientColor() + sunlightColor() * skyL * 0.6
               + vec3(1.0, 0.75, 0.45) * blockL * 1.2;
    vec3 col = toGamma(lin * light);

    gl_FragData[0] = vec4(col, albedo.a);
}
