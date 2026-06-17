#version 120
/*
    Plixar Shaders - shadow.vsh
    Renders the scene from the sun's POV into the shadow map. Applies the same
    foliage sway as the main pass and the shadow-map distortion so near texels
    get more resolution.
*/

#include "/lib/common.glsl"

uniform float frameTimeCounter;
uniform float rainStrength;
uniform vec3  cameraPosition;
uniform mat4  shadowModelView;
uniform mat4  shadowModelViewInverse;

attribute vec4 mc_Entity;
attribute vec3 mc_midTexCoord;

varying vec2 texcoord;
varying vec4 vColor;

// Must match distortShadow() in space.glsl.
vec2 distortShadowClip(vec2 pos) {
    float d = length(pos);
    float distort = mix(1.0, d, 0.9) + 0.04;
    return pos / distort;
}

void main() {
#ifndef SHADOWS_ENABLED
    // Shadows off: collapse everything to a degenerate clip position so the
    // shadow map rasterizes nothing. Cheapest possible shadow pass.
    texcoord = vec2(0.0);
    vColor = vec4(0.0);
    gl_Position = vec4(2.0, 2.0, 2.0, 1.0); // outside [-w,w] on every axis
    return;
#endif

    vec4 pos = gl_Vertex;

    vec4 wp = shadowModelViewInverse * (gl_ModelViewMatrix * pos);
    vec3 wpos = wp.xyz + cameraPosition;

    float id = mc_Entity.x;
    bool isPlant  = (id == 31.0 || id == 59.0 || id == 175.0 || id == 83.0);
    bool isLeaves = (id == 18.0 || id == 161.0);

    if (isPlant || isLeaves) {
        float topMask = isLeaves ? 1.0 : step(mc_midTexCoord.t, gl_MultiTexCoord0.t);
        float t = frameTimeCounter;
        float phase = dot(wpos.xz, vec2(0.7, 0.9)) + t * 1.6;
        vec2 sway = vec2(sin(phase) + 0.4 * sin(phase * 2.3 + 1.0),
                         cos(phase * 0.8 + 2.0));
        float amp = (isLeaves ? 0.035 : 0.08) * topMask * (1.0 + rainStrength * 1.5);
        pos.xyz += vec3(sway.x, 0.0, sway.y) * amp;
    }

    vec4 p = gl_ModelViewMatrix * pos;
    p = gl_ProjectionMatrix * p;

    // Apply distortion in clip space.
    p.xy = distortShadowClip(p.xy);
    gl_Position = p;

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    vColor = gl_Color;
}
