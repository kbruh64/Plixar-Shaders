#version 120
/*
    Plixar Shaders - gbuffers_skytextured.vsh
    Sun / moon / custom sky textures.
*/

varying vec2 texcoord;
varying vec4 vColor;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    vColor = gl_Color;
}
