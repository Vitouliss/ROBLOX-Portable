
// GLSL defines to convert HLSL/Cg code into GLSL
#define float2 vec2
#define float3 vec3
#define float4 vec4
#define float2x2 mat2
#define float3x3 mat3
#define float4x4 mat4
#define tex2D texture2D
#define texCUBE textureCube
#define lerp(x,y,z) mix(x,y,z)
#define mul(x,y) (x*y)
#define atan2(x,y) atan(y,x)
#define saturate(x) clamp(x,0.0,1.0)
#define frac(x) (x - floor(x))
#define samplerCUBE samplerCube
#define UNIFORM_PARAMETER
#define SAMPLER_IN in

/* data passed from vertex shader to pixel shader */
struct VertexOutput {
#if CG
    float4 HPosition	: POSITION;
	float4 Color 		: COLOR;
    float4 ModelUV		: TEXCOORD0;
    float4 TexPos3D		: TEXCOORD1; //  grain coordinate system
    								// coord w is attenuation 0 = no normal map, 1 = full normal map
    float3 Light0Vec	: TEXCOORD2;
    float3 Light1Vec	: TEXCOORD3;
    float3 WorldNormal	: TEXCOORD4;
    float3 WorldTangent	: TEXCOORD5;
    float4 WorldView	: TEXCOORD7; // w = depth value for SSAO
	float4 ObjectNormal : TEXCOORD6;
#endif
#if GLSL
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
#endif
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


void alumPSStuds(VertexOutput IN,
		UNIFORM_PARAMETER float pKs,
		UNIFORM_PARAMETER float pSpecExpon,
		UNIFORM_PARAMETER float3 pLamp0Color,
		UNIFORM_PARAMETER float3 pLamp1Color,
		UNIFORM_PARAMETER float3 pAmbiColor,
		UNIFORM_PARAMETER in sampler2D pStudsSamp,
		UNIFORM_PARAMETER in sampler2D pNormalSamp,
		UNIFORM_PARAMETER in samplerCUBE pEnvSampler,
		UNIFORM_PARAMETER float pKr,
		UNIFORM_PARAMETER float pFresnelVal,
#if GBUFFER
		out float4 oColor1,
#endif
		out float4 oColor
		)
{
	float4 studShade = tex2D(pStudsSamp, IN.ModelUV.xy);
	float fade = 1.0-abs(IN.ObjectNormal.w);
	if(fade < 0.0)
		fade = 0.0;

	float2 NormalUV = IN.ModelUV.zw;
	float2 NormalUV2 = NormalUV * 0.4;
	float2 NormalUV3 = NormalUV2 * 0.1;

	float3 dColor = IN.Color.xyz;

	float3 tNorm = tex2D(pNormalSamp,NormalUV).xyz - float3(0.5,0.5,0.5);
	float3 tNorm2 = tex2D(pNormalSamp, NormalUV2).xyz - float3(0.5, 0.5, 0.5);
	tNorm = lerp(tNorm, tNorm2, 0.5);
	tNorm2 = tex2D(pNormalSamp, NormalUV3).xyz - float3(0.5, 0.5, 0.5);
	tNorm = lerp(tNorm, tNorm2, 0.3);

	float tNormSum = 0.4+0.6*(tNorm.x + tNorm.y + tNorm.z);
	dColor *= ((1.0-fade) + (fade*tNormSum));

    float3 aWorldBinormal = cross(IN.WorldNormal, IN.WorldTangent);
	float3 NnBump = normalize(tNorm.x * IN.WorldTangent +  tNorm.y*aWorldBinormal +  tNorm.z * IN.WorldNormal);
    NnBump *= fade;
	pKs *= fade;

	float3 Nn = normalize(lerp(NnBump, IN.WorldNormal, 0.4 ));

	float3 diffContrib;
	float3 specContrib;
	float3 reflContrib;

	ps_shared_lighting_env(dColor, Nn, IN.WorldView.xyz,
					IN.Light0Vec, IN.Light1Vec,
					pLamp0Color, pLamp1Color,
					pAmbiColor,
					pKs, pSpecExpon,
					pKr,
					diffContrib,
					specContrib,
					pEnvSampler,
					reflContrib);

    diffContrib = lerp(diffContrib, studShade.xyz, studShade.w);
    float3 result = diffContrib + specContrib;

	result += (pFresnelVal*reflContrib-0.1) * fade;

	oColor = float4(result, 1.0);

#if GBUFFER
	oColor1 = packDeferred(IN.WorldView.w, diffContrib, specContrib);
#endif
}

uniform float Ks;
uniform float SpecExpon;
uniform float3 Lamp0Color;
uniform float3 Lamp1Color;
uniform float3 AmbiColor;
uniform sampler2D StudsSamp;
uniform sampler2D NormalSamp;
uniform samplerCUBE EnvSampler;
uniform float Kr;
uniform float FresnelVal;
uniform float4 FogColour;
uniform float4 FogParams;

varying vec4 ModelUV;
varying vec4 TexPos3D;
varying vec3 Light0Vec;
varying vec3 Light1Vec;
varying vec3 WorldNormal;
varying vec3 WorldTangent;
varying vec4 ObjectNormal;
varying vec4 WorldView;

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

	alumPSStuds( IN, Ks, SpecExpon, Lamp0Color, Lamp1Color, AmbiColor, StudsSamp,
		NormalSamp, EnvSampler, Kr, FresnelVal,
#if GBUFFER
		oColor1,
#endif
		oColor);

	float fogAlpha = ( ( FogParams.z - (IN.WorldView.w*500.0) ) * FogParams.w );
	fogAlpha = clamp( fogAlpha, 0.0, 1.0 );

	gl_FragColor = mix( FogColour, oColor, fogAlpha );
#if GBUFFER
	oColor1 = mix( FogColour, oColor1, fogAlpha );
#endif
}
