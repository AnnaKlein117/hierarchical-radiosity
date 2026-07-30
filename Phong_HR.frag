#version 450 core
#extension GL_ARB_bindless_texture:require
#extension GL_NV_gpu_shader5:require // for uint64_t

in vec3 passPosition;
in vec3 passNormal;
in vec2 passTcoord;
in flat int passObjIdx;

uniform mat4 viewMatrix;
uniform int matIndex;

struct Material
{
	vec3 diffColor;
    float kd;
	vec3 specColor;
	float ks;
	uint64_t colorTextureHandle; 
	uint64_t normalTextureHandle;
	float shininess;
	float kr;
	float kt;
	float ior;
};

layout( std430, binding = 0) restrict readonly buffer material_ssbo
{
	Material material[];
};

layout(std430, binding = 28) buffer treeTextures {
	layout(rgba16f) image2DArray treeTex[];
};

layout(std430, binding = 29) buffer areaTextures {
	layout(r16f) image2DArray areaTex[];
};

layout(std430, binding = 26) buffer hrdata {
	int objCount;
	int mipMapLevels; //root level
	int linkedListCounter;
	int listLength;
	int unshotRadSource;
	int lastLight;
	bool gatherLights;
};

uniform vec3 lightAmbient;
out vec4 fragmentColor;

void main() 
{	
	float xCoord = passTcoord.x * (pow(2,mipMapLevels-1));
	float yCoord = passTcoord.y * (pow(2,mipMapLevels-1));
	fragmentColor.rgb = (imageLoad(treeTex[0], ivec3(floor(xCoord), floor(yCoord), passObjIdx)).rgb)/80;
	fragmentColor.a = 1.0f;
}
