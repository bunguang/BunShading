Shader "Unity Shaders Book/Chapter 17/Bumped Diffuse" {
    Properties {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}  // 提醒下，一般我们使用的凹凸贴图，法线信息一般是以切线空间的形式存在的
        _BumpScale ("Bump Scale", Float) = 1.0
    }
    SubShader {
        Tags { "RenderType"="Opaque" }

        LOD 300

        CGPROGRAM
        #pragma surface surf Lambert
        #pragma target 3.0

        sampler2D _MainTex;
        sampler2D _BumpMap;
        fixed4 _Color;
        float _BumpScale;

        struct Input {
        	float2 uv_MainTex;
        	float2 uv_BumpMap;
        };

        void surf(Input IN, inout SurfaceOutput o) {
        	fixed4 tex = tex2D(_MainTex, IN.uv_MainTex);
        	o.Albedo = tex.rgb * _Color.rgb;
        	o.Alpha = tex.a * _Color.a;
        	o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
        }

        ENDCG
        
    } 
    FallBack "Legacy Shaders/Diffuse"
}