Shader "Arc/ArcBoozeShader"
{
	Properties{
		_WaterColor("Water Color", Color) = (1, 1, 1, 1)
		_BottleColor("Bottle Color", Color) = (1, 1, 1, 1)
		_PlaneNormal("PlaneNormal", Vector) = (0, 1, 0, 0)
		_MainTex("Main Tex", 2D) = "white" {}
		_NoiseTex("Noise Tex", 2D) = "white" {}
		_AlphaScale("Alpha Scale", Range(0, 1)) = 1
		_HeightFactor("HeightFactor", Float) = 1
	}

		SubShader{
			Tags {"Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent"}

			//用于裁剪液体
			Pass {
				cull front
				ZWrite Off

				Stencil
				{
					Ref 1
					Comp Always
					Pass Replace
				}
				
				colormask 0
			}

			Pass{ //水面
				Tags { "LightMode" = "ForwardBase" }

				cull back
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
				fixed4 _PlaneNormal;
				float _HeightFactor;
				sampler2D _MainTex;
				sampler2D _NoiseTex;
				float4 _MainTex_ST;
				float4 _NoiseTex_ST;
				fixed _AlphaScale;

				struct SpringData
				{
					float3 cachedWorldPos;
					float3 cachedVelocity;
				};
				uniform RWStructuredBuffer<SpringData> _myWriteBuffer : register(u1);
				uniform RWStructuredBuffer<SpringData> _myReadBuffer : register(u2);

				struct a2v {
					float4 vertex : POSITION;
					float4 texcoord : TEXCOORD0;
					float3 normal : NORMAL;
					uint id : SV_VertexID;
				};

				struct v2f {
					float4 pos : SV_POSITION;
					float4 modelPosRH: TEXCOORD0;
					float3 worldNormal : TEXCOORD1;
					float3 worldPos : TEXCOORD2;	
					float3 debugValue : TEXCOORD3;	
					float2 uv : TEXCOORD4;
				};
				
				v2f vert(a2v v) {
					v2f o;

					//当前实际在世界坐标下的位置
					float3 lastFrameWorldPos = _myReadBuffer[v.id].cachedWorldPos;
					float3 lastFrameVelocity = _myReadBuffer[v.id].cachedVelocity;

					//把模型压到高度平面
					o.modelPosRH = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 0.0));
					float upLerpFactor = clamp(0, 1, 1 - abs(_HeightFactor - o.modelPosRH.y));
					if (o.modelPosRH.y > _HeightFactor) {
						v.vertex.xyz = mul(unity_WorldToObject, float4(o.modelPosRH.x, _HeightFactor , o.modelPosRH.z, o.modelPosRH. w)).xyz;	
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
					float3 verticalMoveAdd = float3(0, normalizedDelta.x * normalize(o.modelPosRH).x + normalizedDelta.z * normalize(o.modelPosRH).z, 0) * -1.0f;
					float3 curVelocity = (lastFrameVelocity)* pow(0.001f, unity_DeltaTime.x) + addVelocity + verticalMoveAdd;
					float randomFactor = 1 + (tex2Dlod(_NoiseTex, float4(v.texcoord.xy, 0, 0)).r - 0.5) * 1;
					if (length(curVelocity) > 0.01f || dist > 0.01f) {
						o.worldPos = float3(o.worldPos.x, lerp(o.worldPos.y, (lastFrameWorldPos + randomFactor * curVelocity * unity_DeltaTime.x).y, upLerpFactor) , o.worldPos.z);
					}
					else {
						curVelocity = float3(0, 0, 0);
					}
					
					v.vertex = mul(unity_WorldToObject, float4(o.worldPos, 1));

					o.debugValue = verticalMoveAdd;

					_myWriteBuffer[v.id].cachedWorldPos = o.worldPos.xyz;
					_myWriteBuffer[v.id].cachedVelocity = curVelocity;

					o.pos = UnityObjectToClipPos(v.vertex);

					o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
		
					o.worldNormal = UnityObjectToWorldNormal(v.normal);

					return o;
				}

				fixed4 frag(v2f i) : SV_Target {
					fixed3 worldNormal = normalize(i.worldNormal);

					if (i.modelPosRH.y > _HeightFactor) {
						worldNormal = lerp(float3(0, 1.0, 0), worldNormal, i.modelPosRH.x * i.modelPosRH.x + i.modelPosRH.z * i.modelPosRH.z);
					}

					fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

					fixed4 texColor = tex2D(_MainTex, i.uv);

					fixed3 albedo = texColor.rgb * _WaterColor.rgb;

					fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

					fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(worldNormal, worldLightDir));

					//return fixed4(i.worldNormal, _WaterColor.a * _AlphaScale);
					return fixed4(diffuse + ambient, _WaterColor.a * _AlphaScale);
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

		}
		FallBack "Transparent/VertexLit"
}