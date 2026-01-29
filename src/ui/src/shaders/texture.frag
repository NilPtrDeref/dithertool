#version 330

precision mediump float;

uniform sampler2D uTexture;

in vec2 vTexCoord;
out vec4 out_color;

void main(void) {
  out_color = texture(uTexture, vTexCoord);
}
