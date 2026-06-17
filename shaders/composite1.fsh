#version 120
/*
    Plixar Shaders - composite1.fsh
    Bloom: bright-pass extraction + a wide gaussian blur, written to colortex3.
    Sampled at reduced effective radius so it stays cheap. Combined in final.
*/

#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;

vec3 brightPass(vec2 uv) {
    vec3 c = texture2D(colortex0, uv).rgb;
    float l = luma(c);
    // Soft-knee threshold around 1.0 (HDR scene values).
    float knee = smoothstep(0.7, 1.4, l);
    return c * knee;
}

/* DRAWBUFFERS:3 */
void main() {
#ifdef BLOOM_ENABLED
    // Wide, cheap bloom: ring samples cover a big radius with few taps. This
    // pass runs at half resolution (see size.buffer.colortex3) and linear
    // filtering smooths it further, so 2 rings x 6 steps (13 taps) is plenty.
    vec2 px = texelSize * 3.0;
    vec3 sum = brightPass(texcoord);
    float wsum = 1.0;

    const int RINGS = 2;
    const int STEPS = 6;
    for (int r = 1; r <= RINGS; r++) {
        float radius = float(r) * 2.0;
        float ringW = 1.0 / float(r);
        for (int s = 0; s < STEPS; s++) {
            float a = (float(s) / float(STEPS)) * TAU + float(r) * 0.6;
            vec2 o = vec2(cos(a), sin(a)) * radius;
            sum += brightPass(texcoord + o * px) * ringW;
            wsum += ringW;
        }
    }
    gl_FragData[0] = vec4(sum / wsum, 1.0);
#else
    gl_FragData[0] = vec4(0.0);
#endif
}
