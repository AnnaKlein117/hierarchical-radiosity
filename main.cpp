#define GLM_SWIZZLE

#include <CVK_Framework.h>
#include <CVK_RT.h>
#include "CVK_RT_GPU_Defs.h"
#include "CVK_RT_GPU_LineSpace.h"
#include "CVK_RT_GPU_Voxel.h"
#include "CVK_RT_GPU_BVH.h"
#include "CVK_RT_GPU_DataStructureManager.h"
#include "CVK_RT_GPU_Shader_RT_Pass0_GBuffer.h"
#include "CVK_RT_GPU_Shader_RT_Pass1.h"
#include "CVK_RT_GPU_Shader_RT_simple.h"
#include "CVK_PT_Shader_PathTracing.h"
#include "CVK_PT_GPU_Shader_Pass0_GBuffer.h"
#include "CVK_PT_GPU_Shader_Pass1_LS.h"
#include "CVK_ShaderPhongBuffered.h"
#include <omp.h>
#include "iostream"
#include <vector>

#define DEFAULT 0
#define TRIANGLE 1
#define TEAPOT 2
#define SPONZA 3
#define CORNELL 4

#define RAYTRACER 0
#define PATHTRACER 1

#define NLS 4 //for vis a LineSpace of 4 is assumed
#define NG 4 //for vis of global LineSpace only

#define DOUBLEWIDTH 1900
#define WIDTH 850
#define HEIGHT 850
#define H_WIDTH 1920
#define H_HEIGHT 1080
#define U_WIDTH 3840
#define U_HEIGHT 2160

#define HIER_RAD
#define WORK_GROUP_SIZE 1
#define NUMGROUPS 1
#define MIPMAPLEVELS  5 // treedepth
#define LINKEDLISTLENGTH  5000000



int width = WIDTH;
int height = HEIGHT;
int randTextureWidth = H_WIDTH; 
int randTextureHeight = H_HEIGHT;
int scene = CORNELL;
int whichTracer = RAYTRACER;



#define OPENGL 0
#define SHAFT_PLANES 10

CVK::Scene *triangleScene = 0, *teapotScene = 0, *sponzaScene = 0, *cornellScene = 0;
CVK::Node *teapot_node, *sponza_node, *tri_node;
CVK::Light *plight1, *plight2, *plight3;
CVK::Material *mat_specular, *mat_floor, *mat_cvlogo;
CVK::Material *mat;

CVK::ShaderPhongBuffered *phongBufferShader;
CVK_RT_GPU::Shader_RT_Simple *GPU_RT_VoxelShader = 0;
CVK_RT_GPU::Shader_RT_Simple *GPU_RT_OctreeShader = 0;
CVK_RT_GPU::Shader_RT_Simple *GPU_RT_LSCandShader = 0;
CVK_RT_GPU::Shader_RT_Simple *GPU_RT_LSSigShader = 0;
CVK_RT_GPU::Shader_RT_Simple *GPU_RT_LSPreIllumShader = 0;
CVK_RT_GPU::Shader_RT_Simple *GPU_RT_BVHShader = 0;
CVK_RT_GPU::Shader_RT_Pass0_GBuffer *GPU_RT_Pass0GBufferShader = 0;
CVK_RT_GPU::Shader_RT_Pass1 *GPU_RT_Pass1LSShader = 0, *GPU_RT_Pass1LSPreIllumShader = 0;
CVK_PT_GPU::ShaderPathTracing *GPU_PT_VoxelShader = 0, *GPU_PT_LSCandShader = 0, *GPU_PT_BVHShader = 0, *GPU_PT_LSPreIllumShader = 0;
CVK_PT_GPU::Shader_PT_Pass0_GBuffer *GPU_PT_Pass0GBufferShader = 0;
CVK_PT_GPU::Shader_PT_Pass1_LS *GPU_PT_Pass1LSShader = 0;
CVK::ShaderSimpleTexture *simpleTextureShader=0;
CVK::ShaderSet *CS_HierRad =0;
CVK::ShaderSet *CS_HRinitialLinking = 0;
CVK::ShaderSet *CS_HRrefine = 0;
CVK::ShaderSet *CS_HRpushPull = 0;
CVK::ShaderSet *CS_HRgather = 0;

glm::uvec3 actRes;
CVK::Perspective *perspective;
CVK::Ortho ortho(0, WIDTH, 0, HEIGHT, -2, 2), ortho2(-1.75, 1.75, -1.75, 1.75, -20, 20);

CVK::Camera *camera;
CVK::Trackball *cam_trackball;
CVK::Pilotview *cam_pilot;

CVK::FBO *fbo_gbuffer;

CVK_RT_GPU::Scene *cornell_RTscene;

int render_type = OPENGL;

bool WireFrame = false;
int drawmode = GL_FILL;
float alpha = -35, beta = -45, gamma = 0;
float spec = 0.f;
float variance = 0;
float epsilon1 = 0, epsilon2 = 0;

GLFWwindow *window;
double start_time, end_time;
FILE *file = stdout;

struct link {
	int sIdx, su, sv, slevel;
	int eIdx, eu, ev, elevel;
	float fes;
	float vis;
	int nextIdx;
	int lastIdx;
};

struct HRinformation {
	int objcnt;
	int mipmaplevel;
	int listCounter;
	int linkedListSize;
	int unshotRadSource;
	int lastLight;
	bool gatherLights;
};

struct TreeTexHandles {
	GLuint64 treeTexturesHandles[10];
	GLuint64 unshotRadHandles[10];
	GLuint64 areaTexHandles[10];
};


GLuint linksList, treeTextures, areaTextures, radTextures, radTextures2, outputFfSsbo, seSsbo, texHandlesSsbo, radTexHandleSSBO, radTexHandleSSBO2, areaHandlesSsbo; //
float clearColor[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
HRinformation *HrInfo = new HRinformation();
GLenum er;
bool refineTree = true;

void PrintInfo()
{
	printf("\n");
	printf("Scene \n");
	printf("  <shift> 1:	Triangle\n");
	printf("  <shift> 2:	Teapot\n");
	printf("  <shift> 3:	Sponza\n");
	printf("  <shift> 4:	Cornell\n");
	printf("Raytracing\n");
	printf("  1:	Voxel\n");
	printf("  2:	LineSpace Kandidatenliste\n");
	printf("  3:	LineSpace 2 pass (GBuffer)\n");
	printf("  4:	LineSpace PreIllum\n");
	printf("  5:	LineSpace LS CandList + PreIllum\n");
	printf("  6:	LineSpace Signature\n");
	printf("  7:	BVH\n");
	printf("  8:	Octree (will crash)\n");
	printf("Screen\n");
	printf("  f/F:	HD or UHD\n");
	printf("  ^^:	reset resolution\n");
	printf("Rendering \n");
	printf("  r/R:	RayTracing/PathTracing\n");
	printf("  o:	OpenGL rendering\n");
	printf("  w:	Wireframe j/n (OpenGL rendering only)\n");
	printf("Information\n");
	printf("  c:	print camera info\n");
	printf("  p:	print buffer info\n");
	printf("LineSpace Interaction (3D scene)\n");
	printf("  a/A:	in/decrease skips\n");
	printf("Sponza\n");
	printf("  k/K:	in/decrease specularity of floor\n");
	printf("  d/D:	in/decrease variance of spec\n");
}

void resizeCallback(GLFWwindow *window, int w, int h)
{
	width = w;
	height = h;
	camera->setWidthHeight(width, height);
	fbo_gbuffer->resize(width, height);
	glViewportIndexedf(0, 0, 0, width, height);
}

void init_shader()
{
	const char *includeshadernames[37] =
	{
		SHADERS_PATH "GPU_RT/include/RT_bvh.glsl",
		SHADERS_PATH "GPU_RT/include/RT_cone.glsl",
		SHADERS_PATH "GPU_RT/include/RT_defs.glsl",
		SHADERS_PATH "GPU_RT/include/RT_debugging.glsl",
		SHADERS_PATH "GPU_RT/include/RT_intersection.glsl",
		SHADERS_PATH "GPU_RT/include/RT_light.glsl",
		SHADERS_PATH "GPU_RT/include/RT_light_pmc.glsl",
		SHADERS_PATH "GPU_RT/include/RT_linespace.glsl",
		SHADERS_PATH "GPU_RT/include/RT_linespace_sig.glsl",
		SHADERS_PATH "GPU_RT/include/RT_linespacePreIllum.glsl",

		SHADERS_PATH "GPU_RT/include/RT_material.glsl",
		SHADERS_PATH "GPU_RT/include/RT_noDataStructure.glsl",
		SHADERS_PATH "GPU_RT/include/RT_objects.glsl",
		SHADERS_PATH "GPU_RT/include/RT_octree.glsl",
		SHADERS_PATH "GPU_RT/include/RT_shade_pur.glsl",
		SHADERS_PATH "GPU_RT/include/RT_shade_recursive.glsl",
		SHADERS_PATH "GPU_RT/include/RT_shade_recursive_pmc.glsl",
		SHADERS_PATH "GPU_RT/include/RT_sphere.glsl",
		SHADERS_PATH "GPU_RT/include/RT_trace_preIllum.glsl",
		SHADERS_PATH "GPU_RT/include/RT_trace_preIllum_pmc.glsl",

		SHADERS_PATH "GPU_RT/include/RT_trace_pur.glsl",
		SHADERS_PATH "GPU_RT/include/RT_trace_recursive.glsl",
		SHADERS_PATH "GPU_RT/include/RT_triangle.glsl",
		SHADERS_PATH "GPU_RT/include/RT_voxel_grid.glsl",

		SHADERS_PATH "PathTracer/PT_Random_LCGTaus.glsl",
		SHADERS_PATH "PathTracer/PT_light.glsl",
		SHADERS_PATH "PathTracer/PT_sampling_phong.glsl",
		SHADERS_PATH "PathTracer/PT_shade_phong.glsl",
		SHADERS_PATH "PathTracer/PT_trace.glsl",
		SHADERS_PATH "PathTracer/PT_trace_preIllum.glsl", 

		SHADERS_PATH "PhongBuffered/Light_pmc.glsl",
		SHADERS_PATH "HierarchicalRadiosity/HR_visibility.glsl",
		SHADERS_PATH "HierarchicalRadiosity/HR_Formfactor.glsl",
		SHADERS_PATH "HierarchicalRadiosity/HR_initialLinking.glsl",
		SHADERS_PATH "HierarchicalRadiosity/HR_pushPull.glsl",
		SHADERS_PATH "HierarchicalRadiosity/HR_refine.glsl",
		SHADERS_PATH "HierarchicalRadiosity/HR_utils.glsl"
	};

	CVK::ShaderSet::loadShaderIncludeSources(37, includeshadernames);

	//load, compile and link Shader

	const char *phongshadernames[2] = { SHADERS_PATH "HierarchicalRadiosity/Phong_HR.vert", SHADERS_PATH "HierarchicalRadiosity/Phong_HR.frag" };
	phongBufferShader = new CVK::ShaderPhongBuffered(VERTEX_SHADER_BIT | FRAGMENT_SHADER_BIT, phongshadernames);
	CVK::State::getInstance()->setShader(phongBufferShader);

	CVK::ShaderSet::setDefines("#define DS_LS_SIGNATURE\n");

	const char *shadernamesSimpleTexture[2] = { SHADERS_PATH "Screenfill/screenFill.vert", SHADERS_PATH "Screenfill/simpleTexture.frag" };
	simpleTextureShader = new CVK::ShaderSimpleTexture(VERTEX_SHADER_BIT | FRAGMENT_SHADER_BIT, shadernamesSimpleTexture);

}

void init_camera()
{
	perspective = new CVK::Perspective(glm::radians(60.f), (float)width / height, 0.5f, 50.f);

	cam_trackball = new CVK::Trackball(width, height);
	cam_trackball->setProjection(perspective);
	cam_trackball->setCenter(&glm::vec3(0.0f, 0.0f, 0.0f));
	cam_trackball->setRadius(5);
	cam_trackball->setStepSize(0.1);

	cam_pilot = new CVK::Pilotview(width, height, perspective);
	cam_pilot->setProjection(perspective);
	cam_pilot->setSpeedIncrease(0.01f);

	camera = cam_trackball;
	CVK::State::getInstance()->setCamera(camera);
}

void init_fbos()
{
	fbo_gbuffer = new CVK::FBO(WIDTH, HEIGHT, 6, true, false);
}

void init_scene(int sceneId)
{
	//Create scene Cornell Box
	glm::vec3 pos = glm::vec3(0);
	float scale = 1.f;

	cornellScene = new CVK::Scene();

	//Light
	CVK::Light *alight = new CVK::Light(glm::vec4(0, 0.975f, 0, 1), darkgrey, glm::normalize(glm::vec3(0, -1, 0)), 0.4f, 0.4f, 3400.0f);

	CVK::Material* mat_white = new CVK::Material(1.f, white, 0.f, white, 1.0f);
	CVK::Material* mat_red = new CVK::Material(1.f, red, 0.f, white, 1.0f);
	CVK::Material* mat_green = new CVK::Material(1.f, green, 0.f, white, 1.0f);
	CVK::Material* mat_reflect = new CVK::Material(0.05f, white, 0.f, white, 1.f);
	mat_reflect->setKr(0.9f);
	mat_reflect->setIor(0.f);

	CVK::Plane *floor = new CVK::Plane(glm::vec3(-1, -1, -1), glm::vec3(-1, -1, 1), glm::vec3(1, -1, 1), glm::vec3(1, -1, -1));
	CVK::Node *floor_node = new CVK::Node("Floor");
	floor_node->setMaterial(mat_white);
	floor_node->setGeometry(floor);

	CVK::Plane *ceil = new CVK::Plane(glm::vec3(-1, 1, -1), glm::vec3(1, 1, -1), glm::vec3(1, 1, 1), glm::vec3(-1, 1, 1));
	CVK::Node *ceil_node = new CVK::Node("Ceil");
	ceil_node->setMaterial(mat_white);
	ceil_node->setGeometry(ceil);
	floor_node->addChild(ceil_node);
	
	CVK::Plane *left = new CVK::Plane(glm::vec3(-1, -1, -1), glm::vec3(-1, 1, -1), glm::vec3(-1, 1, 1), glm::vec3(-1, -1, 1));
	CVK::Node *left_node = new CVK::Node("LeftWall");
	left_node->setMaterial(mat_red);
	left_node->setGeometry(left);
	floor_node->addChild(left_node);
	
	CVK::Plane *right = new CVK::Plane(glm::vec3(1, -1, -1), glm::vec3(1, -1, 1), glm::vec3(1, 1, 1), glm::vec3(1, 1, -1));
	CVK::Node *right_node = new CVK::Node("RightWall");
	right_node->setMaterial(mat_green);
	right_node->setGeometry(right);
	floor_node->addChild(right_node);

	CVK::Plane *back = new CVK::Plane(glm::vec3(-1, -1, -1), glm::vec3(1, -1, -1), glm::vec3(1, 1, -1), glm::vec3(-1, 1, -1));
	CVK::Node *back_node = new CVK::Node("BackWall");
	back_node->setMaterial(mat_white);
	back_node->setGeometry(back);
	floor_node->addChild(back_node); 
	
	CVK::Cube *obj1 = new CVK::Cube();
	CVK::Node *obj1_node = new CVK::Node("Object1");
	obj1_node->setMaterial(mat_reflect);
	obj1_node->setGeometry(obj1);
	obj1_node->setModelMatrix(glm::translate(
	glm::rotate(
	glm::scale(glm::mat4(1.0f), glm::vec3(0.3f, 0.6f, 0.3f)),
	glm::pi<float>() / 8.0f, glm::vec3(0.f, 1.f, 0.f)),
	glm::vec3(-1.f, -0.66f, -1.f)));
	floor_node->addChild(obj1_node);

	CVK::Geometry *obj2 = new CVK::Cube();
	CVK::Node *obj2_node = new CVK::Node("Object2");
	obj2_node->setMaterial(mat_white);
	obj2_node->setGeometry(obj2);
	obj2_node->setModelMatrix(glm::translate(
	glm::rotate(
	glm::scale(glm::mat4(1.0f), glm::vec3(0.3f)),
	-glm::pi<float>() / 8.0f, glm::vec3(0.f, 1.f, 0.f)),
	glm::vec3(1.5f, -2.33f, 1.f)));
	floor_node->addChild(obj2_node); 

	//Camera
	CVK::Trackball *sceneCam_trackball = new CVK::Trackball(width, height);
	CVK::Perspective *sceneCam_perspective = new CVK::Perspective(glm::radians(60.f), (float)width / height, 0.05f, 10.f);

	sceneCam_trackball->setRadius(2.7f);
	sceneCam_trackball->setStepSize(0.1);
	sceneCam_trackball->setProjection(sceneCam_perspective);

	//Scene for buffer management
	float lightScaleForRendering = 5.f;
	cornellScene->setCamera(sceneCam_trackball);
	cornellScene->appendLight(alight);
	cornellScene->updateLightSSBO();
	cornellScene->updateSceneSettings(glm::vec3(0.0, 0.0, 0.0), NO_FOG, white, 1, 10, 1);
	cornellScene->setBackgroundColor(glm::vec3(0, 0, 0));
	cornellScene->setRootNode(floor_node);
	CVK::State::getInstance()->setScene(cornellScene);

	cornell_RTscene = new CVK_RT_GPU::Scene(floor_node);

	cornell_RTscene->getDataStructure()->setVoxRes(glm::uvec3(32, 32, 32));
	cornell_RTscene->getDataStructure()->setLSRes(glm::uvec3(1));
	cornell_RTscene->getDataStructure()->setLS_PIll_Res(glm::uvec3(32, 32, 32));
	cornell_RTscene->getDataStructure()->setNg(16);
	cornell_RTscene->getDataStructure()->setNls(4);

	CVK::State::getInstance()->setScene(cornellScene);
	CVK_RT_GPU::State::getRTInstance()->setRTScene(cornell_RTscene);

	camera = cornellScene->getCamera();
	CVK::State::getInstance()->setCamera(camera);

	CVK::State::getInstance()->updateMaterialSSBO();
}

void charCallback(GLFWwindow *window, unsigned int key)
{
	glm::vec3 pos, center, up;
	float theta, phi, radius;
	glm::mat4 mat4;
	CVK_RT_GPU::Scene *RTscene;
	unsigned int maxLevel;

	switch (key)
	{
	case '^': //reset HD or UHD to normal mode
		width = WIDTH;
		height = HEIGHT;
		glfwSetWindowSize(window, DOUBLEWIDTH, height);
		glfwSetWindowPos(window, 100, 50);
		resizeCallback(window, width, height);
		break;
	case '$': // '§'
		init_scene(CORNELL);
		CVK::State::getInstance()->setScene(cornellScene);
		CVK_RT_GPU::State::getRTInstance()->setRTScene(cornell_RTscene);
		camera = cornellScene->getCamera();
		CVK::State::getInstance()->setCamera(camera);
		resizeCallback(window, width, height); //in case it changed
		render_type = OPENGL;
		break;
	case '1':
		render_type = GPU_RT_VOXEL;
		printf("INFO: Voxel\n");
		CVK_RT_GPU::State::getRTInstance()->getRTScene()->getDataStructure()->resetRTUniformLocations();
		break;
	case '2':
		render_type = GPU_RT_LS_CAND;
		printf("INFO: LineSpace candidate list\n");
		CVK_RT_GPU::State::getRTInstance()->getRTScene()->getDataStructure()->resetRTUniformLocations();
		break;
	case '3':
		render_type = GPU_RT_LS_CAND_2PASS;
		printf("INFO: GBuffer + LineSpace candidate list\n");
		CVK_RT_GPU::State::getRTInstance()->getRTScene()->getDataStructure()->resetRTUniformLocations();
		break;
	case '4':
		render_type = GPU_RT_LS_PREILLUM;
		printf("INFO: LineSpace  Pre-Illuminated shafts\n");
		CVK_RT_GPU::State::getRTInstance()->getRTScene()->getDataStructure()->resetRTUniformLocations();
		break;
	case '5':
		render_type = GPU_RT_LS_PREILLUM_2PASS;
		printf("INFO: LineSpace Pre-Illuminated shafts\n");
		CVK_RT_GPU::State::getRTInstance()->getRTScene()->getDataStructure()->resetRTUniformLocations();
		break;
	case '6':
		render_type = GPU_RT_LS_SIG;
		printf("INFO: LineSpace signature + candidate list\n");
		CVK_RT_GPU::State::getRTInstance()->getRTScene()->getDataStructure()->resetRTUniformLocations();
		break;
	case '7':
		render_type = GPU_RT_BVH;
		printf("INFO: BVH\n");
		CVK_RT_GPU::State::getRTInstance()->getRTScene()->getDataStructure()->resetRTUniformLocations();
		break;
	case '8':
		render_type = GPU_RT_OCTREE;
		printf("INFO: Octree (might crash)\n");
		CVK_RT_GPU::State::getRTInstance()->getRTScene()->getDataStructure()->resetRTUniformLocations();
		break;
	case 'w':
		WireFrame = !WireFrame;
		if (WireFrame)
			drawmode = GL_LINE;
		else
			drawmode = GL_FILL;
		glPolygonMode(GL_FRONT_AND_BACK, drawmode);
		break;
	case 'p':
		CVK::State::getInstance()->getMaterialBuffer()->printInfo();
		CVK_RT_GPU::State::getRTInstance()->getRTScene()->printInfo();

		RTscene = CVK_RT_GPU::State::getRTInstance()->getRTScene();
		RTscene->getDataStructure()->printInfo();
		break;
	case 'o':
		render_type = OPENGL;
		break;
	case 'c':
		phi = cam_trackball->getPhi();
		theta = cam_trackball->getTheta();
		radius = cam_trackball->getRadius();
		cam_trackball->setPhi(0);
		cam_trackball->setTheta(1.57);
		cam_trackball->setRadius(5);
		break;
	case 'd':
		variance += 0.001;
		printf("variance = %f\n", variance);
		break;
	case 'D':
		variance -= 0.001;
		if (variance < 0)
			variance = 0;
		printf("variance = %f\n", variance);
		break;
	case 'f':
		width = H_WIDTH;
		height = H_HEIGHT;
		glfwSetWindowSize(window, width, height);
		glfwSetWindowPos(window, 0, 0);
		resizeCallback(window, width, height);
		break;
	case 'F':
		width = U_WIDTH;
		height = U_HEIGHT;
		glfwSetWindowSize(window, width, height);
		glfwSetWindowPos(window, 0, 0);
		resizeCallback(window, width, height);
		break;
	case 'k':
		spec += 0.05;
		if (spec >= 1) spec = 1.f;
		printf("kr: %f\n", spec);
		mat->setKr(spec);
		mat->setKd((1 - spec) / 2.f);
		mat->setKs((1 - spec) / 2.f);
		CVK::State::getInstance()->updateMaterialSSBO();
		break;
	case 'K':
		spec -= 0.05;
		if (spec <= 0) spec = 0.f;
		printf("krs: %f\n", spec);
		mat->setKr(spec);
		mat->setKd((1 - spec) / 2.f);
		mat->setKs((1 - spec) / 2.f);
		CVK::State::getInstance()->updateMaterialSSBO();
		break;
	case 'a':
		epsilon1 += 1;
		printf("epsilon1 = %f\n", epsilon1);
		break;
	case 'A':
		epsilon1 -= 1;
		if (epsilon1 < 0)
			epsilon1 = 0;
		printf("epsilon1 = %f\n", epsilon1);
		break;
	case 'r':
		whichTracer = RAYTRACER;
		CVK_RT_GPU::State::getRTInstance()->getRTScene()->getDataStructure()->resetRTUniformLocations();
		break;
	case 'R':
		whichTracer = PATHTRACER;
		CVK_RT_GPU::State::getRTInstance()->getRTScene()->getDataStructure()->resetRTUniformLocations();
		break;
		//subdivide hierarchy
	case 's':
		refineTree = true;
		printf("Tree is being refined by one step");
		break;
	}
}

void startTime()
{
	glFinish();
	std::cout << "time" << std::endl;
	start_time = omp_get_wtime();
}

void endTime(char *name, int mode)
{
	glFinish();
	end_time = omp_get_wtime();
	if (mode == 0)
		fprintf(file, "%s; %f; FPS\n", name, 1.0 / (end_time - start_time));
	if (mode == 1)
		fprintf(file, "%s; %f; msec\n", name, (end_time - start_time) * 1000.f);
}

void updateSsbos(CVK_RT_GPU::Scene* rtScene, CVK::Scene* scene, CVK::ShaderSet* shader, CVK::ShaderSet* shader2) {
	GLuint ssboID;

	ssboID = CVK::State::getInstance()->getMaterialSSBOID();

	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, MATERIAL_BUFFER, ssboID);

	ssboID = scene->getLightSSBOID();
	GLuint nLightsID = glGetUniformLocation(shader2->getProgramID(), "nLights");
	glUniform1i(nLightsID, scene->getLights()->size());
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, LIGHT_BUFFER, ssboID);
	ssboID = rtScene->getObjectSSBOID();
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, OBJECTS_BUFFER, ssboID);
	ssboID = rtScene->getTriangleSSBOID();
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, TRIANGLES_BUFFER, ssboID);
	ssboID = rtScene->getSphereSSBOID();
	if (ssboID != INVALID_OGL_VALUE)
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, SPHERES_BUFFER, ssboID);
	ssboID = CVK_RT_GPU::State::getRTInstance()->getRTScene()->getConeSSBOID();
	if (ssboID != INVALID_OGL_VALUE)
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, CONES_BUFFER, ssboID);
}

void generateComputeShader(){
	//init shader set 
	const char *CsShaderName[1] = { SHADERS_PATH "HierarchicalRadiosity/HierRad_CS.glsl" };
	CS_HierRad = new CVK::ShaderSet(COMPUTE_SHADER_BIT, CsShaderName);
	CS_HierRad->useProgram();

	const char *HR_initialLinkingSource[1] = { SHADERS_PATH "HierarchicalRadiosity/HR_initialLinking.glsl" };
	CS_HRinitialLinking = new CVK::ShaderSet(COMPUTE_SHADER_BIT, HR_initialLinkingSource);
	CS_HRinitialLinking->useProgram();

	const char *HRrefineSource[1] = { SHADERS_PATH "HierarchicalRadiosity/HR_refine.glsl" };
	CS_HRrefine = new CVK::ShaderSet(COMPUTE_SHADER_BIT, HRrefineSource);
	CS_HRrefine->useProgram(); 
}

void initSSBOs() {
	
	glGenBuffers(1, &linksList); //33
	glGenTextures(1, &treeTextures); //28?
	glGenTextures(1, &areaTextures);
	glGenTextures(1, &radTextures);
	glGenTextures(1, &radTextures2);
	glGenBuffers(1, &outputFfSsbo);
	glGenBuffers(1, &seSsbo);
	glGenBuffers(1, &texHandlesSsbo);
	glGenBuffers(1, &radTexHandleSSBO);
	glGenBuffers(1, &radTexHandleSSBO2);
	glGenBuffers(1, &areaHandlesSsbo);

	//Buffer for linked List connections
	link* list = new link[LINKEDLISTLENGTH];
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, linksList);
	glBufferStorage(GL_SHADER_STORAGE_BUFFER, sizeof(link)* LINKEDLISTLENGTH, NULL, GL_DYNAMIC_STORAGE_BIT | GL_MAP_READ_BIT | GL_MAP_WRITE_BIT);

	float* outputFFs = new float[12];
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, outputFfSsbo);
	glBufferStorage(GL_SHADER_STORAGE_BUFFER, sizeof(float) * 12, NULL, GL_DYNAMIC_STORAGE_BIT | GL_MAP_READ_BIT | GL_MAP_WRITE_BIT);
	er = glGetError();

	GLuint64 treeTexturesHandles[10];
	int triangleSceneCount = cornell_RTscene->getScene()->size();
	int size = glm::pow(2, MIPMAPLEVELS - 1);
	er = glGetError();

	glBindTexture(GL_TEXTURE_2D_ARRAY, treeTextures);
	glTexStorage3D(GL_TEXTURE_2D_ARRAY, MIPMAPLEVELS, GL_RGBA16F, size, size, triangleSceneCount);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_REPEAT);
	er = glGetError();
	for (int i = 0; i < MIPMAPLEVELS; i++) {
		if (i < 10) {
			treeTexturesHandles[i] = glGetImageHandleARB(treeTextures, i, GL_TRUE, 0, GL_RGBA16F);
			glMakeImageHandleResidentARB(treeTexturesHandles[i], GL_READ_WRITE);
		}
	}
	er = glGetError();
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, texHandlesSsbo);
	glBufferStorage(GL_SHADER_STORAGE_BUFFER, sizeof(GLuint64) * 10, NULL, GL_DYNAMIC_STORAGE_BIT | GL_MAP_READ_BIT | GL_MAP_WRITE_BIT);
	glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(GLuint64) * 10, &treeTexturesHandles[0]);
	er = glGetError();

	GLuint64 unshotRadHandles[10];
	glBindTexture(GL_TEXTURE_2D_ARRAY, radTextures);

	glTexStorage3D(GL_TEXTURE_2D_ARRAY, MIPMAPLEVELS, GL_RGBA16F, size, size, triangleSceneCount);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_REPEAT);
	er = glGetError();
	for (int i = 0; i < MIPMAPLEVELS; i++) {
		if (i < 10) {
			unshotRadHandles[i] = glGetImageHandleARB(radTextures, i, GL_TRUE, 0, GL_RGBA16F);
			glMakeImageHandleResidentARB(unshotRadHandles[i], GL_READ_WRITE);
		}
	}
	er = glGetError();
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, radTexHandleSSBO);
	glBufferStorage(GL_SHADER_STORAGE_BUFFER, sizeof(GLuint64) * 10, NULL, GL_DYNAMIC_STORAGE_BIT | GL_MAP_READ_BIT | GL_MAP_WRITE_BIT);
	glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(GLuint64) * 10, &unshotRadHandles[0]);
	er = glGetError();

	GLuint64 unshotRadHandles2[10];
	glBindTexture(GL_TEXTURE_2D_ARRAY, radTextures2);

	glTexStorage3D(GL_TEXTURE_2D_ARRAY, MIPMAPLEVELS, GL_RGBA16F, size, size, triangleSceneCount);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_REPEAT);
	er = glGetError();
	for (int i = 0; i < MIPMAPLEVELS; i++) {
		if (i < 10) {
			unshotRadHandles2[i] = glGetImageHandleARB(radTextures2, i, GL_TRUE, 0, GL_RGBA16F);
			glMakeImageHandleResidentARB(unshotRadHandles2[i], GL_READ_WRITE);
		}
	}
	er = glGetError();
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, radTexHandleSSBO2);
	glBufferStorage(GL_SHADER_STORAGE_BUFFER, sizeof(GLuint64) * 10, NULL, GL_DYNAMIC_STORAGE_BIT | GL_MAP_READ_BIT | GL_MAP_WRITE_BIT);
	glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(GLuint64) * 10, &unshotRadHandles2[0]);
	er = glGetError();

	GLuint64 areaTexHandles[10];
	//create textures for the trees polygons * 2^Treedepth times
	glBindTexture(GL_TEXTURE_2D_ARRAY, areaTextures);

	er = glGetError();
	glTexStorage3D(GL_TEXTURE_2D_ARRAY, MIPMAPLEVELS, GL_R16F, size, size, triangleSceneCount);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_REPEAT);
	er = glGetError();
	for (int i = 0; i < MIPMAPLEVELS; i++) {
		if (i < 10) {
			areaTexHandles[i] = glGetImageHandleARB(areaTextures, i, GL_TRUE, 0, GL_R16F);
			glMakeImageHandleResidentARB(areaTexHandles[i], GL_READ_WRITE);
		}
	}
	
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, areaHandlesSsbo);
	glBufferStorage(GL_SHADER_STORAGE_BUFFER, sizeof(GLuint64) * 10, NULL, GL_DYNAMIC_STORAGE_BIT | GL_MAP_READ_BIT | GL_MAP_WRITE_BIT);
	glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(GLuint64) * 10, &areaTexHandles[0]);

	GLint maxssbo;
	glGetIntegerv(GL_MAX_SHADER_STORAGE_BUFFER_BINDINGS, &maxssbo);
};


int main()
{
	GLenum error;
	glm::vec3 *bbox;

	// Init GLFW and GLEW
	glfwInit();
	glEnable(GL_DEBUG_OUTPUT);

	window = glfwCreateWindow(WIDTH, HEIGHT, "HierRadiosity", 0, 0);
	glfwSetWindowPos(window, 100, 50);
	glfwSetCharCallback(window, charCallback);
	glfwSetWindowSizeCallback(window, resizeCallback);
	glfwMakeContextCurrent(window);
	glewInit();

	// OpenGL parameters
	glEnable(GL_DEPTH_TEST);
	glEnable(GL_TEXTURE_2D);
	glEnable(GL_TEXTURE_3D);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	init_shader();
	init_material();
	init_camera();
	init_scene(scene);
	init_fbos();

	generateComputeShader();
	initSSBOs();
	PrintInfo();
	
	//Uniform für BVH
	CVK_RT_GPU::Scene *RT_scene = CVK_RT_GPU::State::getRTInstance()->getRTScene();
	RT_scene->getDataStructure()->initDataStructure(GPU_RT_BVH);
	RT_scene->getDataStructure()->updateRTUniforms(GPU_RT_BVH, CS_HierRad->getProgramID());
	std::vector< CVK_RT::Object*> *objectList = RT_scene->getScene();
	int objCount = RT_scene->getScene()->size();
	int size = glm::pow(2, MIPMAPLEVELS - 1); // max image size

	//Bind all SSBOs
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, linksList);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 27, linksList);

	glBindBuffer(GL_SHADER_STORAGE_BUFFER, outputFfSsbo);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 25, outputFfSsbo);

	glBindBuffer(GL_SHADER_STORAGE_BUFFER, seSsbo);
	HrInfo->objcnt = objCount;
	HrInfo->mipmaplevel = MIPMAPLEVELS;
	HrInfo->linkedListSize = LINKEDLISTLENGTH;
	HrInfo->listCounter = -1;
	HrInfo->unshotRadSource = 1;
	HrInfo->gatherLights = true;
	int sesize = sizeof(&HrInfo);
	glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(*HrInfo), HrInfo, GL_DYNAMIC_DRAW);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 26, seSsbo);

	//clear textures
	glBindTexture(GL_TEXTURE_2D_ARRAY, treeTextures);
	glClearTexImage(treeTextures, 0, GL_RGBA, GL_FLOAT, clearColor);
	glGenerateMipmap(GL_TEXTURE_2D_ARRAY);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, texHandlesSsbo);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 28, texHandlesSsbo);

	glBindTexture(GL_TEXTURE_2D_ARRAY, radTextures);
	glClearTexImage(radTextures, 0, GL_RGBA, GL_FLOAT, clearColor);
	glGenerateMipmap(GL_TEXTURE_2D_ARRAY);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, radTexHandleSSBO);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 30, radTexHandleSSBO);

	glBindTexture(GL_TEXTURE_2D_ARRAY, radTextures2);
	glClearTexImage(radTextures2, 0, GL_RGBA, GL_FLOAT, clearColor);
	glGenerateMipmap(GL_TEXTURE_2D_ARRAY);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, radTexHandleSSBO2);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 24, radTexHandleSSBO2);

	glBindTexture(GL_TEXTURE_2D_ARRAY, areaTextures);
	glClearTexImage(areaTextures, 0, GL_R, GL_FLOAT, clearColor);
	glGenerateMipmap(GL_TEXTURE_2D_ARRAY);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, areaHandlesSsbo);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 29, areaHandlesSsbo);

	//Render Scene
	error = glGetError();

	updateSsbos(RT_scene, cornellScene, CS_HierRad, phongBufferShader);

	glm::vec3 BgCol = CVK::State::getInstance()->getScene()->getBackgroundColor();
	//glClearColor(BgCol.r, BgCol.g, BgCol.b, 01.0); //might have change since it belongs to scene
	glClearColor(0, 0.05, 0.2, 01.0);
	error = glGetError();
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	glViewport(0, 0, width, height);

	//Update Camera
	camera = CVK::State::getInstance()->getCamera();
	camera->update(window);
	error = glGetError();
	
	glColor3b(000000, 000000, 000000);

	//Initial Linking
	CS_HRinitialLinking->useProgram();
	glDispatchCompute(1, 1, 1);
	glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
	
	int debugRefine = 0;
	glColor3b(000000, 000000, 000000);
	while (!glfwWindowShouldClose(window))
	{
		startTime();

		glm::vec3 BgCol = CVK::State::getInstance()->getScene()->getBackgroundColor();
		glClearColor(0, 0.05, 0.2, 01.0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glViewport(0, 0, width, height);
	
		//Update Camera
		camera = CVK::State::getInstance()->getCamera();
		camera->update(window);
		
		if (refineTree == true) {
			glBindTexture(GL_TEXTURE_2D_ARRAY, treeTextures);
			glClearTexImage(treeTextures, 0, GL_RGBA, GL_FLOAT, clearColor);
			glGenerateMipmap(GL_TEXTURE_2D_ARRAY);
			glBindBuffer(GL_SHADER_STORAGE_BUFFER, texHandlesSsbo);
			glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 28, texHandlesSsbo);

			glBindTexture(GL_TEXTURE_2D_ARRAY, radTextures);
			glClearTexImage(radTextures, 0, GL_RGBA, GL_FLOAT, clearColor);
			glGenerateMipmap(GL_TEXTURE_2D_ARRAY);
			glBindBuffer(GL_SHADER_STORAGE_BUFFER, radTexHandleSSBO);
			glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 30, radTexHandleSSBO);

			glBindTexture(GL_TEXTURE_2D_ARRAY, radTextures2);
			glClearTexImage(radTextures2, 0, GL_RGBA, GL_FLOAT, clearColor);
			glGenerateMipmap(GL_TEXTURE_2D_ARRAY);
			glBindBuffer(GL_SHADER_STORAGE_BUFFER, radTexHandleSSBO2);
			glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 31, radTexHandleSSBO2);

			CS_HRrefine->useProgram();
			glDispatchCompute(1, 1, 1);
			glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
			error = glGetError();
			glColor3b(000000, 000000, 000000);
			refineTree = false;
		}

		//start compute shader
		CS_HierRad->useProgram();
		glDispatchCompute(1, 1, 1);
		glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
		error = glGetError();

		glBindBuffer(GL_SHADER_STORAGE_BUFFER, outputFfSsbo);
		float* readffs = (float *)glMapBuffer(GL_SHADER_STORAGE_BUFFER, GL_READ_ONLY);
		glUnmapBuffer(GL_SHADER_STORAGE_BUFFER);
		std::cout << readffs[0] << " links" << std::endl;
		error = glGetError();
		glColor3b(000000, 000000, 000000);
		
		//other shaders
		CVK::State::getInstance()->setShader(phongBufferShader);
		error = glGetError();
		phongBufferShader->useProgram();
		phongBufferShader->update();
		glPolygonMode(GL_FRONT_AND_BACK, drawmode);
		RT_scene->renderHRszene();
		error = glGetError();
	
		endTime("HierRad", 0);

		glfwSwapBuffers(window);
		glfwPollEvents();
	}
	glfwDestroyWindow(window);
	glfwTerminate();
	return 0;
}

