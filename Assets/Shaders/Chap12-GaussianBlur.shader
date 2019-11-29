// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 12/Gaussian Blur" {
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _BlurSize ("Blur Size", Float) = 1.0
    }
    SubShader {
    	CGINCLUDE

    	#include "UnityCG.cginc"

    	sampler2D _MainTex;
    	half4 _MainTex_TexelSize;
        fixed _BlurSize;

        struct v2f {
        	float4 pos : SV_POSITION;
            half2 uv[5] : TEXCOORD0;
        };

        v2f vertBlurVertical(appdata_img v) {
        	v2f o;
            o.pos = UnityObjectToClipPos(v.vertex);
            half2 uv = v.texcoord;

            // 这一步其实很聪明，将计算边邻采样纹理坐标放到了vert里，由于计算过程是线性的，vert到frag也是线性的，所以frag拿到的uv也是准确的
            // 类似的把计算放在vert里，通过插值在frag获取精确结果的方案，感觉要比直接在frag里进行计算要节省很多计算资源？！
            o.uv[0] = uv;
            o.uv[1] = uv + float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
            o.uv[2] = uv - float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
            o.uv[3] = uv + float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;
            o.uv[4] = uv - float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;
            return o;
        }

        v2f vertBlurHorizontal(appdata_img v) {
        	v2f o;
            o.pos = UnityObjectToClipPos(v.vertex);
            half2 uv = v.texcoord;

            // 这一步其实很聪明，将计算边邻采样纹理坐标放到了vert里，由于计算过程是线性的，vert到frag也是线性的，所以frag拿到的uv也是准确的
            // 类似的把计算放在vert里，通过插值在frag获取精确结果的方案，感觉要比直接在frag里进行计算要节省很多计算资源？！
            o.uv[0] = uv;
            // 这里的几个uv计算要注意下，不但要取_MainTex_TexelSize的x，而且要把偏移量放到float2的x区……！
            o.uv[1] = uv + float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            o.uv[2] = uv - float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            o.uv[3] = uv + float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;
            o.uv[4] = uv - float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;
            return o;
        }

        fixed4 fragBlur(v2f i) : SV_Target {
        	float weight[3] = {0.4026, 0.2442, 0.0545};

        	fixed3 sum = tex2D(_MainTex, i.uv[0]) * weight[0];

        	for (int it = 1; it < 3; it++) {
        		sum += tex2D(_MainTex, i.uv[it * 2 - 1]).rgb * weight[it];
        		sum += tex2D(_MainTex, i.uv[it * 2]).rgb * weight[it];
        	}

        	return fixed4(sum, 1.0);
        }

    	ENDCG

    	ZTest Always Cull Off ZWrite Off

        Pass { 
            NAME "GAUSSIAN_BLUR_VERTICAL"

            CGPROGRAM

            #pragma vertex vertBlurVertical
            #pragma fragment fragBlur

            ENDCG
        }

        Pass { 
            NAME "GAUSSIAN_BLUR_HORIZONTAL"

            CGPROGRAM

            #pragma vertex vertBlurHorizontal
            #pragma fragment fragBlur
            
            ENDCG
        }
        
    } 
    FallBack Off
}