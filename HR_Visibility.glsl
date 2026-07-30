//tringle - triangle
float calculateVisibility(int objIdS, int objId) {

	float vis = 0.0;
	float raylength;
	Triangle s = triangles[objects[objIdS].geoIndex];
	Ray ray;
	
	vec3 r[3];
	r[0] = triangles[objects[objId].geoIndex].A;
	r[1] = triangles[objects[objId].geoIndex].A + triangles[objects[objId].geoIndex].u;
	r[2] = triangles[objects[objId].geoIndex].A + triangles[objects[objId].geoIndex].v;

	for (int i = 0; i < 3; i++) {
		ray.origin = (s.A + s.A + s.u + s.A + s.v) / 3;
		ray.dir = normalize(r[i] - ray.origin);
		ray.origin = ray.origin + 0.01*ray.dir;
		raylength = length(r[i] - ray.origin) - viseps;
		if (!BVH_isIntersection(0, triangleIds.length(), raylength, ray)) {
			vis += 0.25;
		}
	}

	vec3 eOrigin = (3 * triangles[objects[objId].geoIndex].A + triangles[objects[objId].geoIndex].u + triangles[objects[objId].geoIndex].v) / 3;
	ray.dir = normalize(eOrigin - ray.origin);
	raylength = length(eOrigin - ray.origin) - viseps;

	if (!BVH_isIntersection(0, triangleIds.length(), raylength, ray)) {
		vis += 0.25;
	}
	return vis;
}

//light - triangle
float calculateVisibility(Light s, int objId) {

	float vis = 0.0;
	float raylength;
	Ray ray;
	ray.origin = s.pos.xyz;
	vec3 r[3];
	r[0] = triangles[objects[objId].geoIndex].A;
	r[1] = triangles[objects[objId].geoIndex].A + triangles[objects[objId].geoIndex].u;
	r[2] = triangles[objects[objId].geoIndex].A + triangles[objects[objId].geoIndex].v;

	for (int i = 0; i < 3; i++) {
		ray.dir = normalize(r[i] - ray.origin);
		raylength = length(r[i] - ray.origin) - viseps;
		if (!BVH_isIntersection(0, triangleIds.length(), raylength, ray)) {
			vis += 0.25;
		}
	}
	vec3 eOrigin = (r[0] + r[1] + r[2]) / 3;
	raylength = length(eOrigin - ray.origin) - viseps;
	ray.dir = normalize(eOrigin - ray.origin);

	if (!BVH_isIntersection(0, triangleIds.length(), raylength, ray)) {
		vis += 0.25;
	}
	return vis;
}

//patch - patch
float calculateVisibility(int countS, int s, int countE, int e) {
	
	float vis = 0.0;
	Ray ray;
	vec3 centerS = { 0,0,0 };
	for (int i = 0; i < countS; i++) {
		centerS += sPoints[i];
	}
	centerS /= countS;
	
	ray.origin = centerS;
	float raylength;
	for (int i = 0; i < countE; i++) {
		ray.origin = centerS;
		ray.dir = normalize(ePoints[i] - ray.origin);
		ray.origin = ray.origin + 0.01*ray.dir;
		raylength = length(ePoints[i] - ray.origin) - viseps;
		if (! BVH_isIntersection(0, triangleIds.length(), raylength, ray)) {
			vis += (float)(1.0 / countE);
		} 	
	}
	return vis;
}

// light - patch
float calculateVisibility(Light s, int countE, int eId) {
	Ray ray;
	ray.origin = s.pos.xyz;

	vec3 centerC = { 0,0,0 };
	for (int i = 0; i < countE; i++) {
		centerC += ePoints[0];
	}
	centerC /= countE;
	float raylength;
	float vis = 0.0f;

	for (int i = 0; i < countE; i++) {
		ray.dir = normalize(ePoints[i] - ray.origin);
		raylength = length(ePoints[i] - ray.origin) - viseps;
		if (! BVH_isIntersection(0, triangleIds.length(), raylength, ray)) {
			vis += (float)(1.0 / countE);
		}		
	}
	return vis;
}