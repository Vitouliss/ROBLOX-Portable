
// Defines to convert Cg to GLSL
#define float2 vec2
#define float3 vec3
#define float4 vec4
#define float2x2 mat2
#define float3x3 mat3
#define float4x4 mat4
#define tex2D texture2D
#define tex3D texture3D
#define lerp(x,y,z) mix(x,y,z)
#define mul(x,y) (x * y)
#define atan2(x,y) atan(y,x)
#define saturate(x) clamp(x,0.0,1.0)
#define frac(x) (x - floor(x))
#define samplerCUBE samplerCube
#define texCUBE textureCube
#define UNIFORM_PARAMETER
#define SAMPLER_IN in

struct VertexOutput
{
    float4 HPosition;
	float4 Color;
    float4 ModelUV;
    float4 TexPos3D; //  grain coordinate system
    								// coord w is attenuation 0 = no normal map, 1 = full normal map
    float3 Light0Vec;
    float3 Light1Vec;
    float3 WorldNormal;
    float3 WorldTangent;
    float4 WorldView; // w = depth value for SSAO
	float4 ObjectNormal;
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

void mainPSStuds(VertexOutput IN,
		UNIFORM_PARAMETER float3 Contrast,
		UNIFORM_PARAMETER float Ks,
		UNIFORM_PARAMETER float SpecExpon,
		UNIFORM_PARAMETER float3 Lamp0Color,
		UNIFORM_PARAMETER float3 Lamp1Color,
		UNIFORM_PARAMETER float3 AmbiColor,
		UNIFORM_PARAMETER float3 NoiseScale,
	    	UNIFORM_PARAMETER SAMPLER_IN sampler2D StudsSamp,
		UNIFORM_PARAMETER SAMPLER_IN sampler3D NoiseSamp,
		UNIFORM_PARAMETER SAMPLER_IN sampler2D NormalSamp,
		UNIFORM_PARAMETER SAMPLER_IN sampler2D grassSamp,
		UNIFORM_PARAMETER SAMPLER_IN sampler2D GrassNormalSamp,
#if GBUFFER
		out float4 oColor1,
#endif
		out float4 oColor
)
{
	float3 oo = IN.ObjectNormal.xyz;
	float4 studShade = tex2D(StudsSamp, IN.ModelUV.xy);
	float zdist = IN.ObjectNormal.w;
	float spread = 0.3;
	float grass_threshold = 0.95;
	float NormalRatio = 0.15;
	float2 NormalUV = IN.ModelUV.zw;

	float3 shiftPos = IN.TexPos3D.xyz;
	float3 ns = NoiseScale;
    float noiseval2 = tex3D(NoiseSamp,shiftPos.xyz*ns.x).x * 0.4;
	float noiseval = tex3D(NoiseSamp,shiftPos.zyx*ns.y).x * 0.6;
	noiseval -= noiseval2;
	float noiseval3 = tex3D(NoiseSamp,shiftPos.xyz*ns.z).x * 0.3;
	noiseval += noiseval3;

	float interp = (noiseval - grass_threshold + spread)/2.0/spread+0.5;
	interp = clamp(interp,0.0,1.0);

    float3 grassColor = tex2D(grassSamp, NormalUV).xyz;
	float3 dirt = tex2D(NormalSamp,NormalUV).xyz ;
	float3 grassNorm = tex2D(GrassNormalSamp,NormalUV).xyz;
	float3 dirtNorm = float3(0.5,0.5,1);
	float3 tNorm = lerp(grassNorm, dirtNorm, interp) - 0.5;

    float3 aWorldBinormal = cross(IN.WorldNormal , IN.WorldTangent);
	float3 NnBump = normalize(tNorm.x*IN.WorldTangent + tNorm.y*aWorldBinormal + tNorm.z*IN.WorldNormal);

	float fade = 1.5-abs(zdist);
	if (fade < 0.0)
		fade = 0.0;
	float3 dColor;

	dColor = lerp(grassColor+IN.Color.xyz-float3(0.31,0.43,0.146), dirt, interp*fade);

	float3 diffContrib;
	float3 specContrib;

	//Fade out the shader
	ps_shared_lighting(dColor, NnBump, IN.WorldView.xyz, IN.Light0Vec, IN.Light1Vec,
	Lamp0Color, Lamp1Color, AmbiColor, Ks, SpecExpon, diffContrib, specContrib);


    diffContrib = lerp(diffContrib, studShade.xyz, studShade.w);
    float3 result = diffContrib + specContrib;
	oColor = float4(result,1);

#if GBUFFER
	oColor1 = packDeferred(IN.WorldView.w, diffContrib, specContrib);
#endif
}

uniform float3 Contrast;
uniform float Ks;
uniform float SpecExpon;
uniform float3 Lamp0Color;
uniform float3 Lamp1Color;
uniform float3 AmbiColor;
uniform float3 NoiseScale;
uniform sampler2D StudsSamp;
uniform sampler3D NoiseSamp;
uniform sampler2D NormalSamp;
uniform sampler2D grassSamp;
uniform sampler2D GrassNormalSamp;
uniform float4 FogColour;
uniform float4 FogParams;

varying vec4 ModelUV;
varying vec4 TexPos3D;
varying vec3 Light0Vec;
varying vec3 Light1Vec;
varying vec3 WorldNormal;
varying vec3 WorldTangent;
varying vec4 WorldView;
varying vec4 ObjectNormal;

void main()
{
	VertexOutput IN;
	IN.HPosition = gl_FragCoord;
	IN.Color = gl_Color;
	IN.ModelUV = ModelUV;
	IN.TexPos3D = TexPos3D;
	IN.Light0Vec = Light0Vec;
	IN.Light1Vec = Light1Vec;
	IN.WorldNormal = WorldNormal;
	IN.WorldTangent = WorldTangent;
	IN.WorldView = WorldView;
	IN.ObjectNormal = ObjectNormal;

	float4 oColor = IN.Color;
#if GBUFFER
	float4 oColor1 = gl_SecondaryColor;
#endif

	mainPSStuds( IN,
		Contrast,
		Ks,
		SpecExpon,
		Lamp0Color,
		Lamp1Color,
		AmbiColor,
		NoiseScale,
		StudsSamp,
		NoiseSamp,
		NormalSamp,
		grassSamp,
		GrassNormalSamp,
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
