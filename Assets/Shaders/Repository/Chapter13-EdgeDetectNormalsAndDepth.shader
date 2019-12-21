// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 13/Edge Detect Normals And Depth" {
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _EdgeOnly ("Edge Only", Float) = 1.0
        _EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
        _BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
        _SampleDistance ("Sample Distance", Float) = 1.0
        _Sensitivity ("Sensitivity", Vector) = (1, 1, 1, 1)
    }
    SubShader {
    	CGINCLUDE

    	#include "UnityCG.cginc"

    	sampler2D _MainTex;
    	half4 _MainTex_TexelSize;
    	sampler2D _CameraDepthNormalsTexture;
    	fixed _EdgeOnly;
        fixed4 _EdgeColor;
        fixed4 _BackgroundColor;
        float _SampleDistance;
        half4 _Sensitivity;

        struct v2f {
        	float4 pos : SV_POSITION;
            half2 uv[5] : TEXCOORD0;
        };

        v2f vert(appdata_img v) {
        	v2f o;
            o.pos = UnityObjectToClipPos(v.vertex);
            half2 uv = v.texcoord;
            o.uv[0] = uv;

            // 之前的uv坐标是给mainTex采样的，所以不需要翻转
            // 后续的uv坐标是给camera的深度和法线贴图采样的，所以需要反转
            #if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
            	uv.y = 1 - uv.y;
            #endif

            o.uv[1] = uv + _MainTex_TexelSize.xy * half2(1, 1) * _SampleDistance;
            o.uv[2] = uv + _MainTex_TexelSize.xy * half2(-1, -1) * _SampleDistance;
            o.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1, 1) * _SampleDistance;
            o.uv[4] = uv + _MainTex_TexelSize.xy * half2(1, -1) * _SampleDistance;

            return o;
        }

        half CheckSame(half4 center, half4 sample) {
            // 获取法线和深度值
            half2 centerNormal = center.xy;
            float centerDepth = DecodeFloatRG(center.zw);
            half2 sampleNormal = sample.xy;
            float sampleDepth = DecodeFloatRG(sample.zw);

            half2 diffNormal = abs(centerNormal - sampleNormal) * _Sensitivity.x;
            int isSameNormal = (diffNormal.x + diffNormal.y) < 0.1;

            float diffDepth = abs(centerDepth -sampleDepth) * _Sensitivity.y;
            int isSameDepth = diffDepth < 0.1 * centerDepth;  // 这边要做一个等比例scale，因为深度不是归一化的

            return isSameDepth * isSameNormal ? 1.0 : 0.0;  // 返回值只可能是0或1其中一种，要不就是edge，要不就不是edge
        }

        fixed4 frag(v2f i) : SV_Target {
            // 这个算法是使用Roberts算子来进行边缘检测
            half4 sample1 = tex2D(_CameraDepthNormalsTexture, i.uv[1]);
            half4 sample2 = tex2D(_CameraDepthNormalsTexture, i.uv[2]);
            half4 sample3 = tex2D(_CameraDepthNormalsTexture, i.uv[3]);
            half4 sample4 = tex2D(_CameraDepthNormalsTexture, i.uv[4]);

            half edge = 1.0;

            edge *= CheckSame(sample1, sample2);
            edge *= CheckSame(sample3, sample4);

            fixed4 withEdgeColor = lerp(_EdgeColor, tex2D(_MainTex, i.uv[0]), edge);
            fixed4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);

            return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
        }

    	ENDCG

        Pass { 
            
			ZTest Always Cull Off ZWrite Off

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            ENDCG
        }
     
    } 
    FallBack Off
}