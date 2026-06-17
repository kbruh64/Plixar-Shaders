#version 120
/*
    Plixar Shaders - gbuffers_skybasic.vsh
    Vanilla sky dome / void. We replace it with our procedural sky in the fsh.
*/

#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"

varying vec3 viewDir;

void main() {
    gl_Position = ftransform();
    // Reconstruct a view-space direction for this sky vertex.
    vec4 v = gbufferProjectionInverse * gl_Position;
    viewDir = v.xyz / v.w;
}
