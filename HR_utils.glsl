void writeTexel(int level, ivec3 coord, vec4 color) {
	imageStore(treeTex[level], coord, color);

}

vec4 getTexel(int level, ivec3 coord) {

	return imageLoad(treeTex[level], coord);

}

// consider shearing when mapping triangles to rectangles
float getArea(int idx, int u, int v, int level) {
	if (imageLoad(areaTex[level], ivec3(u, v, idx)).r > 0.0) {
		return imageLoad(areaTex[level], ivec3(u, v, idx)).r;
	} else {
		int size = (int)pow(2, mipMapLevels - level - 1);
		int psize = (int)pow(2, mipMapLevels - level - 2);
		ivec2 pIdx = ivec2(floor(u / 2), floor(v / 2));

		float parea = imageLoad(areaTex[level + 1], ivec3(pIdx, idx)).r;
		vec4 texel = imageLoad(areaTex[level], ivec3(u, v, idx));
			if (size - u - 1 == v) {
				texel.r = parea * 0.25;
			} else {
				texel.r = parea * 0.5;
			}
		imageStore(areaTex[level], ivec3(u, v, idx), texel);
		return texel.r;
	}
}

float getArea(vec3 points[4], int size) {
	float area = length(cross(points[0] - points[1], points[2] - points[1]));
	if (size == 4) {
		area += length(cross(points[0] - points[3], points[2] - points[3]));
	}
	return area;
}


int getPatchPoints(out vec3 points[4], Triangle t, int level, int u, int v) {

	int size = (int)pow(2, mipMapLevels - level - 1);

	vec3 origin = t.A + t.u;
	vec3 vTri = t.v - t.u;
	vec3 uTri = -t.u;

	vec3 width = vTri / size;
	vec3 height = uTri / size;
	points[0] = origin + u*width + v*height;
	points[1] = points[0] + width;

	if (size - u - 1 == v) {
		points[2] = points[0] + height;
		return 3;
	}
	else {
		points[2] = points[1] + height;
		points[3] = points[0] + height;
		return 4;
	}
}

int getTrianglePoints(out vec3 points[4], int o) {
	points[0] = triangles[objects[o].geoIndex].A;
	points[1] = triangles[objects[o].geoIndex].A + triangles[objects[o].geoIndex].u;
	points[2] = triangles[objects[o].geoIndex].A + triangles[objects[o].geoIndex].v;
	return 3;
}
