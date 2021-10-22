const float moon_radius = 1734000.0;
const float moon_distance = 38440000.0;

const float moon_in_one_tile = 9.0;

uniform sampler2D depthtex2;

uniform int moonPhase;

vec3 DrawMoon(in vec3 L, vec3 direction, float hit_planet) {
    if(hit_planet > 0.0) return vec3(0.0);

    vec2 traceingMoon = RaySphereIntersection(vec3(0.0) - L * (moon_distance * Moon_Distance + moon_radius * Moon_Radius), direction, vec3(0.0), moon_radius * Moon_Radius);
    vec2 traceingMoon2 = RaySphereIntersection(vec3(0.0) - L * (moon_distance * Moon_Distance + moon_radius * Moon_Radius), L, vec3(0.0), moon_radius * Moon_Radius);

    mat3 lightModelView = mat3(shadowModelView[0].xy, L.x,
                               shadowModelView[1].xy, L.y,
                               shadowModelView[2].xy, L.z);

    vec3 coord3 = lightModelView * direction; 
    vec2 coord2 = coord3.xy / coord3.z;
         coord2 *= max(0.0, traceingMoon2.x) / (moon_radius * Moon_Radius) * inversesqrt(moon_in_one_tile); 
         coord2 = coord2 * 0.5 + 0.5;

    float moon = float(moonPhase);
    vec2 chosePhase = vec2(mod(moon, 4), step(3.5, moon));

    vec2 coord = (coord2 + chosePhase) * vec2(0.25, 0.5);

    vec4 moon_texture = texture(depthtex2, coord + chosePhase); moon_texture.rgb = LinearToGamma(moon_texture.rgb);
    float hit_moon = float(abs(coord2.x - 0.5) < 0.5 && abs(coord2.y - 0.5) < 0.5 && coord3.z > 0.0);

    return moon_texture.rgb * (hit_moon * Moon_Light_Luminance * moon_texture.a * Moon_Texture_Luminance);    
}

vec3 DrawStars(in vec3 direction, float hit_planet) {
    if(hit_planet > 0.0) return vec3(0.0);

    vec2 coord = vec2(0.0);

    float angle = Planet_Angle * 2.0 * Pi;
    float time_angle = frameTimeCounter / (1200.0) * Stars_Speed * 2.0 * Pi;

    //mat2 rotate = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
    //mat2 time_rotate = mat2(cos(time_angle), sin(time_angle), -sin(time_angle), cos(time_angle));

    //direction.yz *= rotate;
    //direction.xz *= time_rotate;

    direction.yz = RotateDirection(direction.yz, angle);
    direction.xz = RotateDirection(direction.xz, -time_angle);

    vec3 n = abs(direction);
    vec3 coord3 = n.x > max(n.y, n.z) ? direction.yzx :
                  n.y > max(n.x, n.z) ? direction.zxy : 
                  direction;

    float stars = saturate(rescale(hash(floor(coord3.xy / coord3.z * 256.0)), (1.0 - Stars_Visible), 1.0));
          stars += float(floor(coord3.xy / coord3.z * 256.0 / Polaris_Size - vec2(Polaris_Offset_X, Polaris_Offset_Y)) == vec2(0.0)) * Polaris_Luminance * float(n.y > max(n.x, n.z) && coord3.y > 0.0);

    return vec3(stars);
}