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

    // Fog now lives in the deferred pass. This stage only does god rays and the
    // underwater/lava tint, so when god rays are off and the eye is in air it's
    // a straight copy -- bail before any expensive work. On the Fast/Low-End
    // profiles this whole pass is essentially free.
#ifndef GODRAYS_ENABLED
    if (isEyeInWater == 0) {
        gl_FragData[0] = vec4(color, 1.0);
        return;
    }
#endif

    float depth = texture2D(depthtex0, texcoord).r;

    vec3 viewPos  = screenToView(texcoord, depth);
    float dist    = length(viewPos);

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
