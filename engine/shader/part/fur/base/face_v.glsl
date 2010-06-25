#version 130
//#define INT

uniform sampler2D unit_vert, unit_quat;
uniform int width;

void set_base(vec4,vec4);


void main()	{
	#ifdef INT
	int yc = gl_VertexID / width;
	ivec2 tc = ivec2(gl_VertexID - yc*width, yc);
	vec4 vert = texelFetch(unit_vert,tc,0);
	vec4 quat = texelFetch(unit_quat,tc,0);
	#else
	int cy = gl_VertexID / width,
		cx = gl_VertexID - cy*width;
	float dw = 1.0 / width;
	vec2 tc = (ivec2(cx,cy) + vec2(0.5)) * dw;
	vec4 vert = texture(unit_vert,tc);
	vec4 quat = texture(unit_quat,tc);
	#endif
	set_base(vert,quat);
}