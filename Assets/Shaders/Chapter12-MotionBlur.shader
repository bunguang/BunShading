// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 12/Motion Blur" {
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _BlurAmount ("Blur Amount", Float) = 1.0
    }
    SubShader {
    	CGINCLUDE

    	#include "UnityCG.cginc"

    	sampler2D _MainTex;
        fixed _BlurAmount;

        struct v2f {
        	float4 pos : SV_POSITION;
            half2 uv : TEXCOORD0;
        };

        v2f vert(appdata_img v) {
        	v2f o;
            o.pos = UnityObjectToClipPos(v.vertex);
            o.uv = v.texcoord;
            return o;
        }

        fixed4 fragRGB(v2f i) : SV_Target {
            return fixed4(tex2D(_MainTex, i.uv).rgb, _BlurAmount);
        }

        half4 fragA(v2f i) :SV_Target {
            return tex2D(_MainTex, i.uv);
        }

    	ENDCG

    	ZTest Always Cull Off ZWrite Off

        Pass { 
            Blend SrcAlpha OneMinusSrcAlpha

            // 这里的src指的是当前渲染出来的画面，也就是颜色是当前帧缓冲渲染出来的画面，进行混合时权重为_BlurAmount
            // 这里的dst指的是accumulationTexture，也就是上一帧渲染完的画面，进行混合时权重为1 - _BlurAmount
            // 不过要注意，这里的_BlurAmount其实是在脚本那边，就已经经过一次 1 - blurAmount 的转换了
            // 因此脚本的blurAmount越大，shader的_BlurAmount越小，受到上一帧accumulationTexture的影响也就越大

            ColorMask RGB

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment fragRGB

            ENDCG
        }

        Pass { 
            Blend One Zero

            // 第二个pass的作用很直接，就是为了维护整个渲染前后的颜色buffer中，A值（透明度）不变，即直接用100%的src的A值
            // 为了后续的后处理做准备，以防后续要用A值的时候错误了

            ColorMask A

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment fragA

            ENDCG
        }
        
    } 
    FallBack Off
}