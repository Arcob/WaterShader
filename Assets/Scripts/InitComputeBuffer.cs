using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class InitComputeBuffer : MonoBehaviour
{
    public Material material;
    public MeshFilter meshFilter;
    ComputeBuffer compute_buffer_Alpha;
    ComputeBuffer compute_buffer_Beta;
    Mesh mesh;
    SpringData[] dataA;
    SpringData[] dataB;

    public struct SpringData
    {
        public Vector3 cachedWorldPos;
        public Vector3 cachedVelocity;
    }

    void Awake()
    {
        mesh = meshFilter.sharedMesh;
        dataA = new SpringData[mesh.vertices.Length];
        for (int i = 0; i < dataA.Length; i++)
        {
            dataA[i].cachedWorldPos = meshFilter.transform.TransformPoint(mesh.vertices[i]);
            dataA[i].cachedVelocity = Vector3.zero;
        }
        dataB = new SpringData[mesh.vertices.Length];
        for (int i = 0; i < dataB.Length; i++)
        {
            dataB[i].cachedWorldPos = meshFilter.transform.TransformPoint(mesh.vertices[i]);
            dataB[i].cachedVelocity = Vector3.zero;
        }
        Graphics.ClearRandomWriteTargets();
        compute_buffer_Alpha = new ComputeBuffer(dataA.Length, sizeof(float) * 6, ComputeBufferType.Default);
        
        Graphics.SetRandomWriteTarget(1, compute_buffer_Alpha, false);
        material.SetBuffer("_myWriteBuffer", compute_buffer_Alpha);
        compute_buffer_Alpha.SetData(dataA);

        compute_buffer_Beta = new ComputeBuffer(dataB.Length, sizeof(float) * 6, ComputeBufferType.Default);
        Graphics.SetRandomWriteTarget(2, compute_buffer_Beta, false);
        material.SetBuffer("_myReadBuffer", compute_buffer_Beta);
        compute_buffer_Beta.SetData(dataB);
        tempData1 = new SpringData[mesh.vertices.Length];
    }

    SpringData[] tempData1;

    void Update()
    {
        compute_buffer_Alpha.GetData(tempData1);
        compute_buffer_Beta.SetData(tempData1);
    }
}
