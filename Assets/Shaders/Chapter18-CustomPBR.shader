Shader "Unity Shaders Book/Chapter 18/Custom PBR" {
	Properties{
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Albedo", 2D) = "white" {}
		_BumpMap ("Normal Map", 2D) = "bump" {}  // 提醒下，一般我们使用的凹凸贴图，法线信息一般是以切线空间的形式存在的
		_BumpScale ("Bump Scale", Float) = 1.0
		_Glossiness ("Smoothness", Range(0.0, 1.0)) = 1.0
		_SpecColor ("Specular", Color) = (0.2, 0.2, 0.2)
		_SpecGlossMap ("Specular (RGB) Smoothness (A)", 2D) = "white" {}
		_EmissionColor ("Emission Color", Color) = (0, 0, 0)
		_EmissionMap ("Emission", 2D) = "white" {}
	}
	
	SubShader {
		Tags {"RenderType"="Opaque"}
		LOD 300

		Pass {
			Tags {"LightMode"="ForwardBase"}

			CGPROGRAM

			#pragma target 3.0
			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog

            #pragma vertex vert
            #pragma fragment frag

			#include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "HLSLSupport.cginc"

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            float _BumpScale;
            fixed _Glossiness;
            sampler2D _SpecGlossMap;
            float4 _SpecGlossMap_ST;
            fixed4 _EmissionColor;
            sampler2D _EmissionMap;
            float4 _EmissionMap_ST;

			struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };
            
            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 TtoW0 : TEXCOORD1;  
                float4 TtoW1 : TEXCOORD2;  
                float4 TtoW2 : TEXCOORD3;
                SHADOW_COORDS(4)
                UNITY_FOG_COORDS(5)
            };

            v2f vert(a2v v) {
            	v2f o;
            	UNITY_INITIALIZE_OUTPUT(v2f, o);

            	o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
                
                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
                
                TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o, o.pos);
                
                return o;
            }

            inline half3 CustomDisneyDiffuseTerm(half nv, half nl, half lh, half roughness, half3 baseColor) {
                // 依照Disney BRDF 中漫反射项公式进行计算
                half fd90 = 0.5 + 2 * lh * lh * roughness;

                half lightScatter = (1 + (fd90 - 1) * pow(1 - nl, 5));
                half viewScatter = (1 + (fd90 - 1) * pow(1 - nv, 5));

                return baseColor * UNITY_INV_PI * lightScatter * viewScatter;
            }

            inline half CustomSmithJointGGXVisibilityTerm(half nl, half nv, half roughness) {
                // 使用简化后的Smith-Joint函数，取消掉开方计算
                half a2 = roughness * roughness;
                half lambdaV = nl * (nv * (1 - a2) + a2);
                half lambdaL = nv * (nl * (1 - a2) + a2);

                return 0.5f / (lambdaL + lambdaV + 1e-5f);
            }

            inline half CustomGGXTerm(half nh, half roughness) {
                half a = roughness * roughness;
                half a2 = a * a;
                half d = (nh * a2 - nh) * nh + 1.0f;
                return UNITY_INV_PI * a2 / (d * d + 1e-7f);
            }

            inline half3 CustomFresnelTerm(half3 c, half cosA) {
                half t = pow(1 - cosA, 5);
                return c + (1 - c) * t;
            }

            inline half3 CustomFresnelLerp(half3 c0, half3 c1, half cosA) {
                half t = pow(1 - cosA, 5);
                return lerp(c0, c1, t);
            }

            half4 frag(v2f i) : SV_Target {
                // 1.准备输入数据==========================================
                half4 specGloss = tex2D(_SpecGlossMap, i.uv);
                specGloss.a *= _Glossiness;
                half3 specColor = specGloss.rgb * _SpecColor.rgb;  // 高光反射颜色（底色）
                half roughness = 1 - specGloss.a;  // 粗糙度

                half oneMinusReflectivity = 1 - max(max(specColor.r, specColor.g), specColor.b);  // 为了计算边缘掠射角反射颜色而存在的

                half3 diffColor = _Color.rgb * tex2D(_MainTex, i.uv).rgb * oneMinusReflectivity;  // 漫反射颜色（底色）

                half3 normalTangent = UnpackNormal(tex2D(_BumpMap, i.uv));
                normalTangent.xy *= _BumpScale;
                normalTangent.z = sqrt(1.0 - saturate(dot(normalTangent.xy, normalTangent.xy)));
                half3 normalWorld = normalize(half3(dot(i.TtoW0.xyz, normalTangent), dot(i.TtoW1.xyz, normalTangent), dot(i.TtoW2.xyz, normalTangent)));

                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
                half3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
                half3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));

                half3 reflDir = reflect(-viewDir, normalWorld);

                UNITY_LIGHT_ATTENUATION(atten, i, worldPos);

                // 2.开始套公式计算=======================================
                // 2-1.计算各个方向向量角度的余弦值
                half3 halfDir = normalize(lightDir + viewDir);
                half nv = saturate(dot(normalWorld, viewDir));
                half nl = saturate(dot(normalWorld, lightDir));
                half nh = saturate(dot(normalWorld, halfDir));
                half lv = saturate(dot(lightDir, viewDir));
                half lh = saturate(dot(lightDir, halfDir));
                // 2-2.计算漫反射项
                half3 diffuseTerm = CustomDisneyDiffuseTerm(nv, nl, lh, roughness, diffColor);
                // 2-3.计算高光项
                half V = CustomSmithJointGGXVisibilityTerm(nl, nv, roughness);
                half D = CustomGGXTerm(nh, roughness);
                half3 F = CustomFresnelTerm(specColor, lh);
                half3 specularTerm = specColor * F * V * D;
                // 2-4.计算自发光项
                half3 emissionTerm = tex2D(_EmissionMap, i.uv).rgb * _EmissionColor.rgb;
                // 2-5.计算IBL（Image Based Lighting）项
                half perceptualRoughness = roughness * (1.7 - 0.7 * roughness);
                half mip = perceptualRoughness * 6;  // 这里其实不一定要乘以6，默认只要在11以内应该都是可以自己指定的
                half4 envMap = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, mip);
                half grazingTerm = saturate((1 - roughness) + (1 - oneMinusReflectivity));
                half surfaceReduction = 1.0 / (roughness * roughness + 1.0);
                half3 indirectSpecularTerm = surfaceReduction * envMap.rgb * CustomFresnelLerp(specColor, grazingTerm, nv);
                // 2-6.最后合并所有项
                half3 col = emissionTerm + indirectSpecularTerm + UNITY_PI * (diffuseTerm + specularTerm) * _LightColor0.rgb * nl * atten;

                UNITY_APPLY_FOG(i.fogCoord, c.rgb);

                return half4(col, 1);
            }

			ENDCG
		}

	}

	FallBack "Diffuse"
}