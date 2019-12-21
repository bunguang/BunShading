// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 14/Hatching" {
    Properties {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _TileFactor ("Tile Factor", Float) = 1  // 平铺系数，用来控制一定区域内贴图的重复程度（越大越密）
        _Outline ("Outline", Range(0, 1)) = 0.1
        _Hatch0 ("Hatch 0", 2D) = "white" {}
        _Hatch1 ("Hatch 1", 2D) = "white" {}
        _Hatch2 ("Hatch 2", 2D) = "white" {}
        _Hatch3 ("Hatch 3", 2D) = "white" {}
        _Hatch4 ("Hatch 4", 2D) = "white" {}
        _Hatch5 ("Hatch 5", 2D) = "white" {}
    }
    SubShader {
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}

        UsePass "Unity Shaders Book/Chapter 14/Toon Shading/OUTLINE"
        
        Pass { 
            Tags { "LightMode"="ForwardBase" }

            Cull Back

            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fwdbase
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityShaderVariables.cginc"
            
            fixed4 _Color;
            float _TileFactor;
            sampler2D _Hatch0;
            sampler2D _Hatch1;
            sampler2D _Hatch2;
            sampler2D _Hatch3;
            sampler2D _Hatch4;
            sampler2D _Hatch5;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
            }; 
        
            struct v2f {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
                // 本次我们用vert based lighting，所以v2f就不需要传normal了
                fixed3 hatchWeight0 : TEXCOORD1;
                fixed3 hatchWeight1 : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                SHADOW_COORDS(4)
            };
            
            v2f vert(a2v v) {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord.xy * _TileFactor;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
                
                fixed3 worldLightDir = normalize(WorldSpaceLightDir(v.vertex));
                fixed3 worldNormal = normalize(UnityObjectToWorldNormal(v.normal));
                fixed diff = max(0, dot(worldLightDir, worldNormal));

                o.hatchWeight0 = fixed3(0, 0, 0);
                o.hatchWeight1 = fixed3(0, 0, 0);
                float hatchFactor = diff * 7.0;

                if (hatchFactor > 6.0) {
                    // 保留纯白色，啥也不做
                } else if (hatchFactor > 5.0) {
                    o.hatchWeight0.x = hatchFactor - 5.0;
                } else if (hatchFactor > 4.0) {
                    o.hatchWeight0.x = hatchFactor - 4.0;
                    o.hatchWeight0.y = 1 - o.hatchWeight0.x;
                } else if (hatchFactor > 3.0) {
                    o.hatchWeight0.y = hatchFactor - 3.0;
                    o.hatchWeight0.z = 1 - o.hatchWeight0.y;
                } else if (hatchFactor > 2.0) {
                    o.hatchWeight0.z = hatchFactor - 2.0;
                    o.hatchWeight1.x = 1 - o.hatchWeight0.z;
                } else if (hatchFactor > 1.0) {
                    o.hatchWeight1.x = hatchFactor - 1.0;
                    o.hatchWeight1.y = 1 - o.hatchWeight1.x;
                } else {
                    o.hatchWeight1.y = hatchFactor;
                    o.hatchWeight1.z = 1 - o.hatchWeight1.y;
                }
                
                TRANSFER_SHADOW(o);
                
                return o;
            }
            
            fixed4 frag(v2f i) : SV_Target {
                fixed4 hatchTex0 = tex2D(_Hatch0, i.uv) * i.hatchWeight0.x;
                fixed4 hatchTex1 = tex2D(_Hatch1, i.uv) * i.hatchWeight0.y;
                fixed4 hatchTex2 = tex2D(_Hatch2, i.uv) * i.hatchWeight0.z;
                fixed4 hatchTex3 = tex2D(_Hatch3, i.uv) * i.hatchWeight1.x;
                fixed4 hatchTex4 = tex2D(_Hatch4, i.uv) * i.hatchWeight1.y;
                fixed4 hatchTex5 = tex2D(_Hatch5, i.uv) * i.hatchWeight1.z;

                // 计算白色的分量，如果是上面的区间7的话，应该白色分量接近1，其他情况白色分量接近0
                // 之所以用这种算法是因为float不好做等于0的比较，直接拿来和白色相乘可能更优雅
                fixed whiteColor = fixed4(1, 1, 1, 1) * (1 - i.hatchWeight0.x - i.hatchWeight0.y - i.hatchWeight0.z - i.hatchWeight1.x - i.hatchWeight1.y - i.hatchWeight1.z);
                
                fixed4 hatchColor = hatchTex0 + hatchTex1 + hatchTex2 + hatchTex3 + hatchTex4 + hatchTex5 + whiteColor;

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                return fixed4(hatchColor * atten * _Color.rgb, 1.0);
            }
            
            ENDCG
        }
    } 
    FallBack "Diffuse"
}