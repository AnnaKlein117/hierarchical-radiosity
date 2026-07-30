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
#include "/RT_bvh.glsl" //NEU
#include "/HR_utils.glsl"
#include "/HR_visibility.glsl"
#include "/HR_Formfactor.glsl"

#define M_PI 3.1415926535897932384626433832795

#define FFGAMMA  0.000001
float  viseps = 0.01;
float feps = 0.003;
float aeps = 0.0001;

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

bool subdiv(int l, int who, float aeps) {
	if (imageLoad(areaTex[linkedList[l].eLevel], ivec3(linkedList[l].eu, linkedList[l].ev, linkedList[l].eIdx)).r < aeps) {
		return false;
	}
	else {
		float tmp;
		int next = linkedList[l].nextIdx;

		float ffes;
		float vis;
		int pointCountE;
		int pointCountS;


		bool noOR = false;
		// subdivide sender
		if (who == 1) {
			float size = pow(2, (mipMapLevels - linkedList[l].sLevel - 1));
			if (size - linkedList[l].sv - 1 == linkedList[l].su) {
				noOR = true;
			}

			//dont subdivide light
			if (linkedList[l].sLevel == -1) {
				return false;
			}
			linkedList[l].su = linkedList[l].su * 2;
			linkedList[l].sv = linkedList[l].sv * 2;
			linkedList[l].sLevel -= 1;
			linkedList[l].nextIdx = linkedListCounter + 1;

			//points for ffs
			if (linkedList[l].sLevel < mipMapLevels - 1 && linkedList[l].eLevel <mipMapLevels - 1) {
				pointCountS = getPatchPoints(sPoints, triangles[objects[linkedList[l].sIdx].geoIndex], linkedList[l].sLevel, linkedList[l].su, linkedList[l].sv);
				pointCountE = getPatchPoints(ePoints, triangles[objects[linkedList[l].eIdx].geoIndex], linkedList[l].eLevel, linkedList[l].eu, linkedList[l].ev);
				linkedList[l].fes = calculateFdAeAs(pointCountE, pointCountS);
				linkedList[l].vis = calculateVisibility(pointCountS, linkedList[l].sIdx, pointCountE, linkedList[l].eIdx);
			}
			// patch - triangle
			else if (linkedList[l].sLevel - 1 < mipMapLevels - 1 && linkedList[l].eLevel == mipMapLevels - 1) {
				pointCountS = getPatchPoints(sPoints, triangles[objects[linkedList[l].sIdx].geoIndex], linkedList[l].sLevel, linkedList[l].su, linkedList[l].sv);
				pointCountE = getTrianglePoints(ePoints, linkedList[l].eIdx);
				linkedList[l].fes = calculateFdAeAs(pointCountE, pointCountS);
				linkedList[l].vis = calculateVisibility(pointCountS, linkedList[l].sIdx, pointCountE, linkedList[l].eIdx);
			}

			pointCountS = getPatchPoints(sPoints, triangles[objects[linkedList[l].sIdx].geoIndex], linkedList[l].sLevel, linkedList[l].su + 1, linkedList[l].sv);
			ffes = calculateFdAeAs(pointCountE, pointCountS);
			vis = calculateVisibility(pointCountS, linkedList[l].sIdx, pointCountE, linkedList[l].eIdx);
			linkedList[linkedListCounter + 1] = link(linkedList[l].sIdx, linkedList[l].su + 1, linkedList[l].sv, linkedList[l].sLevel,
				linkedList[l].eIdx, linkedList[l].eu, linkedList[l].ev, linkedList[l].eLevel, ffes, vis, linkedListCounter + 2, l);
			linkedListCounter++;

			if (!noOR) {
				pointCountS = getPatchPoints(sPoints, triangles[objects[linkedList[l].sIdx].geoIndex], linkedList[l].sLevel, linkedList[l].su + 1, linkedList[l].sv + 1);
				ffes = calculateFdAeAs(pointCountE, pointCountS);
				vis = calculateVisibility(pointCountS, linkedList[l].sIdx, pointCountE, linkedList[l].eIdx);
				linkedList[linkedListCounter + 1] = link(linkedList[l].sIdx, linkedList[l].su + 1, linkedList[l].sv + 1, linkedList[l].sLevel,
					linkedList[l].eIdx, linkedList[l].eu, linkedList[l].ev, linkedList[l].eLevel, ffes, vis, linkedListCounter + 2, linkedListCounter);
				if (linkedListCounter >= 0) {
					linkedList[linkedListCounter].nextIdx = linkedListCounter + 1;
				}
				linkedListCounter++;
			}
			pointCountS = getPatchPoints(sPoints, triangles[objects[linkedList[l].sIdx].geoIndex], linkedList[l].sLevel, linkedList[l].su, linkedList[l].sv + 1);
			ffes = calculateFdAeAs(pointCountE, pointCountS);
			vis = calculateVisibility(pointCountS, linkedList[l].sIdx, pointCountE, linkedList[l].eIdx);
			linkedList[linkedListCounter + 1] = link(linkedList[l].sIdx, linkedList[l].su, linkedList[l].sv + 1, linkedList[l].sLevel,
				linkedList[l].eIdx, linkedList[l].eu, linkedList[l].ev, linkedList[l].eLevel, ffes, vis, next, linkedListCounter);
			if (linkedListCounter >= 0) {
				linkedList[next].lastIdx = linkedListCounter + 1;
			}
			linkedListCounter++;

			if (lastLight == l){
				lastLight = linkedListCounter;
			}
			tmp = getArea(linkedList[l].sIdx, linkedList[l].su, linkedList[l].sv, linkedList[l].sLevel - 1);
			tmp = getArea(linkedList[l].sIdx, linkedList[l].su + 1, linkedList[l].sv, linkedList[l].sLevel - 1);
			tmp = getArea(linkedList[l].sIdx, linkedList[l].su, linkedList[l].sv + 1, linkedList[l].sLevel - 1);
			tmp = getArea(linkedList[l].sIdx, linkedList[l].su + 1, linkedList[l].sv + 1, linkedList[l].sLevel - 1);
		}
		else {
			int size = (int)pow(2, (mipMapLevels - linkedList[l].eLevel - 1));
			if (size - linkedList[l].ev - 1 == linkedList[l].eu) {
				noOR = true;
			}

			linkedList[l].eu = linkedList[l].eu * 2;
			linkedList[l].ev = linkedList[l].ev * 2;
			linkedList[l].eLevel -= 1;
			linkedList[l].nextIdx = linkedListCounter + 1;

			//light
			if (linkedList[l].sLevel == -1) {
				pointCountE = getPatchPoints(ePoints, triangles[objects[linkedList[l].eIdx].geoIndex],
				linkedList[l].eLevel, linkedList[l].eu, linkedList[l].ev);

				float ffLight = calculateFdAsAe(light[linkedList[l].sIdx], pointCountE);
				float areaL = light[linkedList[l].sIdx].sizeX * light[linkedList[l].sIdx].sizeX;

				linkedList[l].fes = invertFF(ffLight, getArea(linkedList[l].eIdx, linkedList[l].eu, linkedList[l].ev, linkedList[l].eLevel), areaL);
				linkedList[l].vis = calculateVisibility(light[linkedList[l].sIdx], pointCountE, linkedList[l].eIdx);

				pointCountE = getPatchPoints(ePoints, triangles[objects[linkedList[l].eIdx].geoIndex], linkedList[l].eLevel, linkedList[l].eu + 1, linkedList[l].ev);
				ffLight = calculateFdAsAe(light[linkedList[l].sIdx], pointCountE);
				ffes = invertFF(ffLight, getArea(linkedList[l].eIdx, linkedList[l].eu + 1, linkedList[l].ev, linkedList[l].eLevel), areaL);
				vis = calculateVisibility(light[linkedList[l].sIdx], pointCountE, linkedList[l].eIdx);

				linkedList[linkedListCounter + 1] = link(linkedList[l].sIdx, linkedList[l].su, linkedList[l].sv, linkedList[l].sLevel,
					linkedList[l].eIdx, linkedList[l].eu + 1, linkedList[l].ev, linkedList[l].eLevel, ffes, vis,
					linkedListCounter + 2, l);
				linkedListCounter++;

				if (!noOR) {
					pointCountE = getPatchPoints(ePoints, triangles[objects[linkedList[l].eIdx].geoIndex], linkedList[l].eLevel, linkedList[l].eu + 1, linkedList[l].ev + 1);
					ffLight = calculateFdAsAe(light[linkedList[l].sIdx], pointCountE);
					ffes = invertFF(ffLight, getArea(linkedList[l].eIdx, linkedList[l].eu + 1, linkedList[l].ev + 1, linkedList[l].eLevel), areaL);
					vis = calculateVisibility(light[linkedList[l].sIdx], pointCountE, linkedList[l].eIdx);
					linkedList[linkedListCounter + 1] = link(linkedList[l].sIdx, linkedList[l].su, linkedList[l].sv, linkedList[l].sLevel,
						linkedList[l].eIdx, linkedList[l].eu + 1, linkedList[l].ev + 1, linkedList[l].eLevel, ffes, vis, linkedListCounter + 2, linkedListCounter);
					if (linkedListCounter >= 0) {
						linkedList[linkedListCounter].nextIdx = linkedListCounter + 1;
					}
					linkedListCounter++;
				}

				pointCountE = getPatchPoints(ePoints, triangles[objects[linkedList[l].eIdx].geoIndex], linkedList[l].eLevel, linkedList[l].eu, linkedList[l].ev + 1);
				ffLight = calculateFdAsAe(light[linkedList[l].sIdx], pointCountE);
				ffes = invertFF(ffLight, getArea(linkedList[l].eIdx, linkedList[l].eu, linkedList[l].ev + 1, linkedList[l].eLevel), areaL);
				vis = calculateVisibility(light[linkedList[l].sIdx], pointCountE, linkedList[l].eIdx);
				linkedList[linkedListCounter + 1] = link(linkedList[l].sIdx, linkedList[l].su, linkedList[l].sv, linkedList[l].sLevel,
					linkedList[l].eIdx, linkedList[l].eu, linkedList[l].ev + 1, linkedList[l].eLevel, ffes, vis, next, linkedListCounter);

				if (linkedListCounter >= 0) {
					linkedList[next].lastIdx = linkedListCounter + 1;
				}

				linkedListCounter++;
				if (lastLight == l ) {
					lastLight = linkedListCounter;
				}
				
				tmp = getArea(linkedList[l].eIdx, linkedList[l].eu, linkedList[l].ev, linkedList[l].eLevel - 1);
				tmp = getArea(linkedList[l].eIdx, linkedList[l].eu + 1, linkedList[l].ev, linkedList[l].eLevel - 1);
				tmp = getArea(linkedList[l].eIdx, linkedList[l].eu, linkedList[l].ev + 1, linkedList[l].eLevel - 1);
				tmp = getArea(linkedList[l].eIdx, linkedList[l].eu + 1, linkedList[l].ev + 1, linkedList[l].eLevel - 1);
			}
			//no light
			else {
				if (linkedList[l].sLevel < mipMapLevels - 1 && linkedList[l].eLevel < mipMapLevels - 1) {
					pointCountE = getPatchPoints(ePoints, triangles[objects[linkedList[l].eIdx].geoIndex], linkedList[l].eLevel, linkedList[l].eu, linkedList[l].ev);
					pointCountS = getPatchPoints(sPoints, triangles[objects[linkedList[l].sIdx].geoIndex], linkedList[l].sLevel, linkedList[l].su, linkedList[l].sv);

					linkedList[l].fes = calculateFdAeAs(pointCountE, pointCountS);
					linkedList[l].vis = calculateVisibility(pointCountS, linkedList[l].sIdx, pointCountE, linkedList[l].eIdx);
				}
				else if (linkedList[l].sLevel == mipMapLevels - 1 && linkedList[l].eLevel < mipMapLevels - 1) {
					pointCountS = getTrianglePoints(sPoints, linkedList[l].sIdx);
					pointCountE = getPatchPoints(ePoints, triangles[objects[linkedList[l].eIdx].geoIndex], linkedList[l].eLevel, linkedList[l].eu, linkedList[l].ev);

					linkedList[l].fes = calculateFdAsAe(pointCountE, pointCountS);
					linkedList[l].vis = calculateVisibility(pointCountS, linkedList[l].sIdx, pointCountE, linkedList[l].eIdx);
				}

				pointCountE = getPatchPoints(ePoints, triangles[objects[linkedList[l].eIdx].geoIndex], linkedList[l].eLevel, linkedList[l].eu + 1, linkedList[l].ev);
				ffes = calculateFdAeAs(pointCountE, pointCountS);
				vis = calculateVisibility(pointCountS, linkedList[l].sIdx, pointCountE, linkedList[l].eIdx);
				linkedList[linkedListCounter + 1] = link(linkedList[l].sIdx, linkedList[l].su, linkedList[l].sv, linkedList[l].sLevel, linkedList[l].eIdx, linkedList[l].eu + 1, linkedList[l].ev, linkedList[l].eLevel, ffes, linkedList[l].vis, linkedListCounter + 2, l);
				linkedListCounter++;

				if (!noOR) {
					pointCountE = getPatchPoints(ePoints, triangles[objects[linkedList[l].eIdx].geoIndex], linkedList[l].eLevel, linkedList[l].eu + 1, linkedList[l].ev + 1);
					ffes = calculateFdAeAs(pointCountE, pointCountS);
					vis = calculateVisibility(pointCountS, linkedList[l].sIdx, pointCountE, linkedList[l].eIdx);
					linkedList[linkedListCounter + 1] = link(linkedList[l].sIdx, linkedList[l].su, linkedList[l].sv, linkedList[l].sLevel, linkedList[l].eIdx, linkedList[l].eu + 1, linkedList[l].ev + 1, linkedList[l].eLevel, ffes, linkedList[l].vis, linkedListCounter + 2, linkedListCounter);
					if (linkedListCounter >= 0) {
						linkedList[linkedListCounter].nextIdx = linkedListCounter + 1;
					}
					linkedListCounter++;
				}

				pointCountE = getPatchPoints(ePoints, triangles[objects[linkedList[l].eIdx].geoIndex], linkedList[l].eLevel, linkedList[l].eu, linkedList[l].ev + 1);
				ffes = calculateFdAeAs(pointCountE, pointCountS);
				vis = calculateVisibility(pointCountS, linkedList[l].sIdx, pointCountE, linkedList[l].eIdx);
				linkedList[linkedListCounter + 1] = link(linkedList[l].sIdx, linkedList[l].su, linkedList[l].sv, linkedList[l].sLevel, linkedList[l].eIdx, linkedList[l].eu, linkedList[l].ev + 1, linkedList[l].eLevel, ffes, linkedList[l].vis, next, linkedListCounter);
				if (linkedListCounter >= 0) {
					linkedList[next].lastIdx = linkedListCounter + 1;
				}
				linkedListCounter++;
			}
			float tmp = getArea(linkedList[l].eIdx, linkedList[l].eu, linkedList[l].ev, linkedList[l].eLevel - 1);
			tmp = getArea(linkedList[l].eIdx, linkedList[l].eu + 1, linkedList[l].ev, linkedList[l].eLevel - 1);
			tmp = getArea(linkedList[l].eIdx, linkedList[l].eu, linkedList[l].ev + 1, linkedList[l].eLevel - 1);
			tmp = getArea(linkedList[l].eIdx, linkedList[l].eu + 1, linkedList[l].ev + 1, linkedList[l].eLevel - 1);
		}
		return true;
	}
}

void refine(int se, float Feps, float Aeps) {

	if (linkedListCounter < listLength) {
		float Fes = linkedList[se].fes;
		//make get area guessArea and get a better one?
		float sarea;
		if (linkedList[se].sLevel == -1) {
			sarea = light[linkedList[se].sIdx].sizeX * light[linkedList[se].sIdx].sizeX;
		}
		else {
			sarea = getArea(linkedList[se].sIdx, linkedList[se].su, linkedList[se].sv, linkedList[se].sLevel);
		}
		float earea = getArea(linkedList[se].eIdx, linkedList[se].eu, linkedList[se].ev, linkedList[se].eLevel);
		float Fse = invertFF(linkedList[se].fes, sarea, earea);

		if (Fes > Feps && Fse > Feps) {

			if (Fes > Fse && earea > Aeps && (linkedList[se].sLevel > 0)) {
				//ffs[0] = 200;
				//subdivide  sender
				subdiv(se, 1, Aeps);
			}
			else if (sarea > Aeps && linkedList[se].eLevel > 0) {
				//ffs[0] = 100;
				subdiv(se, 2, Aeps);
			}
		}
	}
}

void main() {
	int refCounter = linkedListCounter;
		for (int i = 0; i <= refCounter; i++) {
			refine(i, feps, aeps);
		}
		gatherLights = true;
}