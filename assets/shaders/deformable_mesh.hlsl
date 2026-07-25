struct MeshVertexInput
{
    float2 local_position : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float deformation_weight : TEXCOORD2;
    float2 world_column_0 : TEXCOORD3;
    float2 world_column_1 : TEXCOORD4;
    float2 world_translation : TEXCOORD5;
    float2 deformation_translation : TEXCOORD6;
    float deformation_rotation : TEXCOORD7;
    float2 deformation_scale : TEXCOORD8;
    float4 tint : TEXCOORD9;
    float camera_x_factor : TEXCOORD10;
};

struct VertexOutput
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    float4 tint : TEXCOORD1;
};

cbuffer Camera : register(b0, space1)
{
    float2 camera_center;
    float2 clip_scale;
};

VertexOutput VSMain(MeshVertexInput input)
{
    VertexOutput output;
    float2 scaled = input.local_position * input.deformation_scale;
    float sine_value = sin(input.deformation_rotation);
    float cosine_value = cos(input.deformation_rotation);
    float2 fully_deformed = float2(
        cosine_value * scaled.x - sine_value * scaled.y,
        sine_value * scaled.x + cosine_value * scaled.y) + input.deformation_translation;
    float2 deformed = lerp(input.local_position, fully_deformed, input.deformation_weight);
    float2 world =
        input.world_column_0 * deformed.x +
        input.world_column_1 * deformed.y +
        input.world_translation;
    float2 camera_relative = float2(
        world.x - camera_center.x * input.camera_x_factor,
        world.y - camera_center.y);
    output.position = float4(camera_relative * clip_scale, 0.0f, 1.0f);
    output.uv = input.uv;
    output.tint = input.tint;
    return output;
}
