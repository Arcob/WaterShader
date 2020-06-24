Shader "Arc/ArcSimpleWater"
{
	Properties{
		_WaterColor("Water Color", Color) = (1, 1, 1, 1)
		_BottleColor("Bottle Color", Color) = (1, 1, 1, 1)
		_MainTex("Main Tex", 2D) = "white" {}
		_AlphaScale("Alpha Scale", Range(0, 1)) = 1
		_HeightFactor("HeightFactor", Range(-1, 1)) = 1
	}
		SubShader{
			Tags {"Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent"}

			// Extra pass that renders to depth buffer only
			/*Pass {
				ZWrite On
				ColorMask 0
			}*/

			Pass {
				Tags { "LightMode" = "ForwardBase" }

				cull front
				ZWrite off
				Blend SrcAlpha OneMinusSrcAlpha

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#include "Lighting.cginc"

				fixed4 _WaterColor;
				fixed4 _BottleColor;
				float _HeightFactor;
				sampler2D _MainTex;
				float4 _MainTex_ST;
				fixed _AlphaScale;

				struct a2v {
					float4 vertex : POSITION;
					float3 normal : NORMAL;
					float4 texcoord : TEXCOORD0;
				};

				struct v2f {
					float4 pos : SV_POSITION;
					float3 worldNormal : TEXCOORD0;
					float3 worldPos : TEXCOORD1;
					float2 uv : TEXCOORD2;
					float4 modelPos: TEXCOORD3;
				};

				v2f vert(a2v v) {
					v2f o;
					o.pos = UnityObjectToClipPos(v.vertex);

					o.worldNormal = UnityObjectToWorldNormal(v.normal);

					o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

					o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

					o.modelPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 0.0));
					//o.modelPos = v.vertex;
					return o;
				}

				fixed4 frag(v2f i) : SV_Target {
					fixed3 worldNormal = normalize(i.worldNormal);
					fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

					fixed4 texColor = tex2D(_MainTex, i.uv);

					fixed3 albedo = texColor.rgb * _WaterColor.rgb;

					fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

					fixed3 diffuse = _LightColor0.rgb * albedo;// * max(0, dot(worldNormal, worldLightDir));
					clip(texColor.a * _AlphaScale - 0.1);
					fixed3 addColor = _BottleColor.rgb;
					fixed alpha = _BottleColor.a;
					if (i.modelPos.y < _HeightFactor) {
						addColor = _WaterColor.rgb;
						alpha = _WaterColor.a;
					}

					return fixed4(addColor, texColor.a * _AlphaScale * alpha);
				}

				ENDCG
			}

			Pass {
				Tags { "LightMode" = "ForwardBase" }

				cull back
				ZWrite off
				Blend SrcAlpha OneMinusSrcAlpha

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#include "Lighting.cginc"

				fixed4 _WaterColor;
				fixed4 _BottleColor;
				float _HeightFactor;
				sampler2D _MainTex;
				float4 _MainTex_ST;
				fixed _AlphaScale;

				struct a2v {
					float4 vertex : POSITION;
					float3 normal : NORMAL;
					float4 texcoord : TEXCOORD0;
				};

				struct v2f {
					float4 pos : SV_POSITION;
					float3 worldNormal : TEXCOORD0;
					float3 worldPos : TEXCOORD1;
					float2 uv : TEXCOORD2;
					float4 modelPos: TEXCOORD3;
				};

				v2f vert(a2v v) {
					v2f o;
					o.pos = UnityObjectToClipPos(v.vertex);

					o.worldNormal = UnityObjectToWorldNormal(v.normal);

					o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

					o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

					o.modelPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 0.0));
					//o.modelPos = v.vertex;
					return o;
				}

				fixed4 frag(v2f i) : SV_Target {
					fixed3 worldNormal = normalize(i.worldNormal);
					fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

					fixed4 texColor = tex2D(_MainTex, i.uv);

					fixed3 albedo = texColor.rgb * _WaterColor.rgb;

					fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

					fixed3 diffuse = _LightColor0.rgb * albedo;// * max(0, dot(worldNormal, worldLightDir));
					clip(texColor.a * _AlphaScale - 0.1);
					fixed3 addColor = _BottleColor.rgb;
					fixed alpha = _BottleColor.a;
					if (i.modelPos.y < _HeightFactor) {
						addColor = _WaterColor.rgb;
						alpha = _WaterColor.a;
					}

					return fixed4(addColor, texColor.a * _AlphaScale * alpha);
				}

				ENDCG
			}
		}
			FallBack "Transparent/VertexLit"
}