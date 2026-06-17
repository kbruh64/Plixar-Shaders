#version 120
/*
    Plixar Shaders - gbuffers_skytextured.fsh
    We draw our own analytic sun & moon in the procedural sky, so the vanilla
    sun/moon textures are discarded to avoid a doubled sun. Custom skies and
    the end/nether sky still come through.
*/

uniform sampler2D texture;
uniform int renderStage; // Iris: identifies sun/moon vs custom sky

varying vec2 texcoord;
varying vec4 vColor;

/* DRAWBUFFERS:0 */
void main() {
    vec4 col = texture2D(texture, texcoord) * vColor;

    // Drop the vanilla sun/moon quads; keep everything else.
    // renderStage == MC_RENDER_STAGE_SUN / _MOON when available.
    #if defined MC_RENDER_STAGE_SUN && defined MC_RENDER_STAGE_MOON
        if (renderStage == MC_RENDER_STAGE_SUN || renderStage == MC_RENDER_STAGE_MOON) discard;
    #endif

    if (col.a < 0.01) discard;
    gl_FragData[0] = col;
}
