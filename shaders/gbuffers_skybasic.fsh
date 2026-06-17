#version 120
/*
    Plixar Shaders - gbuffers_skybasic.fsh
    Procedural atmospheric sky replacing the vanilla gradient/void.
*/

#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/sky.glsl"

varying vec3 viewDir;

/* DRAWBUFFERS:0 */
void main() {
    vec3 dir = normalize(mat3(gbufferModelViewInverse) * normalize(viewDir));
    vec3 sky = computeSky(dir);
    gl_FragData[0] = vec4(sky, 1.0);
}
