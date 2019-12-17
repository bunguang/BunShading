// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 12/Motion Blur With Depth Texture" {
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _BlurSize ("Blur Size", Float) = 1.0
    }
    SubShader {
    	CGINCLUDE

    	#include "UnityCG.cginc"

    	sampler2D _MainTex;
    	half4 _MainTex_TexelSize;
    	sampler2D _CameraDepthTexture;
    	float4x4 _PreviousViewProjectionMatrix;
    	float4x4 _CurrentViewProjectionInverseMatrix;
        half _BlurSize;

        struct v2f {
        	float4 pos : SV_POSITION;
            half2 uv : TEXCOORD0;
            half2 uv_depth : TEXCOORD1;
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

            return o;
        }

        fixed4 frag(v2f i) : SV_Target {
            float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth);
            #if defined(UNITY_REVERSED_Z)
				d = 1.0 - d;
			#endif
            float4 H = float4(i.uv.x * 2 - 1, i.uv.y * 2 - 1, d * 2 - 1, 1);  // NDC坐标
            float4 D = mul(_CurrentViewProjectionInverseMatrix, H);
            float4 worldPos = D / D.w;  // 世界坐标

            float4 currentPos = H;  // 当前帧NDC坐标
            float4 previousPos = mul(_PreviousViewProjectionMatrix, worldPos);
            previousPos /= previousPos.w;  // 上一帧NDC坐标

            float2 velocity = (currentPos.xy - previousPos.xy)/2.0f;
			
			float2 uv = i.uv;
			float vecColRate[3] = { 0.5,0.3,0.2 };
			float4 c = tex2D(_MainTex, uv) * vecColRate[0];
			uv += velocity * _BlurSize;
			for (int it = 1; it < 3; it++, uv += velocity * _BlurSize) {
				float4 currentColor = tex2D(_MainTex, uv);
				c += currentColor * vecColRate[it];
			}

            return fixed4(c.rgb, 1.0);  
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