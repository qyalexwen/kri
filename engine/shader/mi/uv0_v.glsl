#version 130
precision lowp float;

in vec2 at_tex0;

vec3 mi_uv0()	{
	return vec3(at_tex0,0.0);
}