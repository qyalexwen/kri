#version 130
precision lowp float;

uniform vec4 lit_attenu;

//light attenuation, blender model
float get_attenuation(float d)	{
	vec3 a = vec3(1.0) + lit_attenu.wyz * vec3(-d,d,d*d);
	//x: spherical, y :linear, z: quadratic
	return a.x * lit_attenu.x / (a.y*a.z);
}

//perspective project
vec4 get_projection(vec3 v, vec4 pr)	{
	//float w = -v.z*pr.w, z1 = (v.z+pr.x)*pr.z;
	//return vec4( v.xy, z1*w, w );
	return vec4( v.xy * pr.xy, v.z*pr.z + pr.w, -v.z);
}

//perspective depth only
float get_proj_depth(float d, vec4 pr)	{
	return -pr.z - pr.w/d;
}