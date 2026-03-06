shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width = 2.0;
uniform float oscillation_speed = 2.0; // how fast the outline pulses
uniform float oscillation_amount = 1.0; // max deviation from outline_width

void vertex() {
    // Calculate oscillating width
    float dynamic_width = outline_width + sin(TIME * oscillation_speed) * oscillation_amount;

    vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
    vec3 clip_normal = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
    
    vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * clip_position.w * dynamic_width * 2.0;
    
    clip_position.xy += offset;
    
    POSITION = clip_position;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    if (outline_color.a < 1.0) {
        ALPHA = outline_color.a;
    }
}