#version 120
/*
    Plixar Shaders - deferred.fsh
    Deferred lighting for opaque geometry. Reads the gbuffer, reconstructs
    world position, and combines:
        - direct sunlight  (shadowed, colored shadows)
        - sky ambient      (hemisphere)
        - block light      (warm point fill from lightmap)
        - a simple SSAO-ish contact term from the lightmap + normal
    Sky pixels are replaced with the procedural sky.
*/

#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/space.glsl"
#include "/lib/sky.glsl"
#include "/lib/shadows.glsl"

varying vec2 texcoord;

/* DRAWBUFFERS:0 */
void main() {
    float depth = texture2D(depthtex0, texcoord).r;

    // --- Sky pixels: paint procedural sky and bail out. ---
    if (depth >= 1.0) {
        vec3 viewPos = screenToView(texcoord, depth);
        vec3 dir = normalize(mat3(gbufferModelViewInverse) * normalize(viewPos));
        gl_FragData[0] = vec4(computeSky(dir), 1.0);
        return;
    }

    // --- Unpack gbuffer. ---
    vec3 albedoG = texture2D(colortex0, texcoord).rgb;
    vec4 normalData = texture2D(colortex1, texcoord);
    vec4 lightData = texture2D(colortex2, texcoord);

    // Geometry written by gbuffers passes is marked with lightData.a == 1.
    // Anything else (e.g. already-shaded forward stuff) passes straight through.
    if (lightData.a < 0.5) {
        gl_FragData[0] = vec4(albedoG, 1.0);
        return;
    }

    vec3 albedo = toLinear(albedoG);
    vec3 N = normalize(normalData.xyz * 2.0 - 1.0);
    vec2 lm = lightData.rg;
    float matId = normalData.a * 255.0;          // 0 generic, 1 plant, 2 leaves
    float isFoliage = step(0.5, matId);          // 1 for plants & leaves

    vec3 viewPos  = screenToView(texcoord, depth);
    float dist    = length(viewPos);
    vec3 worldPos = viewToWorld(viewPos);
    vec3 worldN   = normalize(mat3(gbufferModelViewInverse) * N);
    vec3 V        = normalize(-worldPos);            // frag -> camera (world)

    // --- Direct sunlight ---
    vec3 L = getShadowLightDir();
    float rawNdotL = dot(worldN, L);
    float NdotL = saturate(rawNdotL);

    // Half-Lambert wrap: surfaces ease into shadow instead of a hard terminator.
    // Much softer, more natural falloff -- and free.
    float wrap = saturate(rawNdotL * 0.6 + 0.4);
    wrap *= wrap;

    vec3 shadow = getShadow(worldPos, NdotL, dist);
    vec3 sunCol = mix(moonlightColor(), sunlightColor(), timeBlend());
    float lightStr = mix(0.25, SUN_INTENSITY, timeBlend());

    vec3 direct = sunCol * wrap * shadow * lightStr;

    // --- Specular sun highlight (broad Blinn-Phong). Roughness comes from the
    //     gbuffer; gives surfaces a subtle sheen instead of flat diffuse. ---
    vec3 H = normalize(L + V);
    float spec = pow(saturate(dot(worldN, H)), 24.0);
    direct += sunCol * spec * shadow * lightStr * 0.25 * NdotL;

    // --- Subsurface scattering for foliage: grass & leaves glow when the sun
    //     is behind them. Cheap wrap-lighting based on view-vs-light alignment.
    if (isFoliage > 0.5) {
        float back = saturate(dot(-V, L));               // looking toward sun
        float sss = pow(back, 3.0) * (0.4 + 0.6 * NdotL); // also lit when edge-on
        direct += sunCol * sss * shadow * lightStr * 0.9;
    }

    // --- Sky ambient (hemisphere): brighter from above, but with generous
    //     floors so shadowed sides never crush to black. ---
    float hemi = worldN.y * 0.5 + 0.5;
    vec3 ambient = ambientColor() * mix(0.78, 1.0, hemi) * AMBIENT_STRENGTH;
    // Modulate by sky access so caves still darken, but keep a daylight floor.
    ambient *= mix(0.45, 1.0, lm.y);

#ifdef AO_ENABLED
    // Lightmap-based ambient occlusion approximation (sky access as a proxy).
    float ao = mix(0.75, 1.0, smoothstep(0.0, 0.4, lm.y));
    ambient *= ao;
#endif

    // Small flat bounce term so fully-shadowed daylight surfaces keep readable
    // detail instead of going black.
    ambient += ambientColor() * 0.10 * lm.y * timeBlend();

    // --- Block light (torches): warm, falls off, slight flicker. ---
    float flicker = 0.92 + 0.08 * sin(frameTimeCounter * 11.0 + worldPos.x * 3.0);
    vec3 blockLight = vec3(1.0, 0.62, 0.30) * pow(lm.x, 1.6) * 1.6 * flicker;

    // --- Combine ---
    vec3 lighting = direct + ambient + blockLight;
    vec3 color = albedo * lighting;

    // Cheap color bleed: the ambient bounce picks up a touch of the surface's
    // own color, so grass reads greener, sand warmer, etc. (one extra mul).
    color += albedo * albedo * ambient * 0.25;

    // Subtle rim from the sky for nicer silhouettes.
    float rim = pow(1.0 - saturate(dot(worldN, V)), 4.0);
    color += ambientColor() * rim * 0.06 * lm.y;

    gl_FragData[0] = vec4(color, 1.0);
}
