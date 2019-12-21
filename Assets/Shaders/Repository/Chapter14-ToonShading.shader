// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 14/Toon Shading" {
    Properties {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Main Tex", 2D) = "white" {}
        _Ramp ("Ramp Texture", 2D) = "white" {}
        _Outline ("Outline", Range(0, 1)) = 0.1
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _SpecularScale("Specular Scale", Range(0, 0.1)) = 0.01
    }
    SubShader {
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}

        Pass { 
            NAME "OUTLINE"
            
            Cull Front
            
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            
            float _Outline;
            fixed4 _OutlineColor;
            
            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            }; 
            
            struct v2f {
                float4 pos : SV_POSITION;
            };
            
            v2f vert(a2v v) {
                v2f o;

                float4 pos = float4(UnityObjectToViewPos(v.vertex), 1.0);
                float3 normal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);
                normal.z = -0.5;
                pos = pos + float4(normalize(normal), 0) * _Outline;
                o.pos = mul(UNITY_MATRIX_P, pos);
                
                return o;
            }
            
            fixed4 frag(v2f i) : SV_Target {
                return fixed4(_OutlineColor.rgb, 1);
            }
            
            ENDCG
        }
        
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
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _Ramp;
            fixed4 _Specular;
            fixed _SpecularScale;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
            }; 
        
            struct v2f {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                SHADOW_COORDS(3)
            };
            
            v2f vert(a2v v) {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
                // o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);  
                // o.worldPos = UnityObjectToWorldPos(v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                
                TRANSFER_SHADOW(o);
                
                return o;
            }
            
            fixed4 frag(v2f i) : SV_Target {
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);

                fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
                
                fixed diff = dot(worldNormal, worldLightDir);
                diff = (diff * 0.5 + 0.5);
                // diff = (diff * 0.5 + 0.5) * atten;  // 这一步其实是叫halfLamebert变化，将diff的范围转移到[0, 1]之间
                // 为啥这么早就乘以了atten，不是等到最后光照结果出来后再统一结算阴影吗？
                fixed3 diffuse = _LightColor0.rgb * albedo * tex2D(_Ramp, float2(diff, diff)).rgb;
                diffuse = diffuse * atten;
                
                fixed spec = dot(worldNormal, worldHalfDir);
                fixed w = fwidth(spec) * 2.0; // 求偏微分，也就是相邻片段间值的变化率，具体算法有待研究
                fixed3 specular = _Specular.rgb * lerp(0, 1, smoothstep(-w, w, spec - (1 - _SpecularScale))) * step(0.0001, _SpecularScale);
                // smoothstep(-w, w, spec - (1 - _SpecularScale))，这个计算有点精妙，比较变化率来计算大小，具体算法有待研究
                // step(0.0001, _SpecularScale) 应该是为了解决浮点数精度的问题，当_SpecularScale等于0时可真的取到0
                specular = specular * atten;
                
                return fixed4(ambient + diffuse + specular, 1.0);
            }
            
            ENDCG
        }
    } 
    FallBack "Diffuse"
}