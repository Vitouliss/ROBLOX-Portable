
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


void dplatePSStuds(BumpVertexOutput IN,
		UNIFORM_PARAMETER float Ks,
		UNIFORM_PARAMETER float SpecExpon,
		UNIFORM_PARAMETER float3 Lamp0Color,
		UNIFORM_PARAMETER float3 Lamp1Color,
		UNIFORM_PARAMETER float3 AmbiColor,
		UNIFORM_PARAMETER SAMPLER_IN sampler2D StudsSamp,
		UNIFORM_PARAMETER SAMPLER_IN sampler2D NormalSamp,
#if GBUFFER
		out float4 oColor1,
#endif
		out float4 oColor
)
{
	float4 studShade = tex2D(StudsSamp, IN.ModelUV.xy);
	float fade = 1.0-abs(IN.ObjectNormal.w);  // ObjectNormal.w holds z distance from object position to camera
														// *.00555 is division by 180, the fade distance for LOD drawing
														// so that the contribution of shader will fade to 0 at 180
	if(fade < 0.0)
		fade = 0.0;

	float NormalRatio = 0.15;
	float2 NormalUV = IN.ModelUV.zw;

	float3 dColor = IN.Color.xyz;
	float3 tNorm = tex2D(NormalSamp,NormalUV).xyz - float3(0.5,0.5,0.5);

    float3 aWorldBinormal = cross(IN.WorldNormal, IN.WorldTangent);
	float3 NnBump = normalize(tNorm.x * IN.WorldTangent +  tNorm.y * aWorldBinormal +  tNorm.z * IN.WorldNormal);
    NnBump *= fade;
	Ks *= fade;

	float3 Nn = normalize(lerp(NnBump, IN.WorldNormal, 0.7));

	float3 diffContrib;
	float3 specContrib;

	ps_shared_lighting(dColor, Nn, IN.WorldView.xyz,
					IN.Light0Vec, IN.Light1Vec,
					Lamp0Color, Lamp1Color,
					AmbiColor,
					Ks, SpecExpon,
					diffContrib,
					specContrib);

    diffContrib = lerp(diffContrib, studShade.xyz, studShade.w);
	float3 result = diffContrib + specContrib;

	oColor = float4(result+0.01, 1.0);

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
uniform float4 FogColour;
uniform float4 FogParams;

varying vec4 ModelUV;
varying vec3 Light0Vec;
varying vec3 Light1Vec;
varying vec3 WorldNormal;
varying vec3 WorldTangent;
varying vec4 ObjectNormal;
varying vec4 WorldView;

void main()
{
	BumpVertexOutput IN;
	IN.HPosition = gl_FragCoord;
	IN.Color = gl_Color;
	IN.ModelUV = ModelUV;
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

	dplatePSStuds( IN, Ks, SpecExpon, Lamp0Color, Lamp1Color, AmbiColor, StudsSamp, NormalSamp,
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
