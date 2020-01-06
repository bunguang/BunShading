// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 15/Dissovle" {
	Properties {
		_MainTex ("Main Tex", 2D) = "white" {}
		_BumpMap ("Normal Map", 2D) = "bump" {}
		_BurnMap ("Burn Map", 2D) = "white" {}
		_BurnAmount ("Burn Amount", Range(0.0, 1.0)) = 0.0
		_LineWidth ("Burn Line Width", Range(0.0, 0.2)) = 0.1
		_BurnFirstColor ("Burn First Color", Color) = (1, 0, 0, 1)
		_BurnSecondColor ("Burn Second Color", Color) = (1, 0, 0, 1)
	}
	SubShader {
		Tags { "RenderType"="Opaque" "Queue"="Geometry"}
		
		Pass { 
			Tags { "LightMode"="ForwardBase" }

			Cull Off

			CGPROGRAM
			
			#pragma multi_compile_fwdbase	
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			
			sampler2D _MainTex;
			sampler2D _BumpMap;  // 提醒下，一般我们使用的凹凸贴图，法线信息一般是以切线空间的形式存在的
			sampler2D _BurnMap;
			fixed _BurnAmount;
			fixed _LineWidth;
			fixed4 _BurnFirstColor;
			fixed4 _BurnSecondColor;
			
			float4 _MainTex_ST;
			float4 _BumpMap_ST;
			float4 _BurnMap_ST;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uvMainTex : TEXCOORD0;
				float2 uvBumpMap : TEXCOORD1;
				float2 uvBurnMap : TEXCOORD2;
				float3 lightDir : TEXCOORD3;
				float3 worldPos : TEXCOORD4; 
				SHADOW_COORDS(5)
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);

				o.uvMainTex = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uvBumpMap = TRANSFORM_TEX(v.texcoord, _BumpMap);
				o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap);

				TANGENT_SPACE_ROTATION;
				o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;

				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				TRANSFER_SHADOW(o);

				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				fixed3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb;

				clip(burn.r - _BurnAmount);  
				// burn.r越大，纹理中越亮的地方，就越难被消融
				// _BurnAmount越大，图中被消融区域就越多

				float3 tangentLightDir = normalize(i.lightDir);
				fixed3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uvBumpMap));
				// 做一个反方向操作，不知道为啥现在unity版本方向都反了
				tangentNormal.xy *= -1;
				tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
				tangentNormal = normalize(tangentNormal);

				fixed3 albedo = tex2D(_MainTex, i.uvMainTex);

				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));

				fixed t = 1 - smoothstep(0.0, _LineWidth, burn.r - _BurnAmount);
				// burn.r - _BurnAmount 大于 _LineWidth 时，smoothstep返回1，t为0，此时该像素颜色正常
				// burn.r - _BurnAmount 小于 0.0 时，smoothstep返回0，t为1，此时处于消融边界处
				// _LineWidth越大，smoothstep越不容易返回1，烧焦部分也越大
				fixed3 burnColor = lerp(_BurnFirstColor, _BurnSecondColor, t);
				burnColor = pow(burnColor, 5);  // 一个trick，为了更接近烧焦效果

				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

				fixed3 finalColor = lerp(ambient + diffuse * atten, burnColor, t * step(0.0001, _BurnAmount));
				// step(0.0001, _BurnAmount) 应该是为了解决浮点数精度的问题，当_SpecularScale等于0时可真的取到0

				return fixed4(finalColor, 1.0);
			}
			
			ENDCG
		}

		// 这里要额外实现一个cast shadow的pass
		// 因为之前一个pass进行了透明度测试clip，默认的shadow caster已经不灵了，要自定义阴影投射规则
		Pass {

			Tags {"LightMode" = "ShadowCaster"}

			CGPROGRAM

			#pragma multi_compile_shadowcaster	
			
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			
			fixed _BurnAmount;
			sampler2D _BurnMap;
			float4 _BurnMap_ST;

			struct v2f {
				V2F_SHADOW_CASTER;
				float2 uvBurnMap : TEXCOORD1;
			};

			v2f vert( appdata_base v) {
				v2f o;

				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)

				o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap);

				return o;
			}

			fixed4 frag(v2f i) : SV_Target {
				fixed3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb;

				clip(burn.r - _BurnAmount);

				SHADOW_CASTER_FRAGMENT(i);
			}

			ENDCG

		}
		
	} 
	FallBack "Diffuse"
}