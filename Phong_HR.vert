#version 430 core

layout (location = 0) in vec4 Position;
layout (location = 1) in vec3 Normal;
layout (location = 2) in vec2 Tcoord;
layout (location = 4) in int ObjIndex;

uniform mat4 modelMatrix;
uniform mat4 viewMatrix;
uniform mat4 projectionMatrix;

out vec3 passPosition;
out vec3 passNormal;
out vec2 passTcoord;
out flat int passObjIdx;

void main() {
    gl_Position = projectionMatrix * viewMatrix * modelMatrix * Position;

    passPosition = (viewMatrix * modelMatrix * Position).xyz;

	mat3 normalMatrix = mat3( transpose( inverse( viewMatrix * modelMatrix)));
    passNormal = normalize( normalMatrix * Normal);
	passTcoord = Tcoord;
	passObjIdx = ObjIndex;
}
