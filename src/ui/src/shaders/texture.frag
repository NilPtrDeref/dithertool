#version 330

precision mediump float;

uniform sampler2D Texture;

in vec2 TextureCoord;
out vec4 FragColor;

void main(void) {
  FragColor = texture(Texture, TextureCoord);
}
