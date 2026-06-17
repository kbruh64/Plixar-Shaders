#version 120
/*
    Plixar Shaders - gbuffers_textured.vsh
    Generic textured geometry (particles, hand, item frames, fallback path
    for entities/block-entities). No vertex animation.
*/

#include "/lib/common.glsl"

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 vColor;
varying vec3 vNormal;

void main() {
    gl_Position = ftransform();

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
    lmcoord  = (lmcoord * 33.05 / 32.0) - (1.05 / 32.0);

    vColor  = gl_Color;
    vNormal = normalize(gl_NormalMatrix * gl_Normal);
}
