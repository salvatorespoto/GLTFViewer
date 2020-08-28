static const float PI = 3.14159265f;

static const uint MESH_CONSTANTS_N_DESCRIPTORS = 15;
static const uint MATERIALS_N_DESCRIPTORS = 15;
static const uint TEXTURES_N_DESCRIPTORS = 15;
static const uint SAMPLERS_N_DESCRIPTORS = 15;
static const uint MAX_LIGHT_NUMBER = 7;

static const float3 dielectricSpecular = { 0.04f, 0.04f, 0.04f };
static const float3 black = { 0.0f, 0.0f, 0.0f };

struct Light
{
    float4 position;
    float4 color;
};

struct FrameConstants
{
    float4x4 viewMtx;
    float4x4 projMtx;
    float4x4 viewProjMtx;
    float4 eyePosition;
    Light lights[MAX_LIGHT_NUMBER];
};

struct MeshConstants
{
    float4x4 modelMtx;
    float4 rotationXYZ; // rotations about X, Y and Z axes. Fourth component unused;
};

struct TextureAccessor
{
    uint textureId; float3 _pad0;
    uint texCoordId; float3 _pad1;
};

struct RoughMetallicMaterial
{
    float4 baseColorFactor;
    float metallicFactor; float3 _pad0;
    float roughnessFactor; float3 _pad1;
    TextureAccessor baseColorTA;
    TextureAccessor roughMetallicTA;
    TextureAccessor normalTA;
    TextureAccessor emissiveTA;
    TextureAccessor occlusionTA;
};

FrameConstants frameConstants : register(b0, space0);
ConstantBuffer<MeshConstants> meshConstants : register(b1, space0);
ConstantBuffer<RoughMetallicMaterial> materials[MATERIALS_N_DESCRIPTORS]  : register(b0, space1);
Texture2D textures[TEXTURES_N_DESCRIPTORS] : register(t0, space0);
SamplerState samplers[SAMPLERS_N_DESCRIPTORS] : register(s0);

struct VertexIn
{
    float3 position : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 textCoord : TEXCOORD;
};

struct VertexOut
{
    float4 position : SV_POSITION;
    float2 textCoord : TEXCOORD0;
    float3 shadingLocation: TEXCOORD1;
    float4 tangent : TEXCOORD2;
    float3 normal : TEXCOORD3;
};

// The vertex shader 
VertexOut VSMain(VertexIn vIn)
{
    VertexOut vOut;
    vOut.shadingLocation = mul(float4(vIn.position, 1.0f), meshConstants.modelMtx).xyz;
    vOut.normal = mul(float4(vIn.normal, 1.0f), meshConstants.modelMtx).xyz;
    vOut.position = mul(float4(vIn.position, 1.0f), mul(meshConstants.modelMtx, frameConstants.viewProjMtx));
    vOut.textCoord = vIn.textCoord;
    vOut.tangent = mul(float4(vIn.tangent.xyz, 1.0f), meshConstants.modelMtx);
    return vOut;
}

float3 fresnel(float3 F0, float3 F90, float VdotH);                         // Fresnel
float V_GGX(float NdotL, float NdotV, float ALPHA_roughness);               // Geometric occlusion
float D_GGX(float NdotH, float ALPHA_roughness);                            // Microfaced distribution
float3 diffuseLambert(float3 C_diff);                                       // Diffuse term
float diffuseDisney(float3 C_diff, float F90, float NdotL, float NdotV);    // Diffuse term according to Disney model

// The pixel shader
float4 PSMain(VertexOut vIn) : SV_Target // SV_Target means that the output should match the rendering target format
{
    float3 V = normalize(frameConstants.eyePosition.xyz - vIn.shadingLocation);      // V is the normalized vector from the shading location to the eye
    float3 L = normalize(frameConstants.lights[0].position.xyz - vIn.shadingLocation);    // L is the normalized vector from the shading location to the light
    float3 N = vIn.normal;                                 // N is the surface normal in the same space as the above values
    float3 H = normalize(L + V);                           // H is the half vector, where H = normalize(L + V)
    float VdotH = dot(V, H);
    float LdotH = dot(L, H);
    float NdotL = dot(N, L);
    float NdotV = dot(N, V);
    float NdotH = dot(N, H);

    float3 dielectricSpecular = { 0.04f, 0.04f, 0.04f };
    float3 black = { 0.0f, 0.0f, 0.0f };
    float3 ambientLight = { 0.2f, 0.2f, 0.5f };

    float4 baseColor = textures[materials[0].baseColorTA.textureId].Sample(samplers[0], vIn.textCoord);
    float4 roughMetallic = textures[materials[0].roughMetallicTA.textureId].Sample(samplers[0], vIn.textCoord);
    float4 emissive = textures[materials[0].emissiveTA.textureId].Sample(samplers[0], vIn.textCoord);
    float4 occlusion = textures[materials[0].occlusionTA.textureId].Sample(samplers[0], vIn.textCoord);

    float roughness = roughMetallic.g;
    float metallic = roughMetallic.b;
    float3 albedo = baseColor.xyz;

    float3 C_ambient = ambientLight * albedo;
    return float4(C_ambient, 1.0f);
}

float3 fresnel(float3 F0, float3 F90, float VdotH)
{
    return F0 + (F90 - F0) * pow(clamp(1.0f - VdotH, 0.0f, 1.0f), 5.0f);
}