// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 11/Image Sequence Animation" {
    Properties {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Main Tex", 2D) = "white" {}
        _HorizontalAmount("Horizontal Amount", Float) = 4
        _VerticalAmount("Vertical Amount", Float) = 4
        _Speed ("Speed", Range(1, 100)) = 30
    }
    SubShader {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }

        Pass { 
            Tags { "LightMode"="ForwardBase" }

            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            
            #pragma multi_compile_fwdbase
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            
            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _HorizontalAmount;
            float _VerticalAmount;
            float _Speed;
            
            struct a2v {
                float4 vertex : POSITION;
                float4 texcoord : TEXCOORD0;
            };
            
            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            v2f vert(a2v v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                return o;
            }
            
            fixed4 frag(v2f i) : SV_Target {
                float time = floor(_Time.y * _Speed);  // 这里的speed基本可以理解成播放帧数了
                float row = floor(time / _HorizontalAmount);  // 算出来的数很大，但因为repeat，所以无所谓
                float column = time - row * _HorizontalAmount;

                half2 uv = float2(i.uv.x / _HorizontalAmount, i.uv.y / _VerticalAmount);  // 将UV范围从之前的全图，缩小为现在的区域一小块

                uv.x += column * 1.0f / _HorizontalAmount;  // 列数 * 每一列元素的宽度，就能算出偏移量
                uv.y -= row * 1.0f / _VerticalAmount;  // 往下采样，取到负数，但因为texture为repeat，会采样到正确的坐标

                fixed4 c = tex2D(_MainTex, uv);
                c.rgb *= _Color;

                return c;
            }

            ENDCG
        }
        
    } 
    FallBack "Transparent/VertexLit"
}