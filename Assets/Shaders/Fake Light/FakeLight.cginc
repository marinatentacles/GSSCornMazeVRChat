// Common fake light code.

struct Ray
{
    float3 o;
    float3 d;
};

// Original Volumetric Sphere Density by iq
// http://www.iquilezles.org/www/articles/spheredensity/spheredensity.htm
// Unity version by 1001

float sphDensity( Ray ray, float3 sc, float sr, float dbuffer )
{
	float3 ro = ray.o;
	float3 rd = ray.d;
	// normalize the problem to the canonical sphere
	float ndbuffer = dbuffer / sr;
	float3  rc = (ro - sc)/sr;
	
	// find intersection with sphere
	float b = dot(rd,rc);
	float c = dot(rc,rc) - 1.0;
	float h = b*b - c;

	// not intersecting
	if( h<0.0 ) return 0.0;
	
	h = sqrt( h );

	float t1 = -b - h;
	float t2 = -b + h;

	// not visible (behind camera or behind ndbuffer)
	if( t2<0.0 || t1>ndbuffer ) return 0.0;

	// clip integration segment from camera to ndbuffer
	t1 = max( t1, 0.0 );
	t2 = min( t2, ndbuffer );

	// analytical integration of an inverse squared density
	float i1 = -(c*t1 + b*t1*t1 + t1*t1*t1/3.0);
	float i2 = -(c*t2 + b*t2*t2 + t2*t2*t2/3.0);
	return (i2-i1)*(3.0/4.0);
}


float renderVolumetricSphere(fixed3 baseWorldPos, fixed3 rayDir, in out float3 depthPosition) {
	const float zDepth = length(_WorldSpaceCameraPos-depthPosition);
	const float scale = length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x));
	Ray ray = (Ray)0;
	ray.o = _WorldSpaceCameraPos;
	ray.d = rayDir;
	float sum = sphDensity(ray, baseWorldPos, 0.5 * scale, zDepth);
	sum = sum + sum*sum*sum;
	sum = sum + sum*sum;
	return sum;
}

// Fake point lights, Deus Ex: Human Revolution style
// Unity version by Silent, with lots of help from 1001. 

float renderFakeLight(fixed3 baseWorldPos, fixed3 rd, in out float3 depthPosition) {
	const float zDepth = length(_WorldSpaceCameraPos-depthPosition);
	const float scale = length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x));
	// Light falloff
	float lf = distance(baseWorldPos, depthPosition);
	lf *= lf;
	lf = 1/lf;
	//lf = pow(saturate(1 - pow(lf / 1, 4)),2);
	// Sphere falloff
	float3 sf = depthPosition - baseWorldPos;
	sf *= 1/scale;
	float sum = lf; 
	sum *= saturate(1-length(sf));
	return sum;
}

// Dj Lukis LT's method for retrieving linear depth that's correct in mirrors.
// https://github.com/lukis101/VRCUnityStuffs
#define PM UNITY_MATRIX_P
inline float4 CalculateObliqueFrustumCorrection()
{
	float x1 = -PM._31/(PM._11*PM._34);
	float x2 = -PM._32/(PM._22*PM._34);
	return float4(x1, x2, 0, PM._33/PM._34 + x1*PM._13 + x2*PM._23);
}
inline float CorrectedLinearEyeDepth(float z, float B)
{
	return 1.0 / (z/PM._34 + B);
}
static float4 ObliqueFrustumCorrection = CalculateObliqueFrustumCorrection();
#undef PM

// Vertex shader

struct appdata_t {
    UNITY_VERTEX_INPUT_INSTANCE_ID
    float4 vertex : POSITION;
    fixed4 color : COLOR;
};

struct v2f
{
    UNITY_VERTEX_INPUT_INSTANCE_ID 
	fixed4 screen_vertex : SV_POSITION;
	fixed3 world_vertex : TEXCOORD0;
	float4 scrPos : TEXCOORD1;
	float4 projPos : TEXCOORD2;
	float4 ray : TEXCOORD3;
    UNITY_FOG_COORDS(4)
    fixed4 color : COLOR;
    UNITY_VERTEX_OUTPUT_STEREO
};

v2f vertex_shader (appdata_t v)
{
	v2f o;
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
	o.screen_vertex = UnityObjectToClipPos(v.vertex);
	o.world_vertex = mul(unity_ObjectToWorld, v.vertex).xyz;
	o.scrPos = ComputeScreenPos(o.screen_vertex);
	o.ray.xyz = o.world_vertex.xyz - _WorldSpaceCameraPos;
	o.ray.w = dot(o.screen_vertex, ObliqueFrustumCorrection); // oblique frustrum correction factor
	float4 wvertex = mul(UNITY_MATRIX_VP, float4(o.world_vertex, 1.0));
	o.projPos = ComputeScreenPos (wvertex);
	o.projPos.z = -mul(UNITY_MATRIX_V, float4(o.world_vertex, 1.0)).z;
	o.color = v.color * _Color;
    UNITY_TRANSFER_FOG(o,o.screen_vertex);
	UNITY_TRANSFER_INSTANCE_ID(v, o);
	return o;
}