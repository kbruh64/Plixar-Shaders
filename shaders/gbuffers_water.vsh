#version 120
/*
    Plixar Shaders - gbuffers_water.vsh
    Translucent geometry: water (with gerstner-ish waves), stained glass, ice.
*/

#include "/lib/common.glsl"

uniform float frameTimeCounter;
uniform vec3  cameraPosition;
uniform mat4  gbufferModelView;
uniform mat4  gbufferModelViewInverse;

attribute vec4 mc_Entity;

varying vec2  texcoord;
varying vec2  lmcoord;
varying vec4  vColor;
varying vec3  vNormal;
varying vec3  viewPos;
varying vec3  worldPos;
varying float isWater;

// Sum-of-sines height field for the water surface.
float waveHeight(vec2 p, float t) {
    float h = 0.0;
    h += sin(dot(p, vec2(0.6, 0.8)) + t * 1.1) * 0.06;
    h += sin(dot(p, vec2(-0.7, 0.5)) + t * 1.7) * 0.04;
    h += sin(dot(p, vec2(0.2, -0.9)) + t * 2.3) * 0.025;
    return h;
}

void main() {
    vec4 pos = gl_Vertex;
    isWater = (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) ? 1.0 : 0.0;

    vec4 wp = gbufferModelViewInverse * (gl_ModelViewMatrix * pos);
    vec3 wpos = wp.xyz + cameraPosition;
    worldPos = wp.xyz;

#ifdef WATER_WAVES
    if (isWater > 0.5) {
        float t = frameTimeCounter;
        float h = waveHeight(wpos.xz, t);
        // Displace along world up; convert back into the current MV space.
        vec4 disp = gbufferModelView * vec4(0.0, h, 0.0, 0.0);
        vec4 vp = gl_ModelViewMatrix * pos + disp;
        viewPos = vp.xyz;
        gl_Position = gl_ProjectionMatrix * vp;
    } else
#endif
    {
        vec4 vp = gl_ModelViewMatrix * pos;
        viewPos = vp.xyz;
        gl_Position = gl_ProjectionMatrix * vp;
    }

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
    lmcoord  = (lmcoord * 33.05 / 32.0) - (1.05 / 32.0);

    vColor  = gl_Color;
    vNormal = normalize(gl_NormalMatrix * gl_Normal);
}
