#version 130

//---	UNIFORMS	---//

uniform sampler2D	unit_depth;
uniform sampler2D	unit_g0, unit_g1, unit_g2;
uniform sampler2D	unit_light;

uniform struct Spatial	{
	vec4 pos,rot;
}s_cam;

uniform vec4 screen_size, proj_cam, proj_lit;
uniform vec4 lit_color, lit_data;


//---	LIGHT MODEL	---//
float comp_diffuse(vec3,vec3);
float comp_specular(vec3,vec3,vec3,float);

//---	TRANSFORM	---//
vec3 trans_for2(vec3,Spatial);
vec3 trans_inv2(vec3,Spatial);

//---	TOOLS		---//
vec3 unproject(vec3,vec4);
float get_attenuation2(float);

//---	VARYINGS	---//
flat in Spatial s_light;
out vec4 rez_color;


//---	MAIN	---//

void main()	{
	//extract world & light space
	vec2 tc = gl_FragCoord.xy / screen_size.xy;
	float depth = texture(unit_depth,tc).r;
	vec3 p_camera	= unproject( vec3(tc,depth), proj_cam );
	vec3 p_world	= trans_for2(p_camera, s_cam);
	vec3 p_light	= trans_inv2(p_world, s_light);
	
	//read G-buffer
	vec4 g_diffuse	= texture(unit_g0,tc);
	vec4 g_specular	= texture(unit_g1,tc);
	vec4 g_normal	= texture(unit_g2,tc);
	// no normalization needed for 1-to-1 G-buffer
	vec3 normal = 2.0*g_normal.xyz - vec3(1.0);	//world space
	
	//compute light contribution
	vec3 v_lit = s_light.pos.xyz - p_world;
	vec3 v2lit = normalize( v_lit );
	vec3 v2cam = normalize( s_cam.pos.xyz - p_world );
	float diff = comp_diffuse(  normal, v2lit );
	float spec = comp_specular( normal, v2lit, v2cam, 100.0*g_normal.w );
	
	//write attenuated color
	float intensity = get_attenuation2( length(v_lit) );
	//no need for discard, because we are drawing a sphere with depth test
	//if( intensity*(diff+spec) < 0.01 ) discard;
	rez_color = intensity*lit_color * (diff * g_diffuse + spec * g_specular);
}