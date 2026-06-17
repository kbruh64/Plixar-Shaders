#version 120
/*
    Plixar Shaders - gbuffers_terrain.fsh
    Writes albedo (HDR-ready), packed normals + material id, and the lightmap
    into the gbuffer for deferred lighting.
*/

#include "/lib/common.glsl"

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec2  texcoord;
varying vec2  lmcoord;
varying vec4  vColor;
varying vec3  vNormal;
varying vec3  viewPos;
varying float materialId;

/* DRAWBUFFERS:012 */
void main() {
    vec4 albedo = texture2D(texture, texcoord) * vColor;

    // Alpha test for cutout (leaves, grass, etc.)
    if (albedo.a < 0.1) discard;

    // Store albedo in sRGB; deferred pass converts to linear for lighting.
    gl_FragData[0] = vec4(albedo.rgb, 1.0);

    // Encode view-space normal to [0,1] and pack material id in alpha.
    vec3 n = normalize(vNormal) * 0.5 + 0.5;
    gl_FragData[1] = vec4(n, materialId / 255.0);

    // Lightmap (block.x, sky.y), a small roughness guess, flags.
    float rough = 0.85;
    gl_FragData[2] = vec4(lmcoord, rough, 1.0); // a=1 marks "lit by deferred"
}
