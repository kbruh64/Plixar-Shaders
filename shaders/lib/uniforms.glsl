/*
    Plixar Shaders - uniforms.glsl
    Common uniforms shared across the deferred / composite passes.
*/

#ifndef PLIXAR_UNIFORMS
#define PLIXAR_UNIFORMS

uniform sampler2D colortex0;   // scene color (HDR)
uniform sampler2D colortex1;   // normals (RGB) + material id (A)
uniform sampler2D colortex2;   // lightmap (block.r, sky.g), roughness (b), flags (a)
uniform sampler2D colortex3;   // bloom / scratch buffer
uniform sampler2D depthtex0;   // scene depth (with translucents)
uniform sampler2D depthtex1;   // scene depth (opaque only)
uniform sampler2D noisetex;    // tiling noise

#ifdef SHADOWS_ENABLED
uniform sampler2D shadowtex0;      // shadow depth (all)
uniform sampler2D shadowtex1;      // shadow depth (opaque only)
uniform sampler2D shadowcolor0;    // colored shadow (stained glass / water tint)
#endif

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform vec3 fogColor;
uniform vec3 skyColor;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float wetness;
uniform float far;
uniform float near;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float sunAngle;
uniform int   worldTime;
uniform int   isEyeInWater;

#define texelSize vec2(1.0 / viewWidth, 1.0 / viewHeight)

#endif // PLIXAR_UNIFORMS
