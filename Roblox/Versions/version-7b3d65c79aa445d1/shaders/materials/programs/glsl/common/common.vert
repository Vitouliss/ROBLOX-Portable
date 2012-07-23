
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

float4 lit( float NdotL, float NdotH, float m)
{
	float specular = (NdotL > 0.0) ? pow(max(0.0, NdotH), m) : 0.0;
	return float4(1.0, max(0.0, NdotL), specular, 1.0);
}


////////////////// Util Functions ///////////////

//normal must be normalized.
//tangetnRef and binormalRef should be similar scale.
void makeTangentAndBinormal(float3 normal, float3 tangentRef, float3 binormalRef, out float3 tangent, out float3 binormal)
{
	float3 binormaltemp = cross(normal, tangentRef);
	float binormallen = length(binormaltemp);
	float3 tangenttemp = cross(binormalRef, normal);
	float tangentlen = length(tangenttemp);
	// use the longest result (most accurate)
	// both will never be zero.
	if(binormallen > tangentlen)
	{
		binormal = binormaltemp/binormallen;
		tangent = cross(binormal, normal);
	}
	else
	{
		tangent = tangenttemp/tangentlen;
		binormal = cross(normal, tangent);
	}
}

void makeWorldTangentAndBinormalFromTextureXf(float4x4 TextureXf, float3 objNormal, 
	out float3 objTangent, out float3 objBinormal)
{
	//generate tangent and binormal using 3D texturespace X and Y vector.
	float4 xunit = float4( 1.0, 0.0, 0.0, 0.0 );
	float4 yunit = float4( 0.0, 1.0, 0.0, 0.0 );
	float3 tangentRef = mul(TextureXf, xunit).xyz;
	float3 binormalRef = mul(TextureXf, yunit).xyz; 
	makeTangentAndBinormal(objNormal, tangentRef, binormalRef,
			objTangent, objBinormal);
}

float4 packDeferredDepth(float depth)
{
	float4 result;
	
	const float3 bitSh	= float3( 256.0*256.0, 256.0, 1.0);
	const float2 bitMsk = float2( 1.0/256.0,  1.0/256.0);
	result.rg = float2(0.0,0.0);
	
	float3 comp;
	comp	= depth * bitSh;
	
	comp.z -= comp.y;
	comp.y -= comp.x;
	
	result.ba = comp.yz; 
	
	return result;
}

float YfromRGB(float3 color)
{
	return dot(color, float3(0.299, 0.587, 0.114));
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
		UNIFORM_PARAMETER float3 Lamp0Color,
		UNIFORM_PARAMETER float3 Lamp1Color,
		UNIFORM_PARAMETER float3 AmbiColor,
		UNIFORM_PARAMETER float Ks,
		UNIFORM_PARAMETER float SpecExpon,
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
	float tempSpecExpon = SpecExpon;
    float4 lit0V = lit(ldn0,hdn0,tempSpecExpon);
    float lit1Vy = saturate(ldn1); // don't do specular calculations for second light.
    DiffuseContrib = DiffuseColor * ( lit0V.y*Lamp0Color + lit1Vy*Lamp1Color + AmbiColor);
    SpecularContrib = Ks * (lit0V.z * Lamp0Color);
}

void vs_shared_lighting(
	float3 Position,
	float3 Normal,
	float3 Tangent,
	UNIFORM_PARAMETER float4x4 WorldITXf, // our four standard "untweakable" xforms
	UNIFORM_PARAMETER float4x4 WorldXf,
	UNIFORM_PARAMETER float4x4 ViewIXf,
	UNIFORM_PARAMETER float4x4 WvpXf,
	UNIFORM_PARAMETER float4 Lamp0Pos,
	UNIFORM_PARAMETER float4 Lamp1Pos,
	out float3 Light0Vec,
	out float3 Light1Vec,
	out float3 WorldView,
	out float4 HPosition,
	out float3 WorldNormal,
	out float3 WorldTangent,
	out float3 WorldBinormal)
{
    float4 Po = float4(Position.xyz,1.0);
    float3 Pw = mul(WorldXf, Po).xyz;    
    
	Light0Vec = Lamp0Pos.xyz - (Pw * Lamp0Pos.w);
    Light1Vec = Lamp1Pos.xyz - (Pw * Lamp1Pos.w);
#if GLSL
    WorldView = (float3(ViewIXf[3].x,ViewIXf[3].y,ViewIXf[3].z) - Pw);
#endif
#if CG
	WorldView = (float3(ViewIXf[0].w, ViewIXf[0].w,ViewIXf[0].w) - Pw);
#endif

    HPosition = mul(WvpXf,Po);
	float4 Normal4 = float4(Normal,0.0);
	float4 Tangent4 = float4(Tangent,0.0);
	WorldNormal = mul(WorldITXf, Normal4).xyz;
    WorldTangent = mul(WorldITXf,Tangent4).xyz;
	WorldBinormal = cross(WorldNormal, WorldTangent);
}

void vs_shared_lighting_diffuse(
	float3 Position,
	float3 Normal,
	float3 Tangent,
	float3 DiffuseColor,
	UNIFORM_PARAMETER float4x4 WorldITXf, // our four standard "untweakable" xforms
	UNIFORM_PARAMETER float4x4 WorldXf,
	UNIFORM_PARAMETER float4x4 ViewIXf,
	UNIFORM_PARAMETER float4x4 WvpXf,
	UNIFORM_PARAMETER float4 Lamp0Pos,
	UNIFORM_PARAMETER float4 Lamp1Pos,
	UNIFORM_PARAMETER float3 Lamp0Color,
	UNIFORM_PARAMETER float3 Lamp1Color,
	UNIFORM_PARAMETER float3 Ambient,
	out float3 Light0Vec,
	out float3 LightDiffuseContrib, // includes ambient
	out float3 WorldView,
	out float4 HPosition,
	out float3 WorldNormal,
	out float3 WorldTangent,
	out float3 WorldBinormal)
{
    float4 Po = float4(Position.xyz,1.0);
    float3 Pw = mul( WorldXf, Po ).xyz;
    
	Light0Vec = Lamp0Pos.xyz - (Pw * Lamp0Pos.w);
    float3 Light1Vec = Lamp1Pos.xyz - (Pw * Lamp1Pos.w);
#if GLSL
    WorldView = (float3(ViewIXf[3].x,ViewIXf[3].y,ViewIXf[3].z) - Pw);
#endif
#if CG
	WorldView = (float3(ViewIXf[0].w, ViewIXf[0].w,ViewIXf[0].w) - Pw);
#endif

    HPosition = mul(WvpXf,Po);
	float4 Normal4 = float4(Normal,0.0);
	float4 Tangent4 = float4(Tangent,0.0);
	WorldNormal = mul(WorldITXf, Normal4).xyz;
    WorldTangent = mul(WorldITXf, Tangent4).xyz;
	WorldBinormal = cross(WorldNormal, WorldTangent);
	
	float3 IgnoredSpecular;
	// reuse ps_ lighting comp
	ps_shared_lighting(
		DiffuseColor,
		WorldNormal,
		WorldView,
		Light0Vec,
		Light1Vec,
		Lamp0Color,
		Lamp1Color,
		Ambient,
		0.0,
		0.0,
		LightDiffuseContrib,
		IgnoredSpecular
		);
}

struct BasicVertexInput {
#if CG
    float3 Position	: POSITION;
	float4 Color	: COLOR;
    float2 StudsUV	: TEXCOORD0;
    float3 Normal	: NORMAL;
    float3 Tangent	: TANGENT0;
#endif
#if GLSL
	float3 Position;
	float4 Color;
	float2 StudsUV;
	float3 Normal;
	float3 Tangent;
#endif
};

/* data passed from vertex shader to pixel shader */
struct BasicVertexOutput {
#if CG
    float4 HPosition	: POSITION;
	float4 Color 		: COLOR;
    float2 StudsUV		: TEXCOORD0;
    float3 Light0Vec	: TEXCOORD2;
    float3 Light1Vec	: TEXCOORD3;
    float3 WorldNormal	: TEXCOORD4;
    float3 WorldTangent	: TEXCOORD5;
    float3 WorldView	: TEXCOORD7;
#endif
#if GLSL
    float4 HPosition;
	float4 Color;
    float2 StudsUV;
    float3 Light0Vec;
    float3 Light1Vec;
    float3 WorldNormal;
    float3 WorldTangent;
    float3 WorldView;
#endif
};

/*********** vertex shader ******/
BasicVertexOutput basicVS(BasicVertexInput IN,
    UNIFORM_PARAMETER float4x4 WorldITXf, // our four standard "untweakable" xforms
	UNIFORM_PARAMETER float4x4 WorldXf,
	UNIFORM_PARAMETER float4x4 ViewIXf,
	UNIFORM_PARAMETER float4x4 WvpXf,
	UNIFORM_PARAMETER float4 Lamp0Pos,
    UNIFORM_PARAMETER float4 Lamp1Pos
) 
{
    BasicVertexOutput OUT;
#if CG
	OUT = (BasicVertexOutput )0;
#endif

	float3 unusedBinormal;
	vs_shared_lighting(
		IN.Position,
		IN.Normal,
		IN.Tangent,
    	WorldITXf, // our four standard "untweakable" xforms
		WorldXf,
		ViewIXf,
		WvpXf,
    	Lamp0Pos,
    	Lamp1Pos,
		OUT.Light0Vec,
		OUT.Light1Vec,
		OUT.WorldView,
		OUT.HPosition,
		OUT.WorldNormal,
		OUT.WorldTangent,
		unusedBinormal);
	OUT.StudsUV = IN.StudsUV; // passthrough model UVs.
	OUT.Color = IN.Color;

    return OUT;
}

/********* pixel shader ********/
float4 basicPSStuds(BasicVertexOutput IN,
	UNIFORM_PARAMETER float Ks, UNIFORM_PARAMETER float SpecExpon,
		UNIFORM_PARAMETER float3 Lamp0Color, UNIFORM_PARAMETER float3 Lamp1Color, UNIFORM_PARAMETER float3 AmbiColor,
		UNIFORM_PARAMETER SAMPLER_IN sampler2D StudsSamp
) 
#if CG 
	: COLOR 
#endif
{
	float4 studShade = tex2D(StudsSamp, IN.StudsUV.xy);
	
	float3 diffContrib;
	float3 specContrib;

	ps_shared_lighting(IN.Color.xyz, IN.WorldNormal, IN.WorldView, IN.Light0Vec, IN.Light1Vec,
		Lamp0Color, Lamp1Color, AmbiColor, Ks, SpecExpon, diffContrib, specContrib);
					
    float3 result = lerp(diffContrib, studShade.xyz, studShade.w) + specContrib;
	return float4(result,1.0);	
}


/************* DATA STRUCTS **************/

/* data from application vertex buffer */
struct appdataTangent {
#if CG
    float3 Position	: POSITION;
	float4 Color	: COLOR;
    float2 StudsUV	: TEXCOORD0;
    float4 TexPos3D	: TEXCOORD1;  // w: secondary color (for rust)
    float2 SurfaceUV: TEXCOORD2;
    float3 Normal	: NORMAL;
    float3 Tangent	: TANGENT0;
#endif
#if GLSL
    float3 Position;
	float4 Color;
    float2 StudsUV;
    float4 TexPos3D;  // w: secondary color (for rust)
    float2 SurfaceUV;
    float3 Normal;
    float3 Tangent;
#endif
};

struct appdataBump {
#if CG
    float3 Position	: POSITION;
	float4 Color	: COLOR;
    float2 StudsUV	: TEXCOORD0;
    float2 SurfaceUV: TEXCOORD1;
    float3 Normal	: NORMAL;
    float3 Tangent	: TANGENT0;
#endif
#if GLSL
    float3 Position;
	float4 Color;
    float2 StudsUV;
    float2 SurfaceUV;
    float3 Normal;
    float3 Tangent;
#endif
};

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

struct BumpVertexOutput {
#if CG
    float4 HPosition	: POSITION;
	float4 Color 		: COLOR;
    float4 ModelUV		: TEXCOORD0;
    float3 Light0Vec	: TEXCOORD2;
    float3 Light1Vec	: TEXCOORD3;
    float3 WorldNormal	: TEXCOORD4;
    float3 WorldTangent	: TEXCOORD5;
    float4 WorldView	: TEXCOORD7; // w = depth value for SSAO
	float4 ObjectNormal : TEXCOORD6;// coord w is attenuation 0 = no normal map, 1 = full normal map
#endif
#if GLSL
   float4 HPosition;
	float4 Color;
    float4 ModelUV;
    float3 Light0Vec;
    float3 Light1Vec;
    float3 WorldNormal;
    float3 WorldTangent	;
    float4 WorldView; // w = depth value for SSAO
	float4 ObjectNormal;// coord w is attenuation 0 = no normal map, 1 = full normal map
#endif
};

#define GBUFFER_MAX_DEPTH 500.0

float vs_compute_gbuffer_depth(
	float3 Position,
	float4x4 WvXf
	)
{
	float4 Po = float4(Position.xyz,1.0);
	return mul(WvXf, Po).z;
}

/*********** vertex shader ******/
BumpVertexOutput BumpVS(appdataBump IN,
    UNIFORM_PARAMETER float4x4 WorldITXf, // our four standard "untweakable" xforms
	UNIFORM_PARAMETER float4x4 WorldXf,
	UNIFORM_PARAMETER float4x4 ViewIXf,
	UNIFORM_PARAMETER float4x4 WvpXf,
#if GBUFFER
	UNIFORM_PARAMETER float4x4 WvXf,
#endif	
    UNIFORM_PARAMETER float4 Lamp0Pos,
    UNIFORM_PARAMETER float4 Lamp1Pos,
	UNIFORM_PARAMETER float NormMapScale, 
	UNIFORM_PARAMETER float FadeDistance
) 
{
    BumpVertexOutput OUT;
#if CG
	OUT = (BumpVertexOutput)0;
#endif
	
 	float3 unusedBinormal;
 	
 	float3 worldView;
	vs_shared_lighting(
		IN.Position,
		IN.Normal,
		IN.Tangent,
    	WorldITXf, // our four standard "untweakable" xforms
		WorldXf,
		ViewIXf,
		WvpXf,
    	Lamp0Pos,
    	Lamp1Pos,
		OUT.Light0Vec,
		OUT.Light1Vec,
		worldView,
		OUT.HPosition,
		OUT.WorldNormal,
		OUT.WorldTangent,
		unusedBinormal);
		
	OUT.WorldView.xyz = worldView;
	OUT.WorldView.w = -vs_compute_gbuffer_depth(IN.Position, WvXf) / GBUFFER_MAX_DEPTH;

	OUT.ModelUV = float4(IN.StudsUV, IN.SurfaceUV* NormMapScale); // passthrough model UVs.
	OUT.Color = IN.Color; //Average color of the grass texture
	OUT.ObjectNormal = float4(IN.Normal,1.0);
	float4 Position4 = float4(IN.Position,1.0);  
	OUT.ObjectNormal.w = mul(WvpXf,Position4).z / FadeDistance;
	OUT.ObjectNormal.xyz = normalize(OUT.ObjectNormal.xyz);   // dplate only uses w component. stuff it elsewhere, and get rid of this?
    return OUT;
}

VertexOutput NoiseVS(appdataTangent IN,
    UNIFORM_PARAMETER float4x4 WorldITXf, // our four standard "untweakable" xforms
	UNIFORM_PARAMETER float4x4 WorldXf,
	UNIFORM_PARAMETER float4x4 ViewIXf,
	UNIFORM_PARAMETER float4x4 WvpXf,
#if GBUFFER
	UNIFORM_PARAMETER float4x4 WvXf,
#endif
    UNIFORM_PARAMETER float4 Lamp0Pos,
    UNIFORM_PARAMETER float4 Lamp1Pos,
	UNIFORM_PARAMETER float NormMapScale,
	UNIFORM_PARAMETER float Transform3DNoiseCoordinates,
	UNIFORM_PARAMETER float FadeDistance
) 
{
    VertexOutput OUT;
#if CG
	OUT = (VertexOutput)0;
#endif
	
	float3 worldView;
 	float3 unusedBinormal;
	vs_shared_lighting(
		IN.Position,
		IN.Normal,
		IN.Tangent,
    	WorldITXf, // our four standard "untweakable" xforms
		WorldXf,
		ViewIXf,
		WvpXf,
    	Lamp0Pos,
    	Lamp1Pos,
		OUT.Light0Vec,
		OUT.Light1Vec,
		worldView,
		OUT.HPosition,
		OUT.WorldNormal,
		OUT.WorldTangent,
		unusedBinormal);
		
	OUT.WorldView.xyz = worldView;
	OUT.WorldView.w = -vs_compute_gbuffer_depth(IN.Position, WvXf) / GBUFFER_MAX_DEPTH;

    // This shader uses the object coordinates to determine the grass-grain
    //   coordinate system at shader runtime. Alternatively, you could bake
    //	 the coordinate system into the model as an alternative texcoord. The
    //	 current method applies to all possible models, while baking-in lets
    //	 you try different tricks such as modeling the grain of bent ,
    //	 say for a bow or for the hull timbers of a ship.
    //
    if(Transform3DNoiseCoordinates > 0.01)
    {
		float cfactor = 0.980066578; 	//cos(0.2);
		float sfactor = 0.198669331; 	//sin(0.2);
		float cfactor2 = 0.955336489;	//cos(0.3);
		float sfactor2 = 0.295520207; 	//sin(0.3);
		float cfactor3 = 0.921060994;	//cos(0.4);
		float sfactor3 = 0.389418342;	//sin(0.4);
		float3 p = IN.TexPos3D.xyz;
		float3 shiftPos = p;

		shiftPos.x += p.x * cfactor + p.z * sfactor;
		shiftPos.z += p.x * -sfactor + p.z * cfactor;
		
		shiftPos.x += p.x * cfactor2 - p.y * sfactor2;
		shiftPos.y += p.x * sfactor2 + p.y * cfactor2;
		
		shiftPos.y += p.y * cfactor3 - p.z * sfactor3;
		shiftPos.z += p.y * sfactor3 + p.z * cfactor3;
		
		OUT.TexPos3D = float4(shiftPos,IN.TexPos3D.w); 
	}
	else
		OUT.TexPos3D = IN.TexPos3D; 
	
	OUT.ModelUV = float4(IN.StudsUV, IN.SurfaceUV* NormMapScale); // passthrough model UVs.
	OUT.Color = IN.Color; //Average color of the grass texture
	OUT.ObjectNormal = float4(IN.Normal,1.0);
	float4 Position4 = float4(IN.Position, 1.0);
	float4 transformedPos = mul( WvpXf, Position4 );
	OUT.ObjectNormal.w = transformedPos.z / FadeDistance;
	OUT.ObjectNormal.xyz = normalize(OUT.ObjectNormal.xyz);
	
	
    return OUT;
}
