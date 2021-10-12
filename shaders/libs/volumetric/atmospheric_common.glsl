const vec3  rayleigh_scattering         = vec3(5.8, 13.5, 33.1) * 1e-6;
const vec3  rayleigh_absorption         = vec3(0.0);
const float rayleigh_distribution       = 8000.0;

const vec3  mie_scattering              = vec3(4.0, 4.0, 4.0) * 1e-6;
const vec3  mie_absorption              = mie_scattering * 0.11;
const float mie_distribution            = 1200.0;

const vec3  ozone_scattering            = vec3(0.0);
const vec3  ozone_absorption            = vec3(3.426, 8.298, 0.356) * 0.12 * 10e-7;

const float planet_radius               = 6360e3;
const float atmosphere_radius           = 6420e3;