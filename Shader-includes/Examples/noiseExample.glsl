#include "Examples/worleyNoise.glsl"

uniform float time;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    return color * vec4(1.0 - worley(vec3(screen_coords / 50.0, time), 1.0, false).xxx,1.0);
}