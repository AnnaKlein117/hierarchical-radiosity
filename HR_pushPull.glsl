void pushPull(int idx) {

	vec4 clear = vec4(0, 0, 0, 1);
	if (unshotRadSource == 1) {
		imageStore(unshotRad2[mipMapLevels - 1], ivec3(0, 0, idx), clear);
	}
	else {
		imageStore(unshotRad[mipMapLevels - 1], ivec3(0, 0, idx), clear);
	}
	for (int m = mipMapLevels - 1; m > 0; m--) {
		int texSize = (int)pow(2, (mipMapLevels - 1 - m));
		//loop textures
		for (int u = 0; u < texSize; u++) {
			for (int v = 0; v < texSize; v++) {

				vec3 b_downUnshot;
				//current unshot rad
				if (unshotRadSource == 1) {
					b_downUnshot = imageLoad(unshotRad[m], ivec3(u, v, idx)).rgb;
				}
				else {
					b_downUnshot = imageLoad(unshotRad2[m], ivec3(u, v, idx)).rgb;
				}

				//loop over children add B parent
				for (int i = 0; i < 2; i++) {
					for (int j = 0; j < 2; j++) {//vec4 tmp = imageLoad(treeTex[m - 1], ivec3(u * 2 + i, v * 2 + j, idx));
						vec4 tmpA = imageLoad(areaTex[m - 1], ivec3(u * 2 + i, v * 2 + j, idx));
						if (tmpA.r == 0.0) {
							tmpA.r = getArea(idx, u * 2 + i, v * 2 + j, m - 1);
						}

						vec4 tmp_unshotRad;
						if (unshotRadSource == 1) {
							tmp_unshotRad =imageLoad(unshotRad[m - 1], ivec3(u * 2 + i, v * 2 + j, idx));
							tmp_unshotRad.rgb += b_downUnshot;
							imageStore(unshotRad[m - 1], ivec3(u * 2 + i, v * 2 + j, idx), tmp_unshotRad);
							imageStore(unshotRad2[m-1], ivec3(u * 2 + i, v * 2 + j, idx), clear);
						}
						else {
							tmp_unshotRad =imageLoad(unshotRad2[m - 1], ivec3(u * 2 + i, v * 2 + j, idx));
							tmp_unshotRad.rgb += b_downUnshot;
							imageStore(unshotRad2[m - 1], ivec3(u * 2 + i, v * 2 + j, idx), tmp_unshotRad);
							imageStore(unshotRad[m-1], ivec3(u * 2 + i, v * 2 + j, idx), clear);
						}

					}
				}
			}
		}
	}
	// copy radiosity to map
	int texSize = (int)pow(2, (mipMapLevels - 1));
	vec4 tmpGather;
	vec4 radTexel;

	for (int u = 0; u < texSize; u++) {
		for (int v = 0; v < texSize; v++) {
			radTexel = imageLoad(treeTex[0], ivec3(u, v, idx));
			if (unshotRadSource == 1) {
				tmpGather = imageLoad(unshotRad[0], ivec3(u, v, idx));
			}
			else {
				tmpGather = imageLoad(unshotRad2[0], ivec3(u, v, idx));
			}
			radTexel.rgb += tmpGather.rgb;
			imageStore(treeTex[0], ivec3(u, v, idx), radTexel);
		}
	}

	// pull
	for (int n = 1; n <= mipMapLevels-1; n++) {
		int texSize = (int)pow(2, (mipMapLevels - 1 - n));

		for (int u = 0; u < texSize; u++) {
			for (int v = 0; v < texSize; v++) {
				vec3 b_up = vec3(0, 0, 0);
				vec3 b_upUnshotRad = vec3(0, 0, 0);
				vec4 texel;
				vec4 area = imageLoad(areaTex[n], ivec3(u, v, idx));
				if (area.r == 0.0) {
					area.r = getArea(idx, u, v, n);
				}

				if (texSize - u - 1 == v){
					int stop = 2;
					for (int i = 0; i < 2; i++) {
						for (int j = 0; j < stop; j++) {
							vec4 a_tmp = imageLoad(areaTex[n - 1], ivec3(u * 2 + i, v * 2 + j, idx));
							vec4 b_tmpUnshotRad;
							if (a_tmp.r == 0.0) {
								a_tmp.r = getArea(idx, u * 2 + i, v * 2 + j, n - 1);
							}
							//current unshot rad
							if (unshotRadSource == 1) {
								b_tmpUnshotRad = imageLoad(unshotRad[n - 1], ivec3(u * 2 + i, v * 2 + j, idx));
								b_upUnshotRad += (b_tmpUnshotRad.rgb * a_tmp.r / area.r);
							}
							else {
								b_tmpUnshotRad = imageLoad(unshotRad2[n - 1], ivec3(u * 2 + i, v * 2 + j, idx));
								b_upUnshotRad += (b_tmpUnshotRad.rgb * a_tmp.r / area.r);
							}
						}
						stop = 1;
					}
				}
				else {	
					for (int i = 0; i < 2; i++) {
						for (int j = 0; j < 2; j++) {
							//vec4 b_tmp = imageLoad(treeTex[n - 1], ivec3(u * 2 + i, v * 2 + j, idx));
							vec4 a_tmp = imageLoad(areaTex[n - 1], ivec3(u * 2 + i, v * 2 + j, idx));
							if (a_tmp.r == 0.0) {
								a_tmp.r = getArea(idx, u * 2 + i, v * 2 + j, n - 1);
							}
							//b_up += ((b_tmp.rgb * a_tmp.r) / area.r);

							vec4 b_tmpUnshotRad;
							//current unshot rad
							if (unshotRadSource == 1) {
								b_tmpUnshotRad = imageLoad(unshotRad[n - 1], ivec3(u * 2 + i, v * 2 + j, idx));
								b_upUnshotRad += (b_tmpUnshotRad.rgb * a_tmp.r / area.r);
							}
							else {
								b_tmpUnshotRad = imageLoad(unshotRad2[n - 1], ivec3(u * 2 + i, v * 2 + j, idx));
								b_upUnshotRad += (b_tmpUnshotRad.rgb * a_tmp.r / area.r);
							}
						}
					}
				}
				texel.rgb = b_up; 
				if (unshotRadSource == 1) {
					texel.rgb = b_upUnshotRad;
					imageStore(unshotRad[n], ivec3(u, v, idx), texel);
				}
				else {
					texel.rgb = b_upUnshotRad;
					imageStore(unshotRad2[n], ivec3(u, v, idx), texel);
				}
			}
		}
	}
}