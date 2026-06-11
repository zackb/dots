#version 440

// Iris reveal: the new wallpaper grows out of the centre as a circle.
// `aspect` (width/height) keeps the iris circular on wide displays.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspect;
};

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

void main() {
    vec2  d       = vec2((qt_TexCoord0.x - 0.5) * aspect, qt_TexCoord0.y - 0.5);
    float dist    = length(d);
    float maxDist = length(vec2(0.5 * aspect, 0.5));

    float edge = 0.05 * maxDist;
    float r    = progress * (maxDist + 2.0 * edge) - edge;
    float wTo  = 1.0 - smoothstep(r - edge, r + edge, dist);

    fragColor = mix(texture(fromTex, qt_TexCoord0),
                    texture(toTex,   qt_TexCoord0), wTo) * qt_Opacity;
}
