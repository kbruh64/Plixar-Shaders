#version 120
/*
    Plixar Shaders - gbuffers_terrain.vsh
    Solid + cutout terrain. Applies subtle wind sway to foliage and writes
    the data the deferred lighting pass needs.
*/

#include "/lib/common.glsl"

uniform float frameTimeCounter;
uniform float rainStrength;
uniform vec3  cameraPosition;
uniform mat4  gbufferModelView;
uniform mat4  gbufferModelViewInverse;

attribute vec4 mc_Entity;       // x = block id
attribute vec3 mc_midTexCoord;  // for foliage pivot detection

varying vec2  texcoord;
varying vec2  lmcoord;
varying vec4  vColor;
varying vec3  vNormal;          // view-space normal
varying vec3  viewPos;
varying float materialId;       // 0 = generic, 1 = foliage, 2 = leaves

void main() {
    vec4 pos = gl_Vertex;

    // World position for wind phase.
    vec4 worldPos = gbufferModelViewInverse * (gl_ModelViewMatrix * pos);
    vec3 wp = worldPos.xyz + cameraPosition;

    float id = mc_Entity.x;
    materialId = 0.0;

    // 31/175 = vanilla tallgrass/plants; 18/161 = leaves (approx ids).
    bool isPlant  = (id == 31.0 || id == 59.0 || id == 175.0 || id == 83.0);
    bool isLeaves = (id == 18.0 || id == 161.0);

    if (isPlant || isLeaves) {
        materialId = isLeaves ? 2.0 : 1.0;

        // Only sway the top of the plant (verts above their mid-tex pivot).
        float topMask = isLeaves ? 1.0 : step(mc_midTexCoord.t, gl_MultiTexCoord0.t);
        float t = frameTimeCounter;
        float phase = dot(wp.xz, vec2(0.7, 0.9)) + t * 1.6;
        vec2 sway;
        sway.x = sin(phase) + 0.4 * sin(phase * 2.3 + 1.0);
        sway.y = cos(phase * 0.8 + 2.0);
        float amp = (isLeaves ? 0.035 : 0.08) * topMask;
        amp *= (1.0 + rainStrength * 1.5);
        pos.xyz += vec3(sway.x, 0.0, sway.y) * amp;
    }

    vec4 vp = gl_ModelViewMatrix * pos;
    viewPos = vp.xyz;
    gl_Position = gl_ProjectionMatrix * vp;

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
    lmcoord  = (lmcoord * 33.05 / 32.0) - (1.05 / 32.0);

    vColor = gl_Color;
    vNormal = normalize(gl_NormalMatrix * gl_Normal);
}
