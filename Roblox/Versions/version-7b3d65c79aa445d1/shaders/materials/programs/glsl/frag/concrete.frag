
// Defines to convert Cg to GLSL
#define float2 vec2
#define float3 vec3
#define float4 vec4
#define float2x2 mat2
#define float3x3 mat3
#define float4x4 mat4
#define tex2D texture2D
#define lerp(x,y,z) mix(x,y,z)
#define mul(x,y) (x * y)
#define atan2(x,y) atan(y,x)
#define saturate(x) clamp(x,0.0,1.0)
#define frac(x) (x - floor(x))
#define samplerCUBE samplerCube
#define texCUBE textureCube

#define UNIFORM_PARAMETER
#define SAMPLER_IN in


struct vertexOutputSimple {
    float4 HPosition;
    float4 DiffuseContrib;
    float3 ModelUV;
    float3 Light0Vec;
    float3 WorldNormal;
    float4 WorldView; // w - view space depth for SSAO
    float3 SurfaceFresnel; // z = frensel
};

float YfromRGB(float3 color)
{
	return dot(color, float3(0.299, 0.587, 0.114));
}

float4 lit( float NdotL, float NdotH, float m)
{
	float specular = (NdotL > 0.0) ? pow(max(0.0, NdotH), m) : 0.0;
	return float4(1.0, max(0.0, NdotL), specular, 1.0);
}

float4 packDeferred(float depth, float3 diffuse, float3 specular)
{
	float4 result;

	const float3 bitSh	= float3( 255.0*255.0, 255.0, 1.0);

	const float2 bitMsk = float2( 1.0/255.0,  1.0/255.0);

	result.r = YfromRGB(specular);
	result.g = YfromRGB(diffuse);


	float2 comp;
	depth = saturate(depth);
/*	float fracpart = frac(depth*255);

	comp.x = depth - fracpart/255;
	comp.y = fracpart*256.0f/255.0f;

	comp.y -= frac(fracpart*256)/255;*/

	comp = depth*float2(255.0,255.0*256.0);
	comp = frac(comp);

	comp = float2(depth,comp.x*256.0/255.0) - float2(comp.x, comp.y)/255.0;

	result.ba = comp.yx;

	return result;
}

void ps_shared_lighting(
		float3 DiffuseColor,
		float3 WorldNormal,
		float3 WorldView,
		float3 Light0Vec,
		float3 Light1Vec,
		float3 Lamp0Color,
		float3 Lamp1Color,
		float3 AmbiColor,
		float Ks,
		float SpecExpon,
		out float3 DiffuseContrib,
		out float3 SpecularContrib
		)
{
    float3 Nn = normalize(WorldNormal);
    float3 Vn = normalize(WorldView);
    float3 Ln0 = normalize(Light0Vec);
    float3 Ln1 = normalize(Light1Vec);
    float3 Hn0 = normalize(Vn + Ln0);

    float hdn0 = dot(Hn0,Nn);
    float ldn0 = dot(Ln0,Nn);
    float ldn1 = dot(Ln1,Nn);

    float4 lit0V = lit(ldn0,hdn0,SpecExpon);
    float lit1Vy = saturate(ldn1); // don't do specular calculations for second light.
    DiffuseContrib = DiffuseColor * ( lit0V.y*Lamp0Color + lit1Vy*Lamp1Color + AmbiColor);
    SpecularContrib = Ks * (lit0V.z * Lamp0Color);
}

void ps_shared_lighting_env(
		float3 DiffuseColor,
		float3 WorldNormal,
		float3 WorldView,
		float3 Light0Vec,
		float3 Light1Vec,
		float3 Lamp0Color,
		float3 Lamp1Color,
		float3 AmbiColor,
		float Ks,
		float SpecExpon,
		float Kr,
		out float3 DiffuseContrib,
		out float3 SpecularContrib,
		SAMPLER_IN samplerCUBE EnvSampler,
		out float3 ReflectionContrib
		)
{
    float3 Nn = normalize(WorldNormal);
    float3 Vn = normalize(WorldView);
    float3 Ln0 = normalize(Light0Vec);
    float3 Ln1 = normalize(Light1Vec);
    float3 Hn0 = normalize(Vn + Ln0);
    float hdn0 = dot(Hn0,Nn);
    float ldn0 = dot(Ln0,Nn);
    float ldn1 = dot(Ln1,Nn);
    float4 lit0V = lit(ldn0,hdn0,SpecExpon);
    float lit1Vy = saturate(ldn1); // don't do specular calculations for second light.
    DiffuseContrib = DiffuseColor * ( lit0V.y*Lamp0Color + lit1Vy*Lamp1Color + AmbiColor);
    SpecularContrib = Ks * (lit0V.z * Lamp0Color);

    float3 reflVect = -reflect(Vn,Nn);
	float3 cubeSample = texCUBE( EnvSampler,reflVect).xyz;
    ReflectionContrib = saturate(Kr * cubeSample);
}

void ps_shared_lighting_env_specularonly(
		float3 WorldNormal,
		float3 WorldView,
		float3 Light0Vec,
		UNIFORM_PARAMETER float3 Lamp0Specular,
		UNIFORM_PARAMETER float Ks,
		UNIFORM_PARAMETER float SpecExpon,
		UNIFORM_PARAMETER float Kr,
		out float3 SpecularContrib,
		UNIFORM_PARAMETER SAMPLER_IN samplerCUBE EnvSampler,
		out float3 ReflectionContrib
		)
{
    float3 Nn = normalize(WorldNormal);
    float3 Vn = normalize(WorldView);
    float3 Ln0 = normalize(Light0Vec);
    float3 Hn0 = normalize(Vn + Ln0);
    float hdn0 = dot(Hn0,Nn);
    float ldn0 = dot(Ln0,Nn);
    float4 lit0V = lit(ldn0,hdn0,SpecExpon);
    SpecularContrib = Ks * float3(lit0V.z * Lamp0Specular);

#if ENABLE_REFLECTIONS
    float3 reflVect = -reflect(Vn,Nn);
	float3 cubeSample = texCUBE(EnvSampler,reflVect).xyz;
    ReflectionContrib = saturate(Kr * cubeSample);
#endif
}


void ConcreteFP(vertexOutputSimple IN,
		UNIFORM_PARAMETER float3 Lamp0Color,
		UNIFORM_PARAMETER float Ks,
		UNIFORM_PARAMETER float SpecExpon,
		UNIFORM_PARAMETER float Kr,
		UNIFORM_PARAMETER SAMPLER_IN sampler2D StudsSampler,
		UNIFORM_PARAMETER SAMPLER_IN sampler2D SurfaceSampler,
		UNIFORM_PARAMETER SAMPLER_IN samplerCUBE EnvSampler,
#if GBUFFER
		out float4 oColor1,
#endif
		out float4 oColor
)
{
#if ENABLE_STUDS
	float4 StudShade = tex2D(StudsSampler, IN.ModelUV.xy);
#endif

	float4 Concrete = 0.5* (tex2D(SurfaceSampler, IN.SurfaceFresnel.xy)*2.0-1.0);

    float3 specContrib;
    float3 reflContrib;
    float3 diffContrib;
    float3 result;

	float3 fresnel = IN.SurfaceFresnel;

	ps_shared_lighting_env_specularonly(
				IN.WorldNormal, IN.WorldView.xyz, IN.Light0Vec,
				Lamp0Color, // use lamp0Color as specular.
				Ks, SpecExpon, Kr,
				specContrib,
				EnvSampler,
				reflContrib);
#if ENABLE_STUDS
	diffContrib = lerp(IN.DiffuseContrib.xyz+Concrete.xyz, StudShade.xyz, StudShade.w);
#else
	diffContrib = IN.DiffuseContrib.xyz+Concrete.xyz;
#endif

	result = diffContrib + specContrib;
#if ENABLE_REFLECTIONS
	result = lerp(result, reflContrib, fresnel);
#endif

    oColor = float4(result,1); //IN.DiffuseContrib.w); // copy alpha out.

	//oColor = float4(Concrete.xyz, result.x);
#if GBUFFER
	oColor1 = packDeferred(IN.WorldView.w, diffContrib, specContrib);
#endif
}

uniform float3 Lamp0Color;
uniform float Ks;
uniform float SpecExpon;
uniform float Kr;
uniform sampler2D StudsSampler;
uniform sampler2D SurfaceSampler;
uniform samplerCUBE EnvSampler;
uniform float4 FogColour;
uniform float4 FogParams;

varying vec3 ModelUV;
varying vec3 Light0Vec;
varying vec3 WorldNormal;
varying vec4 WorldView;
varying vec3 SurfaceFresnel;

void main()
{
	vertexOutputSimple IN;
	IN.HPosition = gl_FragCoord;
	IN.DiffuseContrib = gl_Color;
	IN.ModelUV = ModelUV;
	IN.Light0Vec = Light0Vec;
	IN.WorldNormal = WorldNormal;
	IN.WorldView = WorldView;
	IN.SurfaceFresnel = SurfaceFresnel;

	float4 oColor = IN.DiffuseContrib;
#if GBUFFER
	float4 oColor1 = gl_SecondaryColor;
#endif

	ConcreteFP( IN,
		Lamp0Color,
		Ks,
		SpecExpon,
		Kr,
		StudsSampler,
		SurfaceSampler,
		EnvSampler,
#if GBUFFER
	oColor1,
#endif
	oColor );

	float fogAlpha = ( ( FogParams.z - (IN.WorldView.w*500.0) ) * FogParams.w );
	fogAlpha = clamp( fogAlpha, 0.0, 1.0 );

	gl_FragColor = mix( FogColour, oColor, fogAlpha );
#if GBUFFER
	oColor1 = mix( FogColour, oColor1, fogAlpha );
#endif
}
