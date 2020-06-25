Shader "Arc/ArcBoozeShader"
{
	Properties{
		_WaterColor("Water Color", Color) = (1, 1, 1, 1)
		_BottleColor("Bottle Color", Color) = (1, 1, 1, 1)
		_PlanePosition ("PlanePosition", Vector) = (0, 0, 0, 1)
		_PlaneNormal("PlaneNormal", Vector) = (0, 1, 0, 0)
		_MainTex("Main Tex", 2D) = "white" {}
		_NoiseTex("Noise Tex", 2D) = "white" {}
		_AlphaScale("Alpha Scale", Range(0, 1)) = 1
		_BumpedStrength("Bump Strength", Range(0, 1)) = 1
		_HeightFactor("HeightFactor", Range(-1, 1)) = 1
	}

		SubShader{
			Tags {"Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent"}

			//瓶子背面
			Pass {
				Tags { "LightMode" = "ForwardBase" }

				cull front
				ZWrite Off
				Blend SrcAlpha OneMinusSrcAlpha

				Stencil
				{
					Ref 1
					Comp Always
					Pass Replace
				}
				
				colormask 0

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

				bool CheckVisible(float3 worldPos) {
					float3 tempModelPos = (0, 0, _HeightFactor);
					float dotProd = dot(worldPos - tempModelPos, _PlaneNormal.xyz);
					return dotProd > 0;
				}

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
					fixed3 worldNormal = (0, 0, 1);
					fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

					fixed4 texColor = tex2D(_MainTex, i.uv);

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

			Pass{ //水面
				Tags { "LightMode" = "ForwardBase" }

				cull off
				ZWrite off
				Blend SrcAlpha OneMinusSrcAlpha
				Stencil
				{
					Ref 1
					Comp Equal
					Pass keep
				}
				CGPROGRAM

				#pragma vertex vert
				#pragma fragment frag
				#pragma target 5.0

				#include "Lighting.cginc"

				fixed4 _WaterColor;
				fixed4 _BottleColor;
				fixed4 _PlanePosition;
				fixed4 _PlaneNormal;
				float _HeightFactor;
				sampler2D _MainTex;
				sampler2D _NoiseTex;
				float4 _MainTex_ST;
				float4 _NoiseTex_ST;
				fixed _AlphaScale;
				fixed _BumpedStrength;

				struct SpringData
				{
					float3 cachedPos;
					float3 cachedWorldPos;
					float3 cachedVelocity;
				};
				uniform RWStructuredBuffer<SpringData> _myWriteBuffer : register(u1);
				uniform RWStructuredBuffer<SpringData> _myReadBuffer : register(u2);

				struct a2v {
					float4 vertex : POSITION;
					float3 normal : NORMAL;
					uint id : SV_VertexID;
					float4 tangent : TANGENT;
					float4 texcoord : TEXCOORD0;
				};

				struct v2f {
					float4 pos : SV_POSITION;
					float3 worldNormal : TEXCOORD0;
					float3 worldPos : TEXCOORD1;
					float4 uv : TEXCOORD2;
					float4 modelPos: TEXCOORD3;
					float3 delta : TEXCOORD4;
					float3x3 world2Tangent : TEXCOORD45;
					
				};

				bool CheckVisible(float3 worldPos) {
					float3 tempModelPos = (0, 0, _HeightFactor);
					float dotProd = dot(worldPos - tempModelPos, _PlaneNormal.xyz);
					return dotProd > 0;
				}

				v2f vert(a2v v) {
					v2f o;

					float3 cachedModelPos = _myReadBuffer[v.id].cachedPos;
					//当前实际在世界坐标下的位置
					float3 lastFrameWorldPos = _myReadBuffer[v.id].cachedWorldPos;
					float3 lastFrameVelocity = _myReadBuffer[v.id].cachedVelocity;

					o.modelPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 0.0));
					float upLerpFactor = clamp(0, 1, 1 - abs(_HeightFactor - o.modelPos.y));
					if (CheckVisible(o.modelPos)) {
						v.vertex.xyz = mul(unity_WorldToObject, float4(o.modelPos.x, _HeightFactor , o.modelPos.z, o.modelPos. w)).xyz;	
					}
					//当前应该在的位置
					o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
					
					float dist = distance(lastFrameWorldPos, o.worldPos);
					float3 deltaMovement = o.worldPos - lastFrameWorldPos;
					float3 normalizedDelta = 0;
					if (length(deltaMovement) > 0.000001) {
						normalizedDelta = normalize(deltaMovement);
					}				
					float3 addVelocity = float3(0.0, deltaMovement.y, 0.0) * 2.0f;
					float3 verticalMoveAdd = float3(0, normalizedDelta.x * normalize(o.modelPos).x + normalizedDelta.z * normalize(o.modelPos).z, 0) * -1.0f;
					float3 curVelocity = (lastFrameVelocity)* pow(0.001f, unity_DeltaTime.x) + addVelocity + verticalMoveAdd;
					float randomFactor = 1 + (tex2Dlod(_NoiseTex, float4(v.texcoord.xy, 0, 0)).r - 0.5) * 0.1;
					if (length(curVelocity) > 0.01f || dist > 0.01f) {
						o.worldPos = float3(o.worldPos.x, lerp(o.worldPos.y, (lastFrameWorldPos + randomFactor * curVelocity * unity_DeltaTime.x).y, upLerpFactor) , o.worldPos.z);
					}
					else {
						curVelocity = float3(0, 0, 0);
					}
					
					v.vertex = mul(unity_WorldToObject, float4(o.worldPos, 1));
					v.vertex.w = 1;

					o.delta = verticalMoveAdd;

					_myWriteBuffer[v.id].cachedPos = v.vertex.xyz;
					_myWriteBuffer[v.id].cachedWorldPos = o.worldPos.xyz;
					_myWriteBuffer[v.id].cachedVelocity = curVelocity;
					
					o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

					o.pos = UnityObjectToClipPos(v.vertex);

					o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
					o.uv.zw = TRANSFORM_TEX(v.texcoord, _NoiseTex);

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
					fixed3 unpackedWorldNormal = UnpackNormal(tex2D(_NoiseTex, i.uv.zw));

					fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

					fixed4 texColor = tex2D(_MainTex, i.uv.xy);

					fixed3 albedo = texColor.rgb * _WaterColor.rgb;

					fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

					fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(worldNormal, worldLightDir));

					//return fixed4(i.delta, _WaterColor.a * _AlphaScale);
					return fixed4(ambient + diffuse, _WaterColor.a * _AlphaScale);
				}

				ENDCG
			}

			//瓶子
			Pass {
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
			}

			////瓶子正面
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