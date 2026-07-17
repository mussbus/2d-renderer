struct VertexInput
{
    float2 local_position : TEXCOORD0;
    float2 world_position : TEXCOORD1;
    float rotation : TEXCOORD2;
    float2 scale : TEXCOORD3;
    float2 pivot : TEXCOORD4;
    float4 uv_rect : TEXCOORD5;
    float4 tint : TEXCOORD6;
};

struct VertexOutput
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    float4 tint : TEXCOORD1;
};

Texture2D<float4> sprite_texture : register(t0, space2);
SamplerState sprite_sampler : register(s0, space2);

cbuffer Camera : register(b0, space1)
{
    float4 viewport_data;
};

VertexOutput VSMain(VertexInput input)
{
    VertexOutput output;
    float2 pivoted = (input.local_position - input.pivot) * input.scale;
    float sine_value = sin(input.rotation);
    float cosine_value = cos(input.rotation);
    float2 rotated = float2(
        cosine_value * pivoted.x - sine_value * pivoted.y,
        sine_value * pivoted.x + cosine_value * pivoted.y);
    float2 world = rotated + input.world_position;
    float2 clip = world / viewport_data.xy * 2.0f - 1.0f;
    output.position = float4(clip, 0.0f, 1.0f);
    output.uv = float2(
        lerp(input.uv_rect.x, input.uv_rect.z, input.local_position.x),
        lerp(input.uv_rect.w, input.uv_rect.y, input.local_position.y));
    output.tint = input.tint;
    return output;
}

float4 PSMain(VertexOutput input) : SV_Target0
{
    return sprite_texture.Sample(sprite_sampler, input.uv) * input.tint;
}
