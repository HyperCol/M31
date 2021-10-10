 vec3 d(const vec3 v,const vec3 z,vec3 y)
 {
   vec3 i=(z-v)*.5,m=y-(z+v)*.5;
   vec3 f=sign(m)*step(abs(abs(m)-i),vec3(1e-05));
   return normalize(f);
 }
 bool d(const vec3 v,const vec3 i,Ray m,inout float x,inout vec3 y)
 {
   vec3 z=m.inv_direction*(v-1e-05-m.origin),t=m.inv_direction*(i+1e-05-m.origin),n=min(t,z),s=max(t,z);
   float c=max(max(n.x,n.y),n.z);
   float f=min(min(s.x,s.y),s.z);
   float c2=max(c,0.);
   bool w=f>c2&&c2<x;
   if(w)
     y=d(v-1e-05,i+1e-05,m.origin+m.direction*c),x=c;
   return w;
 }
 bool c(vec3 v,float y,Ray f,inout float x,inout vec3 t)
 {
   bool i=false,m=false;
   if(y>=67.)
     return false;
   m=d(v,v+vec3(1.,1.,1.),f,x,t);
   i=m;
   return i;
 }

const int shadowMapResolution = 4096;
const int RAY_TRACING_RESOLUTION = shadowMapResolution >> 1;
const float RAY_TRACING_DIAMETER_TEMP = floor(pow(RAY_TRACING_RESOLUTION, 2.0 / 3.0));
const float RAY_TRACING_DIAMETER = RAY_TRACING_DIAMETER_TEMP - mod(RAY_TRACING_DIAMETER_TEMP, 2.0) - 1.0;

vec3 Fract01(vec3 pos)
{
	posf[0] = posf[0] == 0.0 ? 1.0 : posf[0];
	posf[1] = posf[1] == 0.0 ? 1.0 : posf[1];
	posf[2] = posf[2] == 0.0 ? 1.0 : posf[2];
	return posf;
}
FractedCameraPosition = Fract01(cameraPosition+.5);

vec2 worldPosToShadowCoord(vec3 worldPos)
{
	worldPos = clamp(worldPos, vec3(0.0), vec3(RAY_TRACING_DIAMETER));
	worldPos = floor(worldPos.xzy + 1e-05);
	worldPos.x += RAY_TRACING_DIAMETER * worldPos.z;
	vec2 shadowCoord;
	shadowCoord.x = mod(worldPos.x , RAY_TRACING_RESOLUTION);
	shadowCoord.y = worldPos.y + floor(worldPos.x / RAY_TRACING_RESOLUTION) * RAY_TRACING_DIAMETER;
	shadowCoord += 0.5;
	shadowCoord /= shadowMapResolution;
	return shadowCoord;
}

struct RayTrace{vec3 rayPos; vec3 rayDirInv; vec3 rayDirSign; vec3 rayDir; vec3 nextBlock;};

RayTrace startTrace(Ray ray)
{
	RayTrace raytrace;
	raytrace.rayPos = floor(ray.origin);
	raytrace.rayDirInv = abs(vec3(length(ray.direction)) / (ray.direction + 1e-07));
	raytrace.rayDirSign = sign(ray.direction);
	raytrace.rayDir = (raytrace.rayDirSign * (raytrace.rayPos - ray.origin) + raytrace.rayDirSign * 0.5 + 0.5) * raytrace.rayDirInv;
	raytrace.nextBlock = vec3(0.);
	return raytrace;
}

void Stepping(inout RayTrace v)
{
	v.nextBlock = step(v.rayDir.xyz, v.rayDir.yzx);
	v.nextBlock *= -v.nextBlock.zxy + 1.0;
	v.rayDir += v.nextBlock * v.rayDirInv, v.rayPos += v.nextBlock * v.rayDirSign;
}

float RayTracedShadow(vec3 worldPos, vec3 worldNormal, vec3 worldGeoNormal, vec3 worldDir, float parallaxOffset)
{
	vec3 rayOrigin = worldPos + 0.0002 * length(worldPos) * worldNormal + FractedCameraPosition - 
		(parallaxOffset * 0.2 / (saturate(dot(worldGeoNormal, -worldDir)) + 1e-06) + 0.0005) * worldDir;
	rayOrigin = clamp(rayOrigin + vec3(RAY_TRACING_DIAMETER / 2.0 - 1.0), vec3(-1.0), vec3(RAY_TRACING_DIAMETER - 1.0));
	Ray ray = MakeRay(rayOrigin, worldLightVector); // 采用阳光方向作为光追方向
	RayTrace raytrace = startTrace(ray);

	float shadow = 1.0, blockID = 0.0, rayLength = 114514.0;
	vec2 shadowCoord = vec2(0.0);
	vec3 targetNormal = worldLightVector;
	Stepping(raytrace);
	for(int i = 0; i < 5; i++)
	{
		shadowCoord = worldPosToShadowCoord(raytrace.rayPos);
		blockID = texture2DLod(shadowcolor, shadowCoord, 0).w * 255.0;
		if((blockID < 240.0 || abs(blockID - 248.0) < 7.0) && (blockID != 31.0 && abs(blockID - 38.5) > 1.0))
		{
			if(c(raytrace.rayPos, blockID, ray, rayLength, targetNormal))
			{
				if(abs(blockID - 33.5) < 2.0)
				{
					shadow = 0.0;
					break;
				}
				vec3 rayPos = fract(ray.origin + ray.direction * rayLength) - 0.5;
				vec2 texCoordOffset = vec2(0.0);
				if(abs(targetNormal.x) > 0.5)
					texCoordOffset = vec2(rayPos.z * -targetNormal.x, -rayPos.y) * abs(targetNormal.x);
				if(abs(targetNormal.y) > 0.5)
					texCoordOffset = vec2(rayPos.x, rayPos.z * targetNormal.y) * abs(targetNormal.y);
				if(abs(targetNormal.z) > 0.5)
					texCoordOffset = vec2(rayPos.x * targetNormal.z, -rayPos.y) * abs(targetNormal.z);
				vec4 blockData = texture2DLod(shadowcolor1, shadowCoord, 0);
				float textureResolusion = TEXTURE_RESOLUTION;
				#ifdef ADAPTIVE_PATH_TRACING_RESOLUTION
				if(blockID < 67.0 || abs(blockID - 111.0) < 29.0)
					textureResolusion = exp2(blockData.w * 255.0);
				#endif
				vec2 terrainSize = textureSize(colortex3, 0) / textureResolusion;
				vec2 texCoordPT = (floor(blockData.xy * terrainSize) + 0.5 + texCoordOffset.xy) / terrainSize;
				float isShadow = texture2DLod(colortex3, texCoordPT, 0).w;
				if(isShadow > 0.1 || abs(blockID - 61.5) > 31.0)
				{
					shadow = 0.0;
					break;
				}
				rayLength = 114514.0;
			}
		}
		Stepping(raytrace);
	}

	float depth = length(worldPos);
	shadow = mix(shadow, 1.0, saturate(rayLength * 5.0 - 0.1 * depth - 0.2));

	return shadow;
}