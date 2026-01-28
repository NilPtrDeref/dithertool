#version 330

precision mediump float;

uniform sampler2D tex;

in vec2 vTexCoord;
out vec4 out_color;

void main(void) {
  out_color = texture(tex, vTexCoord);
}
