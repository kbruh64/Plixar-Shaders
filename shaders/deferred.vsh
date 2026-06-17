#version 120
/*
    Plixar Shaders - deferred.vsh
    Fullscreen pass vertex shader (shared by deferred + composite stages).
*/

varying vec2 texcoord;

void main() {
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.st;
}
