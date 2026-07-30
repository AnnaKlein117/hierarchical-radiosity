//triangle - triangle
float calculateFdAsAe(Triangle s, Triangle e) {
	float ff = 0;
	float gamma;
	vec3 gamma_;
	vec3 r[3];
	vec3 sender = (s.A + s.A + s.u + s.A + s.v) / 3;
	r[0] = e.A - sender;
	r[1] = e.A + e.u - sender;
	r[2] = e.A + e.v - sender;
	for (int i = 0; i < 3; i++) {
		int index = (int)mod(i + 1, 3);
		vec3 ri1 = r[index];
		gamma = acos(dot(ri1, r[i]) / (length(ri1) * length(r[i])));
		gamma_ = (vec3)gamma *(cross(r[i], ri1)) / (length(cross(r[i], ri1)));

		ff += dot(gamma_, s.normal);
	}
	ff *= (-(1 / (2 * M_PI)));
	if (ff < (0.0 + FFGAMMA) || isnan(ff)) {
		ff = 0.0;
	}
	return ff;
}
float calculateFFlight(Triangle e, Light s) {
	float ffl = 0;
	float gammal;
	vec3 gammal_;
	vec3 senderl = s.pos.xyz;
	vec3 rl[3];
	rl[0] = e.A - senderl;
	rl[1] = (e.A + e.u) - senderl;
	rl[2] = (e.A + e.v) - senderl;

	for (int i = 0; i < 3; i++) {
		int index = (int)mod(i + 1, 3);
		vec3 ri1l = rl[index];
		gammal = acos(dot(ri1l, rl[i]) / (length(ri1l) * length(rl[i])));
		gammal_ = (vec3)gammal * (cross(rl[i], ri1l)) / (length(cross(rl[i], ri1l)));
		ffl = ffl + dot(gammal_, s.direction);
	}
	ffl *= (-(1 / (2 * M_PI)));
	if (ffl < 0.0 + FFGAMMA || isnan(ffl)) {
		ffl = 0.0;
	}
	return ffl;
}

// patch backwards
float calculateFdAeAs(int countE, int countS) {
	float ff = 0.0;
	float gamma;
	vec3 gamma_;
	vec3 sender = { 0,0,0 };
	for (int i = 0; i < countE; i++) {
		sender += (ePoints[i]);
	}
	vec3 r[4];
	sender = sender / countE;
	vec3 snormal = cross(ePoints[1] - ePoints[0], ePoints[2] - ePoints[0]);

	for (int j = 0; j < countS; j++) {
		r[j] = sPoints[j] - sender;
	}
	for (int k = 0; k < countS; k++) {
		int index = (int)mod(k + 1, countS);
		vec3 ri1 = r[index];
		gamma = acos(dot(ri1, r[k]) / (length(ri1) * length(r[k])));
		gamma_ = (vec3)gamma *(cross(r[k], ri1)) / (length(cross(r[k], ri1)));
		ff += dot(gamma_, snormal);
	}
	ff = ff *(-(1 / (2 * M_PI)));
	if (ff < 0.0 + FFGAMMA || isnan(ff)) {
		ff = 0.0;
	}
	return ff;
}

float calculateFdAsAe(int countS, int countE) {
	float ff = 0.0;
	float gamma;
	vec3 gamma_;
	vec3 sender = { 0,0,0 };
	for (int i = 0; i < countS; i++) {
		sender += (sPoints[i]);
	}
	vec3 r[4];
	sender = sender / countS;
	vec3 snormal = cross(sPoints[1] - sPoints[0], sPoints[2] - sPoints[0]);

	for (int j = 0; j < countE; j++) {
		r[j] = ePoints[j] - sender;
	}
	for (int k = 0; k < countE; k++) {
		int index = (int)mod(k + 1, countE);
		gamma = acos(dot(ri1, r[k]) / (length(ri1) * length(r[k])));
		gamma_ = (vec3)gamma *(cross(r[k], ri1)) / (length(cross(r[k], ri1)));
		ff += dot(gamma_, snormal);
	}
	ff = ff *(-(1 / (2 * M_PI)));
	if (ff < 0.0 + FFGAMMA || isnan(ff)) {
		ff = 0.0;
	}
	return ff;
}

// light - patch
float calculateFdAsAe(Light s, int countE) {
	float ff = 0;
	float gamma;
	vec3 gamma_;
	vec3 sender = s.pos.xyz;
	vec3 r[4];
	for (int j = 0; j < countE; j++) {
		r[j] = ePoints[j] - sender;
	}
	for (int k = 0; k < countE; k++) {
		int index = (int)mod(k + 1, countE);
		vec3 ri1 = r[index];
		gamma = acos(dot(ri1, r[k]) / (length(ri1) * length(r[k])));
		gamma_ = (vec3)gamma * (cross(r[k], ri1)) / (length(cross(r[k], ri1)));

		ff += dot(gamma_, s.direction);
	}
	ff = ff *(-(1 / (2 * M_PI)));
	if (ff < 0.0 + FFGAMMA || isnan(ff)) {
		ff = 0.0;
	}
	return ff;
}

float invertFF(float ffes, float areaS, float areaE) {
	float iff = ffes * areaE / areaS;
	if (iff < 0.0 + FFGAMMA || isnan(iff)) {
		iff = 0.0;
	}
	return iff;
}