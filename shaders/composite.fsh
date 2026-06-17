#version 120
/*
    Plixar Shaders - composite.fsh
    Atmospheric stage applied over the fully-shaded scene (opaque + water):
        - height + distance fog tinted by the sky toward the sun
        - volumetric light shafts (god rays) marched in screen space toward
          the sun, occluded by the depth buffer
        - underwater tint when the eye is in water
*/

#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/space.glsl"
#include "/lib/sky.glsl"

varying vec2 texcoord;

/* DRAWBUFFERS:0 */
void main() {
    vec3 color = texture2D(colortex0, texcoord).rgb;

    // If fog, god rays and water/lava tint are all off, this whole pass is a
    // straight copy -- bail before the expensive position reconstruction.
#if !defined FOG_ENABLED && !defined GODRAYS_ENABLED
    if (isEyeInWater == 0) {
        gl_FragData[0] = vec4(color, 1.0);
        return;
    }
#endif

    float depth = texture2D(depthtex0, texcoord).r;

    vec3 viewPos  = screenToView(texcoord, depth);
    float dist    = length(viewPos);
    vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * normalize(viewPos));

    // --------------------------------------------------------------------
    //  Fog
    // --------------------------------------------------------------------
#ifdef FOG_ENABLED
    if (depth < 1.0) {
        // Distance fog (exponential-squared).
        float fogStart = far * 0.55;
        float fogEnd   = far * 0.95;
        float dFog = saturate((dist - fogStart) / max(fogEnd - fogStart, EPS));
        dFog = 1.0 - exp(-dFog * dFog * 3.0 * FOG_DENSITY);

        // Height fog (thicker low to the ground / over water).
        vec3 worldPos = viewToWorld(viewPos) + cameraPosition;
        float h = worldPos.y;
        float heightFog = saturate(exp(-(h - 48.0) * 0.06));
        heightFog *= saturate(dist / (far * 0.25));
        heightFog *= 0.5 * FOG_DENSITY;

        float fog = saturate(dFog + heightFog);

        // Fog color: cheap sky gradient, tinted toward the sun for a warm
        // horizon. (skyGradient skips discs/stars -- invisible behind fog.)
        vec3 fColor = skyGradient(worldDir);
        float toSun = saturate(dot(worldDir, getSunDir()));
        fColor = mix(fColor, sunlightColor(), pow(toSun, 4.0) * 0.4 * timeBlend());

        color = mix(color, fColor, fog);
    }
#endif

    // --------------------------------------------------------------------
    //  Volumetric god rays (screen-space march toward the sun)
    // --------------------------------------------------------------------
#ifdef GODRAYS_ENABLED
    vec3 sunView = normalize(sunPosition);
    vec4 sunClip = gbufferProjection * vec4(sunView * far, 1.0);
    if (sunClip.w > 0.0) {
        vec2 sunUv = (sunClip.xy / sunClip.w) * 0.5 + 0.5;
        float sunVisible = step(0.0, sunView.z) * timeBlend();

        if (sunVisible > 0.0) {
            vec2 delta = (sunUv - texcoord);
            float len = length(delta);
            // Skip if the sun is far off-screen (perf + avoids streaks).
            if (len < 1.6) {
                int samples = GODRAYS_SAMPLES;
                vec2 marchStep = delta / float(samples) * 0.85;
                vec2 uv = texcoord;
                float decay = 1.0;
                float accum = 0.0;
                float jitter = ign(gl_FragCoord.xy + frameTimeCounter);
                uv += marchStep * jitter;

                for (int i = 0; i < samples; i++) {
                    uv += marchStep;
                    // Explicit bounds test (AMD GLSL is happier than with
                    // a vec != vec comparison).
                    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) break;
                    float d = texture2D(depthtex0, uv).r;
                    accum += (d >= 1.0 ? 1.0 : 0.0) * decay;
                    decay *= 0.96;
                }
                accum /= float(samples);

                // Brighten toward the sun direction and fade with distance.
                float falloff = saturate(1.0 - len / 1.6);
                vec3 rayCol = sunlightColor() * accum * falloff * sunVisible;
                color += rayCol * 0.9;
            }
        }
    }
#endif

    // --------------------------------------------------------------------
    //  Underwater tint
    // --------------------------------------------------------------------
    if (isEyeInWater == 1) {
        vec3 waterFog = vec3(0.05, 0.22, 0.30);
        float u = 1.0 - exp(-dist * 0.18);
        color = mix(color, waterFog, u);
        color *= vec3(0.7, 0.9, 1.0); // blue absorption
    } else if (isEyeInWater == 2) {
        // Lava
        color = mix(color, vec3(0.85, 0.30, 0.06), 1.0 - exp(-dist * 1.5));
    }

    gl_FragData[0] = vec4(color, 1.0);
}
