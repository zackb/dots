#version 440

// Pixelate: both images dissolve through ever-larger blocks that peak at
// the midpoint, then resolve crisply into the new wallpaper.
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
    float d     = min(progress, 1.0 - progress);   // 0 at ends, 0.5 at middle
    float steps = 32.0;
    float dist  = ceil(d * steps) / steps;         // quantised block growth

    vec2 minSquares = vec2(24.0);
    vec2 squareSize = 2.0 * dist / minSquares;

    vec2 uv = squareSize.x > 0.0
        ? (floor(qt_TexCoord0 / squareSize) + 0.5) * squareSize
        : qt_TexCoord0;

    fragColor = mix(texture(fromTex, uv),
                    texture(toTex,   uv), progress) * qt_Opacity;
}
