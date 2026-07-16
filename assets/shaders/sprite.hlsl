struct VertexInput
{
    float2 position : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float2 offset : TEXCOORD2;
    float2 scale : TEXCOORD3;
    float4 tint : TEXCOORD4;
};

struct VertexOutput
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    float4 tint : TEXCOORD1;
};

Texture2D<float4> sprite_texture : register(t0, space2);
SamplerState sprite_sampler : register(s0, space2);

VertexOutput VSMain(VertexInput input)
{
    VertexOutput output;
    output.position = float4(input.position * input.scale + input.offset, 0.0f, 1.0f);
    output.uv = input.uv;
    output.tint = input.tint;
    return output;
}

float4 PSMain(VertexOutput input) : SV_Target0
{
    return sprite_texture.Sample(sprite_sampler, input.uv) * input.tint;
}

