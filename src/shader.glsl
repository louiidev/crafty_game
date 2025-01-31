@header package main
@header import sg "../sokol/gfx"


//
// VERTEX SHADER
//
@vs vs
in vec2 position;
in vec4 color0;
in vec2 uv0;
in float tex_id;
in float flash_amount;

out vec4 color;
out vec2 uv;
out float v_tex_id;
out float v_flash_amount;

void main() {
    gl_Position = vec4(position.xy, 0, 1);
    color = color0;
    uv = uv0;
    v_tex_id = tex_id;
    v_flash_amount = flash_amount;
}
@end


//
// FRAGMENT SHADER
//
@fs fs
layout(binding=0) uniform texture2D tex0;
layout(binding=1) uniform texture2D tex1;
layout(binding=0) uniform sampler default_sampler;

in vec4 color;
in vec2 uv;
in float v_tex_id;
in float v_flash_amount;

out vec4 col_out;

void main() {
    vec4 tex_col = vec4(1.0);

    int tex_index = 0.5f > v_tex_id ? 0 : 1;

    if (tex_index == 0) {
        tex_col = texture(sampler2D(tex0, default_sampler), uv);
        if (v_flash_amount == 1 && tex_col.a > 0 && tex_col.a != 90.0 / 255.0) {
            vec4 whiteColor = vec4(1, 1, 1, 1);
            col_out = whiteColor;
        } else {
            col_out = tex_col;
            col_out *= color;
        }

    } else {
        tex_col.a = texture(sampler2D(tex1, default_sampler), uv).r;
        col_out = tex_col;
        col_out *= color;
    }

}
@end

@program quad vs fs
