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
#include "/HR_visibility.glsl"
#include "/HR_Formfactor.glsl"

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

float initgetArea(int idx, int u, int v, int level) {
	if (imageLoad(areaTex[level], ivec3(u, v, idx)).r > 0.0) {

		return imageLoad(areaTex[level], ivec3(u, v, idx)).r;
	}
	else {

		int size = (int)pow(2, mipMapLevels - level - 1);
		int psize = (int)pow(2, mipMapLevels - level - 2);
		ivec2 pIdx = ivec2(floor(u / 2), floor(v / 2));

		float parea = imageLoad(areaTex[level + 1], ivec3(pIdx, idx)).r;
		vec4 texel = imageLoad(areaTex[level], ivec3(u, v, idx));
		if (psize - pIdx.x - 1 == pIdx.y) {
			if (size - u - 1 == v) {
				texel.r = parea * 0.25;
			}
			else {
				texel.r = parea * 0.5;
			}
		}
		else {
			texel.r = parea * 0.25;
		}
		imageStore(areaTex[level], ivec3(u, v, idx), texel);
		return texel.r;
	}
}

void initAreas() {
	float area;
	for (int i = 0; i < objects.length(); i++) {
		if (objects[i].type == 2) {
			vec4 texel = imageLoad(areaTex[mipMapLevels - 1], ivec3(0, 0, i));
			texel.r = triangles[objects[i].geoIndex].area;
			imageStore(areaTex[mipMapLevels - 1], ivec3(0, 0, i), texel);
		}
	}
	for (int o = 0; o < objCount; o++) {
		for (int n = 1; n < mipMapLevels; n++) {
			int texSize = (int)pow(2, (mipMapLevels - 1 - n));

			for (int u = 0; u < texSize; u++) {
				for (int v = 0; v < texSize; v++) {
					area = initgetArea(o, u, v, n);
				}
			}
		}
	}
}
void initialLinking() {
	// initiate lights to triangles
	float vis;

	for (int l = 0; l < light.length(); l++) {
		for (int o = 0; o < objCount; o++) {

			float ffseLight = calculateFFlight(triangles[objects[o].geoIndex], light[l]);
			float areaL = light[l].sizeX * light[l].sizeX;
			float ffLight = invertFF(ffseLight, triangles[objects[o].geoIndex].area, areaL);
			vis = calculateVisibility(light[l], o);
			linkedList[linkedListCounter + 1] = link(l, -1, -1, -1, o, 0, 0, mipMapLevels - 1, ffLight, vis, -1, linkedListCounter);
			if (linkedListCounter >= 0) {
				linkedList[linkedListCounter].nextIdx = linkedListCounter + 1;
			}
			linkedListCounter++;
		}
	}
	lastLight = linkedListCounter;

	//initiate first level of triangles
	for (int s = 0; s < objCount; s++) {
		for (int e = 0; e < s; e++) {
			if (objects[s].type == 2 && objects[e].type == 2) {

				//berechne ff für s, anderes reziprok (Fse ⋅As)/Ae =Fes
				float visS = calculateVisibility(s, e);
				float visE = calculateVisibility(e, s);
				float ffes = (float)calculateFdAsAe(triangles[objects[e].geoIndex], triangles[objects[s].geoIndex]);
				float ffse = invertFF(ffes, triangles[objects[s].geoIndex].area, triangles[objects[e].geoIndex].area);

				//initiate List of linked polys/triangles
				//sIdx, su, sv, sLevel; eIdx, eu, ev, eLevel;fes;vis;nextIdx;lastIdx;
				linkedList[linkedListCounter + 1] = link(s, 0, 0, mipMapLevels - 1, e, 0, 0, mipMapLevels - 1, ffes, visS, -1, linkedListCounter);
				if (linkedListCounter >= 0) {
					linkedList[linkedListCounter].nextIdx = linkedListCounter + 1;
				}
				linkedListCounter++;
				linkedList[linkedListCounter + 1] = link(e, 0, 0, mipMapLevels - 1, s, 0, 0, mipMapLevels - 1, ffse, visE, -1, linkedListCounter);
				if (linkedListCounter >= 0) {
					linkedList[linkedListCounter].nextIdx = linkedListCounter + 1;
				}
				linkedListCounter++;
			}
		}
	}
}

void main() {	
	initAreas();
	initialLinking();
	ffs[2] = 0;
	ffs[5] = 1;
	ffs[11] = 0;
}