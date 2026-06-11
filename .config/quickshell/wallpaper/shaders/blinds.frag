#version 440

// Venetian blinds: the screen is split into horizontal strips that each open
// with a small soft wipe, revealing the new wallpaper behind them.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float progress;
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

void main() {
    const float strips = 14.0;
    float local = fract(qt_TexCoord0.y * strips);   // 0..1 within each strip

    float edge = 0.18;
    float p    = progress * (1.0 + 2.0 * edge) - edge;
    float wTo  = 1.0 - smoothstep(p - edge, p + edge, local);

    fragColor = mix(texture(fromTex, qt_TexCoord0),
                    texture(toTex,   qt_TexCoord0), wTo) * qt_Opacity;
}
