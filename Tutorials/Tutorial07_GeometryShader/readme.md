# Tutorial07 - Geometry Shader

This tutorial is based on Tutorial03 and shows how to use geometry shader to render smooth wireframe.

![](Screenshot.png)

Geometry shader is a programmable stage that resides between vertex and pixel shaders (it can also 
be used with hardware tessellation, in which case it resides between domain shader and pixel shader). 
While vertex shader processes individual vertices and pixel shader handles pixel, geometry shader operates
with full primitives.

## Shaders

Vertex shader in this tutorial is mostly identical to that of Tutorial03. The only difference is that
the shader uses `#include` directive to include file with definitons of common structures.

Geometry shader processes entire triangles. It fist computes the triangle area that is used to
determine the distance from every vertex to the opposite edge. The distances are then
interpolated across the triangle surface which allows the pixel shader to compute the distance
to the closest edge. Outputs from the vertex shader are passed through to the pixel shader
without changes.

```hlsl
[maxvertexcount(3)]
void main(triangle VSOutput In[3], 
          inout TriangleStream<GSOutput> triStream )
{
    // Compute screen-space position of every vertex
    float2 v0 = g_Constants.ViewportSize.xy * In[0].Pos.xy / In[0].Pos.w;
    float2 v1 = g_Constants.ViewportSize.xy * In[1].Pos.xy / In[1].Pos.w;
    float2 v2 = g_Constants.ViewportSize.xy * In[2].Pos.xy / In[2].Pos.w;
    float2 edge0 = v2 - v1;
    float2 edge1 = v2 - v0;
    float2 edge2 = v1 - v0;
    // Compute triangle area
    float area = abs(edge1.x*edge2.y - edge1.y * edge2.x);

    GSOutput Out;

    Out.VSOut = In[0];
    // Distance to edge0
    Out.DistToEdges = float3(area/length(edge0), 0.0, 0.0);
    triStream.Append( Out );

    Out.VSOut = In[1];
    // Distance to edge1
    Out.DistToEdges = float3(0.0, area/length(edge1), 0.0);
    triStream.Append( Out );

    Out.VSOut = In[2];
    // Distance to edge2
    Out.DistToEdges = float3(0.0, 0.0, area/length(edge2));
    triStream.Append( Out );
}
```

As it was already mentioned, fragment shader computes the distance to the 
closest edge and uses this value to determine the edge intensity.

```hlsl
float4 main(GSOutput ps_in) : SV_TARGET
{
    float4 Color = g_Texture.Sample(g_Texture_sampler, ps_in.VSOut.uv);
    
    // Compute distance to the closest edge
    float minDist = min(ps_in.DistToEdges.x, ps_in.DistToEdges.y);
    minDist = min(minDist, ps_in.DistToEdges.z);

    float lineWidth = g_Constants.LineWidth;
    float lineIntensity = saturate((lineWidth - minDist) / lineWidth);

    float3 EdgeColor = float3(0.0, 0.0, 0.0);
    Color.rgb = lerp(Color.rgb, EdgeColor, lineIntensity);

    return Color;
}
```

## Initializing the Pipeline State and Rendering

Pipeline state initialization is the same as in Tutorial03, with the only difference being
initialzation of the geometry shader:

```cpp
// Create geometry shader
RefCntAutoPtr<IShader> pGS;
{
    CreationAttribs.Desc.ShaderType = SHADER_TYPE_GEOMETRY;
    CreationAttribs.EntryPoint = "main";
    CreationAttribs.Desc.Name = "Cube GS";
    CreationAttribs.FilePath = "cube.gsh";
    pDevice->CreateShader(CreationAttribs, &pGS);
    pGS->GetShaderVariable("GSConstants")->Set(m_ShaderConstants);
}

// ...

PSODesc.GraphicsPipeline.pVS = pVS;
PSODesc.GraphicsPipeline.pGS = pGS;
PSODesc.GraphicsPipeline.pPS = pPS;
pDevice->CreatePipelineState(PSODesc, &m_pPSO);
```

Rendering is performed in the same way as in Tutorial03.