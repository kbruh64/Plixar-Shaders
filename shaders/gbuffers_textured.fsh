#version 120
/*
    Plixar Shaders - gbuffers_textured.fsh
    Generic textured geometry writing into the same gbuffer layout as terrain.
*/

#include "/lib/common.glsl"

uniform sampler2D texture;

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vColor;
varying vec3 vNormal;

/* DRAWBUFFERS:012 */
void main() {
    vec4 albedo = texture2D(texture, texcoord) * vColor;
    if (albedo.a < 0.1) discard;

    gl_FragData[0] = vec4(albedo.rgb, 1.0);

    vec3 n = normalize(vNormal) * 0.5 + 0.5;
    gl_FragData[1] = vec4(n, 0.0);

    gl_FragData[2] = vec4(lmcoord, 0.9, 1.0);
}
