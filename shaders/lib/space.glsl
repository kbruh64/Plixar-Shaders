/*
    Plixar Shaders - space.glsl
    Coordinate-space conversions: screen <-> view <-> world.
    Requires uniforms.glsl.
*/

#ifndef PLIXAR_SPACE
#define PLIXAR_SPACE

// Linearize hardware depth (0..1) into view-space distance.
float linearizeDepth(float depth) {
    return (2.0 * near * far) / (far + near - (depth * 2.0 - 1.0) * (far - near));
}

// Screen UV + depth -> view space position.
vec3 screenToView(vec2 uv, float depth) {
    vec4 ndc = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * ndc;
    return view.xyz / view.w;
}

// View space -> screen UV (for SSR / reprojection).
vec3 viewToScreen(vec3 viewPos) {
    vec4 clip = gbufferProjection * vec4(viewPos, 1.0);
    vec3 ndc = clip.xyz / clip.w;
    return ndc * 0.5 + 0.5;
}

// View space -> world space (camera-relative; add cameraPosition for absolute).
vec3 viewToWorld(vec3 viewPos) {
    return (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
}

vec3 worldToView(vec3 worldPos) {
    return (gbufferModelView * vec4(worldPos, 1.0)).xyz;
}

// World-space (camera relative) -> shadow clip space, with distortion applied.
vec3 worldToShadow(vec3 worldPos) {
    vec4 sv = shadowModelView * vec4(worldPos, 1.0);
    vec4 sc = shadowProjection * sv;
    return sc.xyz / sc.w;
}

// Shadow map distortion — packs nearby texels at higher resolution.
vec2 distortShadow(vec2 pos) {
    float d = length(pos);
    float distort = mix(1.0, d, 0.9) + 0.04;
    return pos / distort;
}

#endif // PLIXAR_SPACE
