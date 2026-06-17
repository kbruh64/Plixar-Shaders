#version 120
/*
    Plixar Shaders - composite.vsh
    Fullscreen pass.
*/

varying vec2 texcoord;

void main() {
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.st;
}
