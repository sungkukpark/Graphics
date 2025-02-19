#ifndef UNITY_BUILTIN_DATA_INCLUDED
#define UNITY_BUILTIN_DATA_INCLUDED

//-----------------------------------------------------------------------------
// BuiltinData
// This structure include common data that should be present in all material
// and are independent from the BSDF parametrization.
// Note: These parameters can be store in GBuffer if the writer wants
//-----------------------------------------------------------------------------

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Debug.hlsl" // Require for GetIndexColor auto generated
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Builtin/BuiltinData.cs.hlsl"

//-----------------------------------------------------------------------------
// Modification Options
//-----------------------------------------------------------------------------
// Due to various transform and conversions that happen, some precision is lost along the way.
// as a result, motion vectors that are close to 0 due to cancellation of components (camera and object) end up not doing so.
// To workaround the issue, if the computed motion vector is less than MICRO_MOVEMENT_THRESHOLD (now 1% of a pixel)
// if  KILL_MICRO_MOVEMENT is == 1, we set the motion vector to 0 instead.
// An alternative could be rounding the motion vectors (e.g. round(motionVec.xy * 1eX) / 1eX) with X varying on how many digits)
// but that might lead to artifacts with mismatch between actual motion and written motion vectors on non trivial motion vector lengths.
#define KILL_MICRO_MOVEMENT
#define MICRO_MOVEMENT_THRESHOLD (0.01f * _ScreenSize.zw)

//-----------------------------------------------------------------------------
// helper macro
//-----------------------------------------------------------------------------

#define BUILTIN_DATA_SHADOW_MASK                    float4(builtinData.shadowMask0, builtinData.shadowMask1, builtinData.shadowMask2, builtinData.shadowMask3)
#ifdef UNITY_VIRTUAL_TEXTURING
    #define ZERO_BUILTIN_INITIALIZE(builtinData)    ZERO_INITIALIZE(BuiltinData, builtinData); builtinData.vtPackedFeedback = real4(1.0f, 1.0f, 1.0f, 1.0f)
#else
    #define ZERO_BUILTIN_INITIALIZE(builtinData)    ZERO_INITIALIZE(BuiltinData, builtinData)
#endif

//-----------------------------------------------------------------------------
// common Encode/Decode functions
//-----------------------------------------------------------------------------

// Guideline for motion vectors buffer.
// The object motion vectors buffer is potentially fill in several pass.
// - In gbuffer pass with extra RT (Not supported currently)
// - In forward prepass pass
// - In dedicated motion vectors pass
// So same motion vectors buffer is use for all scenario, so if deferred define a motion vectors buffer, the same is reuse for forward case.
// THis is similar to NormalBuffer

// EncodeMotionVector / DecodeMotionVector code for now, i.e it must do nothing like it is doing currently.
// Design note: We assume that motion vector/distortion fit into a single buffer (i.e not spread on several buffer)
void EncodeMotionVector(float2 motionVector, out float4 outBuffer)
{
    // RT - 16:16 float
    outBuffer = float4(motionVector.xy, 0.0, 0.0);
}

bool PixelSetAsNoMotionVectors(float4 inBuffer)
{
    return inBuffer.x > 1.0f;
}

void DecodeMotionVector(float4 inBuffer, out float2 motionVector)
{
    motionVector = PixelSetAsNoMotionVectors(inBuffer) ? 0.0f : inBuffer.xy;
}

void EncodeDistortion(float2 distortion, float distortionBlur, bool isValidSource, out float4 outBuffer)
{
    // RT - 16:16:16:16 float
    // distortionBlur in alpha for a different blend mode
    outBuffer = float4(distortion, isValidSource, distortionBlur); // Caution: Blend mode depends on order of attribut here, can't change without updating blend mode.
}

void DecodeDistortion(float4 inBuffer, out float2 distortion, out float distortionBlur, out bool isValidSource)
{
    distortion = inBuffer.xy;
    distortionBlur = inBuffer.a;
    isValidSource = (inBuffer.z != 0.0);
}

void GetBuiltinDataDebug(uint paramId, BuiltinData builtinData, PositionInputs posInput, inout float3 result, inout bool needLinearToSRGB)
{
    GetGeneratedBuiltinDataDebug(paramId, builtinData, result, needLinearToSRGB);

    switch (paramId)
    {
    case DEBUGVIEW_BUILTIN_BUILTINDATA_BAKED_DIFFUSE_LIGHTING:
        // TODO: require a remap
        // TODO: we should not gamma correct, but easier to debug for now without correct high range value
        result = builtinData.bakeDiffuseLighting; needLinearToSRGB = true;
        break;
    case DEBUGVIEW_BUILTIN_BUILTINDATA_DEPTH_OFFSET:
        result = builtinData.depthOffset.xxx * 10.0; // * 10 assuming 1 unity is 1m
        break;
    case DEBUGVIEW_BUILTIN_BUILTINDATA_DISTORTION:
        result = float3((builtinData.distortion / (abs(builtinData.distortion) + 1) + 1) * 0.5, 0.5);
        break;
#ifdef DEBUG_DISPLAY
    case DEBUGVIEW_BUILTIN_BUILTINDATA_RENDERING_LAYERS:
        // HDRP supports up to 16 rendering layers
        uint stripeSize = 8;
        int lightLayers = builtinData.renderingLayers & _DebugLightLayersMask;
        uint layerId = 0, layerCount = countbits(lightLayers);

        result = float3(0, 0, 0);
        for (uint i = 0; (i < 16) && (layerId < layerCount); i++)
        {
            if (lightLayers & (1 << i))
            {
                if ((posInput.positionSS.y / stripeSize) % layerCount == layerId)
                    result = _DebugRenderingLayersColors[i].xyz;
                layerId++;
            }
        }
        break;
#endif
    }
}

#endif // UNITY_BUILTIN_DATA_INCLUDED
