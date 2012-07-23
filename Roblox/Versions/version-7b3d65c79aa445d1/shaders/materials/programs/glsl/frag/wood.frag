
// Defines to convert Cg to GLSL
#define float2 vec2
#define float3 vec3
#define float4 vec4
#define float2x2 mat2
#define float3x3 mat3
#define float4x4 mat4
#define tex2D texture2D
#define tex3D texture3D
#define ddx dFdx
#define ddy dFdy
#define lerp(x,y,z) mix(x,y,z)
#define mul(x,y) (x * y)
#define atan2(x,y) atan(y,x)
#define saturate(x) clamp(x,0.0,1.0)
#define frac(x) (x - floor(x))
#define samplerCUBE samplerCube
#define texCUBE textureCube

#define UNIFORM_PARAMETER
#define SAMPLER_IN in

struct woodVertexOutput {
    float4 HPosition;
    float4 WoodColor;
    float4 ModelUV;
    float4 WoodPos; // wood grain coordinate system
    		    // coord w is attenuation 0 = no normal map, 1 = full normal map
    float3 Light0Vec;
    float3 Light1Vec;
    float3 WorldNormal;
    float3 WorldTangent;
    float3 WorldBinormal;
    float4 WorldView; // w is view space depth for SSAO
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



void woodCore(
		float4 HPosition,
		float4 WoodColor,
		float4 ModelUV,
		float4 WoodPos, // wood grain coordinate system
		float3 Light0Vec,
		float3 Light1Vec,
		float3 WorldNormal,
		float3 WorldTangent,
		float3 WorldBinormal,
		float3 WorldView,
		float4 StudShade,
		UNIFORM_PARAMETER float3 WoodContrast,
		UNIFORM_PARAMETER float Ks1,
		UNIFORM_PARAMETER float Ks2,
		UNIFORM_PARAMETER float SpecExpon,
		UNIFORM_PARAMETER float RingScale,
		UNIFORM_PARAMETER float AmpScale,
		UNIFORM_PARAMETER float3 Lamp0Color,
		UNIFORM_PARAMETER float3 Lamp1Color,
		UNIFORM_PARAMETER float3 AmbiColor,
		UNIFORM_PARAMETER float LightRingEnd,
		UNIFORM_PARAMETER float DarkRingStart,
		UNIFORM_PARAMETER float DarkRingEnd,
		UNIFORM_PARAMETER float MixedColorRatio,
		UNIFORM_PARAMETER float AAFreqMultiplier,
		UNIFORM_PARAMETER float NoiseScale,
	    UNIFORM_PARAMETER float NormMapScale,
		UNIFORM_PARAMETER sampler3D NoiseSamp,
		UNIFORM_PARAMETER sampler2D NormalSamp,
		out float3 diffContrib,
		out float3 specContrib)
{
	float2 NormalUV = WoodPos.xy * NormMapScale;
	float singularityAttenuation = WoodPos.w;

    float3 noiseval = tex3D(NoiseSamp,WoodPos.xyz/NoiseScale).xyz;
    float3 tNorm = tex2D(NormalSamp,NormalUV).xyz;


    // transform tNorm to world space
    float3 NnBump = tNorm.x*WorldTangent -
		      tNorm.y*WorldBinormal +
		      tNorm.z*WorldNormal;
    float3 NnNoBump = WorldNormal;
	float3 Nn = normalize(lerp(NnBump, NnNoBump, singularityAttenuation));

	// Removing ddx dependence for opengl. OpenGL support for it is still fairly splotchy in both compiler and linker
	//  and this shader is not heavily dependent on it
	//float signalfreq = length(float4(ddx(WoodPos.y), ddx(WoodPos.z),
	//						         ddy(WoodPos.y), ddy(WoodPos.z)));
	float signalfreq = -0.1;

	float aa_attn = saturate(signalfreq*AAFreqMultiplier - 1.0);
    float3 Pwood = WoodPos.xyz + (AmpScale * noiseval);
    float r = RingScale * length(Pwood.yz);
    r = r + tex3D(NoiseSamp,float3(r, r, r)/32.0).x;
    r = r - floor(r);
    r = smoothstep(LightRingEnd, DarkRingStart, r) - smoothstep(DarkRingEnd,1.0,r);
	// apply anti-aliasing
	r = lerp(r, MixedColorRatio, aa_attn);


    float3 dColor = WoodColor.xyz + WoodContrast * (MixedColorRatio - r);
    float Ks = lerp(Ks1,Ks2,r);

	ps_shared_lighting(dColor, Nn, WorldView,
					Light0Vec, Light1Vec,
					Lamp0Color, Lamp1Color,
					AmbiColor,
					Ks, SpecExpon,
					diffContrib,
					specContrib);


    diffContrib = lerp(diffContrib, StudShade.xyz, StudShade.w);
}

void woodPSStuds(woodVertexOutput IN,
		UNIFORM_PARAMETER float3 WoodContrast,
		UNIFORM_PARAMETER float Ks1,
		UNIFORM_PARAMETER float Ks2,
		UNIFORM_PARAMETER float SpecExpon,
		UNIFORM_PARAMETER float RingScale,
		UNIFORM_PARAMETER float AmpScale,
		UNIFORM_PARAMETER float3 Lamp0Color,
		UNIFORM_PARAMETER float3 Lamp1Color,
		UNIFORM_PARAMETER float3 AmbiColor,
		UNIFORM_PARAMETER float LightRingEnd,
		UNIFORM_PARAMETER float DarkRingStart,
		UNIFORM_PARAMETER float DarkRingEnd,
		UNIFORM_PARAMETER float MixedColorRatio,
		UNIFORM_PARAMETER float AAFreqMultiplier,
		UNIFORM_PARAMETER float NoiseScale,
	   	UNIFORM_PARAMETER float NormMapScale,
		UNIFORM_PARAMETER SAMPLER_IN sampler2D StudsSamp,
		UNIFORM_PARAMETER SAMPLER_IN sampler3D NoiseSamp,
		UNIFORM_PARAMETER SAMPLER_IN sampler2D NormalSamp,
#if GBUFFER
		out float4 oColor1,
#endif
		out float4 oColor
)
{
	float3 diffContrib;
	float3 specContrib;
	float4 studShade = tex2D(StudsSamp, IN.ModelUV.xy);
	woodCore(IN.HPosition,
		IN.WoodColor,
		IN.ModelUV,
		IN.WoodPos, // wood grain coordinate system
		IN.Light0Vec,
		IN.Light1Vec,
		IN.WorldNormal,
		IN.WorldTangent,
		IN.WorldBinormal,
		IN.WorldView.xyz,
		studShade,
		WoodContrast,
		Ks1,
		Ks2,
		SpecExpon,
		RingScale,
		AmpScale,
		Lamp0Color,
		Lamp1Color,
		AmbiColor,
		LightRingEnd,
		DarkRingStart,
		DarkRingEnd,
		MixedColorRatio,
		AAFreqMultiplier,
		NoiseScale,
		NormMapScale,
		NoiseSamp,
		NormalSamp,
		diffContrib,
		specContrib);

	oColor = float4(diffContrib + specContrib,1);

#if GBUFFER
	oColor1 = packDeferred(IN.WorldView.w, diffContrib, specContrib);
#endif
}

uniform float3 WoodContrast;
uniform float Ks1;
uniform float Ks2;
uniform float SpecExpon;
uniform float RingScale;
uniform float AmpScale;
uniform float3 Lamp0Color;
uniform float3 Lamp1Color;
uniform float3 AmbiColor;
uniform float LightRingEnd;
uniform float DarkRingStart;
uniform float DarkRingEnd;
uniform float MixedColorRatio;
uniform float AAFreqMultiplier;
uniform float NoiseScale;
uniform float NormMapScale;
uniform sampler2D StudsSamp;
uniform sampler3D NoiseSamp;
uniform sampler2D NormalSamp;
uniform float4 FogColour;
uniform float4 FogParams;

varying vec4 ModelUV;
varying vec4 WoodPos;
varying vec3 Light0Vec;
varying vec3 Light1Vec;
varying vec3 WorldNormal;
varying vec3 WorldTangent;
varying vec3 WorldBinormal;
varying vec4 WorldView;

void main()
{
	woodVertexOutput IN;
	IN.HPosition = gl_FragCoord;
	IN.WoodColor = gl_Color;
	IN.ModelUV = ModelUV;
	IN.WoodPos = WoodPos;
	IN.Light0Vec = Light0Vec;
	IN.Light1Vec = Light1Vec;
	IN.WorldNormal = WorldNormal;
	IN.WorldTangent = WorldTangent;
	IN.WorldBinormal = WorldBinormal;
	IN.WorldView = WorldView;

	float4 oColor = IN.WoodColor;
#if GBUFFER
	float4 oColor1 = gl_SecondaryColor;
#endif

	woodPSStuds( IN,
		WoodContrast,
		Ks1,
		Ks2,
		SpecExpon,
		RingScale,
		AmpScale,
		Lamp0Color,
		Lamp1Color,
		AmbiColor,
		LightRingEnd,
		DarkRingStart,
		DarkRingEnd,
		MixedColorRatio,
		AAFreqMultiplier,
		NoiseScale,
	   	NormMapScale,
		StudsSamp,
		NoiseSamp,
		NormalSamp,
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
