#version 450 core
#extension GL_ARB_bindless_texture : require
#extension GL_NV_gpu_shader5 : require // for uint64_t
#extension GL_ARB_shading_language_include : require

#include "/defines"; //automatically generated
#include "/RT_defs.glsl"
#include "/RT_debugging.glsl"
#include "/RT_intersection.glsl"
#include "/RT_light.glsl"
#include "/RT_material.glsl"
#include "/RT_objects.glsl"
#include "/RT_triangle.glsl"

#include "/RT_cone.glsl"
#include "/RT_sphere.glsl"
#include "/RT_bvh.glsl" 
#include "/HR_utils.glsl"
#include "/HR_pushPull.glsl"

#define M_PI 3.1415926535897932384626433832795

#define FFGAMMA  0.000001
float  viseps = 0.01;

struct link {
	int sIdx, su, sv, sLevel;
	int eIdx, eu, ev, eLevel;
	float fes;
	float vis;
	int nextIdx;
	int lastIdx;
};

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 28) buffer treeTextures {
	layout(rgba16f) image2DArray treeTex[];
};

layout(std430, binding = 30) buffer unshotRadiosity {
	layout(rgba16f) image2DArray unshotRad[];
};
layout(std430, binding = 24) buffer unshotRadiosity2 {
	layout(rgba16f) image2DArray unshotRad2[];
};

layout(std430, binding = 29) buffer areaTextures {
	layout(r16f) image2DArray areaTex[];
};

layout(std430, binding = 27) buffer linkedlistssbo {
	link linkedList[];
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

layout(std430, binding = 25) buffer outputFF {
	float ffs[];
};

vec3 sPoints[4];
vec3 ePoints[4];

vec3 getRadiosity(vec3 b_e, vec3 b_s, vec3 rho_e, float f_es, float vis) {
	if (b_s.r >= 0 && b_s.g >= 0 && b_s.b >= 0) {
		b_e += rho_e * b_s * f_es * vis;
	}
	return b_e;
}

void gatherL() {
	link l;
	for (int i = 0; i <= linkedListCounter; i++) {
		if (linkedList[i].lastIdx == -1) {
			l = linkedList[i];
			break;
		}
	}
	int gatherCount = 0;

	while (l.nextIdx  != linkedList[lastLight].nextIdx) {

		vec4 be;
		vec4 bs;

		//if it's light ask for radiosity from there'
		bs = vec4(light[l.sIdx].photometricValue, light[l.sIdx].photometricValue, light[l.sIdx].photometricValue, 1);

		if (unshotRadSource == 1) {
			be = imageLoad(unshotRad[l.eLevel], ivec3(l.eu, l.ev, l.eIdx));
		}
		else {
			be = imageLoad(unshotRad2[l.eLevel], ivec3(l.eu, l.ev, l.eIdx));
		}
		vec3 rho = material[objects[l.eIdx].materialIndex].diffColor;
		be.rgb = getRadiosity(be.rgb, bs.rgb, rho, l.fes, l.vis);

		//set new unshot rad for e
		if (unshotRadSource == 1) {
			imageStore(unshotRad[l.eLevel], ivec3(l.eu, l.ev, l.eIdx), be);
		}
		else {
			imageStore(unshotRad2[l.eLevel], ivec3(l.eu, l.ev, l.eIdx), be);
		}

		l = linkedList[l.nextIdx];
		gatherCount++;
		memoryBarrier();
	}
}

void gather() {
	link l;

	int gatherCount=0;
	l = linkedList[linkedList[lastLight].nextIdx];
	while (gatherCount <= linkedListCounter) {

		vec4 be;
		vec4 bs;
		vec4 shootRad;
		if (unshotRadSource == 1) {
			bs = imageLoad(unshotRad2[l.sLevel], ivec3(l.su, l.sv, l.sIdx));
			be = imageLoad(unshotRad[l.eLevel], ivec3(l.eu, l.ev, l.eIdx));
		}
		else {
			bs = imageLoad(unshotRad[l.sLevel], ivec3(l.su, l.sv, l.sIdx));
			be = imageLoad(unshotRad2[l.eLevel], ivec3(l.eu, l.ev, l.eIdx));
		}

		vec3 rho = material[objects[l.eIdx].materialIndex].diffColor;

		be.rgb = getRadiosity(be.rgb, bs.rgb, rho, l.fes, l.vis);

		if (unshotRadSource == 1) {
			imageStore(unshotRad[l.eLevel], ivec3(l.eu, l.ev, l.eIdx), be);
		}
		else {
			imageStore(unshotRad2[l.eLevel], ivec3(l.eu, l.ev, l.eIdx), be);
		}
	
		l = linkedList[l.nextIdx];
		gatherCount++;
		memoryBarrier();
		ffs[2]++;
	}
}

void main() {

	ffs[0] = 0;
	if (gatherLights) {
		gatherL();
			for (int i = 0; i < objCount; i++) {
				pushPull(i);
			}
		gatherLights = false;
		unshotRadSource = 1 - unshotRadSource;
	}
	ffs[0] = linkedListCounter;

	gather();
	for (int i = 0; i < objCount; i++) {
		pushPull(i);
	} 
	unshotRadSource = 1 - unshotRadSource;
}