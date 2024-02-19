varying vec3 vColor;
#ifdef VERTEX
attribute vec2 InstancePosition;
attribute vec3 InstanceColor;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vColor = InstanceColor;
    return transform_projection * vec4(vertex_position.xy + InstancePosition.xy, vertex_position.zw);
}
#endif
#ifdef PIXEL
vec4 effect(vec4 love_Color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    return love_Color * vec4(vColor, 1.0);
}
#endif