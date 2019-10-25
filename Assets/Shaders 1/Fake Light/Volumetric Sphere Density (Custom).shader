// Original Volumetric Sphere Density by iq
// http://www.iquilezles.org/www/articles/spheredensity/spheredensity.htm
// Unity version by 1001
// Cleaned up/useability tweaks/instancing support by Silent

Shader "Fake Light/Volumetric Sphere Density (Custom)"
{
	Properties
	{
		[HDR]_Color ("Color", Color) = (1.0, 1.0, 1.0, 1.0) 
		[Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Float) = 0

        [Enum(UnityEngine.Rendering.BlendMode)]
        _SrcBlend("Src Factor", Float) = 1  // SrcAlpha
        [Enum(UnityEngine.Rendering.BlendMode)]
        _DstBlend("Dst Factor", Float) = 10 // OneMinusSrcAlpha
	}
	Subshader
	{
		Tags { "Queue"="Transparent-194" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" "DisableBatching"="True"}
		LOD 100
		Cull[_CullMode]
        Blend[_SrcBlend][_DstBlend]
		ZWrite Off ZTest Always
		Lighting Off
		SeparateSpecular Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vertex_shader
			#pragma fragment pixel_shader
			#pragma target 5.0
            #pragma multi_compile_instancing
			#pragma multi_compile_fog    
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma instancing_options assumeuniformscaling 

			UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

			#include "UnityCG.cginc"

			float4 _Color;
			#include "FakeLight.cginc"

            float _Falloff;

			fixed4 pixel_shader(v2f ps) : SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(ps);
                fixed3 viewDirection = normalize(ps.world_vertex-_WorldSpaceCameraPos.xyz);

				fixed3 baseWorldPos = unity_ObjectToWorld._m03_m13_m23;

				float sceneDepth = CorrectedLinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(ps.projPos)), ps.ray.w);
				float3 depthPosition = sceneDepth * ps.ray / ps.projPos.z + _WorldSpaceCameraPos;

				float sphered = renderVolumetricSphere(baseWorldPos, viewDirection, depthPosition);
				fixed3 finalColor = ps.color * sphered;
				float finalAlpha = ps.color.a * saturate(sphered);

				// Call Unity fog functions directly to apply fog properly.
				// Calculate fog factor from depth.
                UNITY_CALC_FOG_FACTOR_RAW(sceneDepth); // out: unityFogFactor
                #if 0 // Non-additive blend?
                // Lerp result to fog colour by fog factor
                UNITY_FOG_LERP_COLOR(finalColor,unity_FogColor,unityFogFactor);
                finalAlpha *= saturate(unityFogFactor);
                #else // Additive blend?
                UNITY_FOG_LERP_COLOR(finalColor,float3(0,0,0),unityFogFactor);
                #endif

				return fixed4(finalColor, finalAlpha);
			}
			ENDCG
		}
	}
}