Shader "Arc/ArcBoozeShader"
{
	Properties{
		_WaterColor("Water Color", Color) = (1, 1, 1, 1)
		_BottleColor("Bottle Color", Color) = (1, 1, 1, 1)
		_PlanePosition ("PlanePosition", Vector) = (0, 0, 0, 1)
		_PlaneNormal("PlaneNormal", Vector) = (0, 1, 0, 0)
		_MainTex("Main Tex", 2D) = "white" {}
		_WaterNormalMap("Water Surface Normal Tex", 2D) = "white" {}
		_AlphaScale("Alpha Scale", Range(0, 1)) = 1
		_BumpedStrength("Bump Strength", Range(0, 1)) = 1
		_HeightFactor("HeightFactor", Range(-1, 1)) = 1
	}

		SubShader{
			Tags {"Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent"}

			

			Pass { //水面
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
				fixed4 _PlanePosition;
				fixed4 _PlaneNormal;
				float _HeightFactor;
				sampler2D _MainTex;
				sampler2D _WaterNormalMap;
				float4 _MainTex_ST;
				float4 _WaterNormalMap_ST;
				fixed _AlphaScale;
				fixed _BumpedStrength;

				struct a2v {
					float4 vertex : POSITION;
					float3 normal : NORMAL;
					float4 tangent : TANGENT;
					float4 texcoord : TEXCOORD0;
				};

				struct v2f {
					float4 pos : SV_POSITION;
					float3 worldNormal : TEXCOORD0;
					float3 worldPos : TEXCOORD1;
					float4 uv : TEXCOORD2;
					float4 modelPos: TEXCOORD3;
					float3x3 world2Tangent : TEXCOORD4;
				};

				bool CheckVisible(float3 worldPos) {
					float3 tempModelPos = (0, 0, _HeightFactor);
					//float3 tempModelPos = _PlanePosition.rgb;
					float dotProd = dot(worldPos - tempModelPos, _PlaneNormal.xyz);
					return dotProd > 0;
				}

				v2f vert(a2v v) {
					v2f o;
					o.modelPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 0.0));
					if (CheckVisible(o.modelPos)) {
						v.vertex.xy = mul(float4(o.modelPos.x, _HeightFactor, o.modelPos.z, o.modelPos.w), unity_WorldToObject).xy;
					}
					o.pos = UnityObjectToClipPos(v.vertex);

					o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

					o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
					o.uv.zw = TRANSFORM_TEX(v.texcoord, _WaterNormalMap);

					

					/*if (o.worldPos.y > o.modelPos.y) {
						o.worldPos.y = o.modelPos.y;
					}*/

					fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
					fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
					fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;
					float3x3 worldToTangent = float3x3(worldTangent, worldBinormal, worldNormal);

					o.worldNormal = mul(worldToTangent, _PlaneNormal);
					o.world2Tangent = worldToTangent;

					return o;
				}

				fixed4 frag(v2f i) : SV_Target {
					fixed3 worldNormal = (0, 0, 1);
					fixed3 unpackedWorldNormal = UnpackNormal(tex2D(_WaterNormalMap, i.uv.zw));
					//fixed3 worldNormal = normalize(i.worldNormal) + (mul(i.world2Tangent, unpackedWorldNormal) - (0.5,0.5,0.5))*2 * _BumpedStrength;
					
					//worldNormal = mul(i.world2Tangent, unpackedWorldNormal);

					fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

					fixed4 texColor = tex2D(_MainTex, i.uv.xy);

					fixed3 albedo = texColor.rgb * _WaterColor.rgb;

					fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

					fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(worldNormal, worldLightDir));

					if (CheckVisible(i.modelPos)) {
						//discard;
					}

					return fixed4(ambient + diffuse, _WaterColor.a * _AlphaScale);
				}

				ENDCG
			}

			/*Pass {
				Tags { "LightMode" = "ForwardBase" }


				cull front
				ZWrite off
				Blend SrcAlpha OneMinusSrcAlpha

				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag

				#include "Lighting.cginc"

				fixed4 _BottleColor;
				fixed _AlphaScale;

				struct a2v {
					float4 vertex : POSITION;
				};

				struct v2f {
					float4 pos : SV_POSITION;
				};

				v2f vert(a2v v) {
					v2f o;
					o.pos = UnityObjectToClipPos(v.vertex);
					return o;
				}

				fixed4 frag(v2f i) : SV_Target {
					return fixed4(_BottleColor.rgb, _BottleColor.a * _AlphaScale);
				}

				ENDCG
			}*/

			//Pass {
			//	Tags { "LightMode" = "ForwardBase" }

			//	cull back
			//	ZWrite off
			//	Blend SrcAlpha OneMinusSrcAlpha

			//	CGPROGRAM

			//	#pragma vertex vert
			//	#pragma fragment frag

			//	#include "Lighting.cginc"

			//	fixed4 _WaterColor;
			//	fixed4 _BottleColor;
			//	fixed4 _PlanePosition;
			//	fixed4 _PlaneNormal;
			//	float _HeightFactor;
			//	sampler2D _MainTex;
			//	float4 _MainTex_ST;
			//	fixed _AlphaScale;

			//	struct a2v {
			//		float4 vertex : POSITION;
			//		float3 normal : NORMAL;
			//		float4 texcoord : TEXCOORD0;
			//	};

			//	struct v2f {
			//		float4 pos : SV_POSITION;
			//		float3 worldNormal : TEXCOORD0;
			//		float3 worldPos : TEXCOORD1;
			//		float2 uv : TEXCOORD2;
			//		float4 modelPos: TEXCOORD3;
			//	};

			//	bool CheckVisible(float3 worldPos) {
			//		float3 tempModelPos = (0, 0, _HeightFactor);
			//		//float3 tempModelPos = _PlanePosition.rgb;
			//		float dotProd = dot(worldPos - tempModelPos, _PlaneNormal.xyz);
			//		return dotProd > 0;
			//	}

			//	v2f vert(a2v v) {
			//		v2f o;
			//		o.pos = UnityObjectToClipPos(v.vertex);

			//		o.worldNormal = UnityObjectToWorldNormal(v.normal);

			//		o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

			//		o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

			//		o.modelPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 0.0));
			//		//o.modelPos = v.vertex;
			//		return o;
			//	}

			//	fixed4 frag(v2f i) : SV_Target {
			//		fixed3 worldNormal = normalize(i.worldNormal);
			//		fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

			//		fixed4 texColor = tex2D(_MainTex, i.uv);

			//		fixed3 albedo = texColor.rgb * _WaterColor.rgb;

			//		fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

			//		fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(worldNormal, worldLightDir));

			//		if (CheckVisible(i.modelPos)) {
			//			discard;
			//		}

			//		return fixed4(ambient + diffuse, _WaterColor.a * _AlphaScale);
			//	}

			//	ENDCG
			//}
		}
			FallBack "Transparent/VertexLit"
}