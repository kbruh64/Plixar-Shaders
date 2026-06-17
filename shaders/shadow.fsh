#version 120
/*
    Plixar Shaders - shadow.fsh
    Writes shadow depth, and a colored shadow buffer so translucent blockers
    (water, stained glass) tint the sunlight instead of fully blocking it.
*/

#include "/lib/common.glsl"

uniform sampler2D texture;

varying vec2 texcoord;
varying vec4 vColor;

/* DRAWBUFFERS:0 */
void main() {
    vec4 col = texture2D(texture, texcoord) * vColor;
    if (col.a < 0.1) discard;

    // For opaque geometry, store white (no tint). For translucents the alpha
    // here lets the lighting pass blend the tint in.
    gl_FragData[0] = vec4(col.rgb, col.a);
}
