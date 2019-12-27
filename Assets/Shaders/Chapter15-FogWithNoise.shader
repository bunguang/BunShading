﻿// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 15/Fog With Noise" {
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _FogDensity ("Fog Density", Float) = 1.0
        _FogColor ("Fog Color", Color) = (1, 1, 1, 1)
        _FogStart ("Fog Start", Float) = 0.0
        _FogEnd ("Fog End", Float) = 1.0
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _FogXSpeed ("Fog Horizontal Speed", Float) = 0.1
        _FogYSpeed ("Fog Vertical Speed", Float) = 0.1
        _NoiseAmount ("Noise Amount", Float) = 1.0
    }
    SubShader {
    	CGINCLUDE

    	#include "UnityCG.cginc"

    	sampler2D _MainTex;
    	half4 _MainTex_TexelSize;
    	sampler2D _CameraDepthTexture;
    	half _FogDensity;
        fixed4 _FogColor;
        float _FogStart;
        float _FogEnd;
        float4x4 _FrustumCornersRay;
        sampler2D _NoiseTex;
        float _FogXSpeed;
        float _FogYSpeed;
        float _NoiseAmount;

        struct v2f {
        	float4 pos : SV_POSITION;
            half2 uv : TEXCOORD0;
            half2 uv_depth : TEXCOORD1;
            float4 interpolatedRay : TEXCOORD2;
        };

        v2f vert(appdata_img v) {
        	v2f o;
            o.pos = UnityObjectToClipPos(v.vertex);
            o.uv = v.texcoord;
            o.uv_depth = v.texcoord;

            #if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
            	o.uv_depth.y = 1 - o.uv_depth.y;
            #endif

            int index = 0;
            if (v.texcoord.x < 0.5 && v.texcoord.y < 0.5) {
                index = 0;
            } else if (v.texcoord.x > 0.5 && v.texcoord.y < 0.5) {
                index = 1;
            } else if (v.texcoord.x > 0.5 && v.texcoord.y > 0.5) {
                index = 2;
            } else {
               index = 3;
            }

            #if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
                index = 3 - index;
            #endif
            
            o.interpolatedRay = _FrustumCornersRay[index];

            return o;
        }

        fixed4 frag(v2f i) : SV_Target {
            float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth);
            float linearDepth = LinearEyeDepth(d);
            float3 worldPos = _WorldSpaceCameraPos + linearDepth * i.interpolatedRay.xyz;

            // 正片开始！！！
            // 这种求speed的方法似乎很通用
            float2 speed = _Time.y * float2(_FogXSpeed, _FogYSpeed);  // 友情提示下，_Time变量的四个分量代表了不同速度的时间尺度，其中y变量正好是t
            fixed4 noiseColor = tex2D(_NoiseTex, i.uv + speed);
            float noise = (noiseColor.r - 0.5) * _NoiseAmount;

            float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart);
            fogDensity = saturate(fogDensity * _FogDensity * (1 + noise));
            
            fixed4 finalColor = tex2D(_MainTex, i.uv);
            finalColor.rgb = lerp(finalColor.rgb, _FogColor.rgb, fogDensity);

            return finalColor;  
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