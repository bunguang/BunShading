// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 12/Edge Detection" {
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _EdgesOnly ("Edges Only", Float) = 0.0
        _EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
        _BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
    }
    SubShader {
        Pass { 
            ZTest Always Cull Off ZWrite Off

            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment fragSobel
            
            #include "UnityCG.cginc"
            
            sampler2D _MainTex;
            half4 _MainTex_TexelSize;
            fixed _EdgesOnly;  // 0的时候表示边缘叠加在原图上显示，1的时候表示只显示边缘图
            fixed4 _EdgeColor;
            fixed4 _BackgroundColor;

            struct v2f {
                float4 pos : SV_POSITION;
                half2 uv[9] : TEXCOORD0;
            };
            
            v2f vert(appdata_img v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                half2 uv = v.texcoord;

                // 这一步其实很聪明，将计算边邻采样纹理坐标放到了vert里，由于计算过程是线性的，vert到frag也是线性的，所以frag拿到的uv也是准确的
                // 类似的把计算放在vert里，通过插值在frag获取精确结果的方案，感觉要比直接在frag里进行计算要节省很多计算资源？！
                o.uv[0] = uv + _MainTex_TexelSize.xy * half2(-1, -1);
                o.uv[1] = uv + _MainTex_TexelSize.xy * half2(0, -1);
                o.uv[2] = uv + _MainTex_TexelSize.xy * half2(1, -1);
                o.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1, 0);
                o.uv[4] = uv + _MainTex_TexelSize.xy * half2(0, 0);
                o.uv[5] = uv + _MainTex_TexelSize.xy * half2(1, 0);
                o.uv[6] = uv + _MainTex_TexelSize.xy * half2(-1, 1);
                o.uv[7] = uv + _MainTex_TexelSize.xy * half2(0, 1);
                o.uv[8] = uv + _MainTex_TexelSize.xy * half2(1, 1);
                return o;
            }

            fixed luminance(fixed4 color) {
                return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
            }

            half Sobel(v2f i) {
                const half Gx[9] = {-1, -2, -1, 0, 0, 0, 1, 2, 1};
                const half Gy[9] = {-1, 0, 1, -2, 0, 2, -1, 0, 1};

                half texColor;
                half edgeX = 0;
                half edgeY = 0;

                for (int it = 0; it < 9; it++) {
                    texColor = luminance(tex2D(_MainTex, i.uv[it]));
                    edgeX += texColor * Gx[it];
                    edgeY += texColor * Gy[it];
                }

                half edge = 1 - abs(edgeX) - abs(edgeY);

                return edge;
            }

            fixed4 fragSobel(v2f i) : SV_Target {
                half edge = Sobel(i);  // 得到的edge取值越小，表示越可能是一个边缘点

                // edge值越小，颜色越趋向于黑色也就是边缘原色；edge值越大，颜色越趋向于图片本来的颜色
                fixed4 withEdgeColor = lerp(_EdgeColor, tex2D(_MainTex, i.uv[4]), edge);
                // edge值越小，颜色越趋向于黑色也就是边缘原色；edge值越大，颜色越趋向于白色也就是背景颜色
                fixed4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);
                // 通过_EdgeColor，在两种显示模式之间进行切换
                return lerp(withEdgeColor, onlyEdgeColor, _EdgesOnly);

            }
            
            ENDCG
        }
        
    } 
    FallBack Off
}