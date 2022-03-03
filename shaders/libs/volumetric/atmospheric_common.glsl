#if Atmosphere_Profile == Default
    const vec3  rayleigh_scattering         = vec3(5.8, 13.5, 33.1) * 1e-6;
    const vec3  rayleigh_absorption         = vec3(0.0);
    const float rayleigh_distribution       = 8000.0;

    const vec3  mie_scattering              = vec3(2.0, 2.0, 2.0) * 1e-6;
    const vec3  mie_absorption              = mie_scattering * 0.11;
    const float mie_distribution            = 1200.0;

    const vec3  ozone_scattering            = vec3(0.0);
    const vec3  ozone_absorption            = vec3(3.426, 8.298, 0.356) * 0.12 * 10e-7;

    const float planet_radius               = 6360e3;
    const float atmosphere_radius           = 6420e3;
#else
    const vec3  rayleigh_scattering         = vec3(Rayleigh_Transmittance_R, Rayleigh_Transmittance_G, Rayleigh_Transmittance_B) * 1e-6 * Rayleigh_Scattering;
    const vec3  rayleigh_absorption         = vec3(Rayleigh_Transmittance_R, Rayleigh_Transmittance_G, Rayleigh_Transmittance_B) * 1e-6 * Rayleigh_Absorption;
    const float rayleigh_distribution       = Rayleigh_Distribution;

    const vec3  mie_scattering              = vec3(Mie_Transmittance_R, Mie_Transmittance_G, Mie_Transmittance_B) * 1e-6 * Mie_Scattering;
    const vec3  mie_absorption              = vec3(Mie_Transmittance_R, Mie_Transmittance_G, Mie_Transmittance_B) * 1e-6 * Mie_Absorption;
    const float mie_distribution            = Mie_Distribution;

    const vec3  ozone_scattering            = vec3(Ozone_Transmittance_R, Ozone_Transmittance_G, Ozone_Transmittance_B) * 1e-6 * Ozone_Scattering;
    const vec3  ozone_absorption            = vec3(Ozone_Transmittance_R, Ozone_Transmittance_G, Ozone_Transmittance_B) * 1e-6 * Ozone_Absorption;

    const float planet_radius               = Planet_Radius;
    const float atmosphere_radius           = Atmosphere_Radius;
#endif

    //#define Near_Atmosphere_Clouds_Shadow

    #define Fog_End 500                             //[500 1000 1500 2000 2500 3000 3500 4000 4500 5000 5500 6000 6500 7000 7500 8000 8500 9000 9500 10000 10500 11000 11500 12000 12500 13000 13500 14000 14500 15000 15500 16000 16500 17000 17500 18000 18500 19000 19500 20000 20500 21000 21500 22000 22500 23000 23500]
    #define Fog_Start 22000                         //[500 1000 1500 2000 2500 3000 3500 4000 4500 5000 5500 6000 6500 7000 7500 8000 8500 9000 9500 10000 10500 11000 11500 12000 12500 13000 13500 14000 14500 15000 15500 16000 16500 17000 17500 18000 18500 19000 19500 20000 20500 21000 21500 22000 22500 23000 23500]
    #define Fog_Clear_Time 1000.0                   //[100.0 200.0 300.0 400.0 500.0 600.0 700.0 800.0 900.0 1000.0 1500.0 2000.0 2500.0 3000.0 3500.0 4000.0 4500.0 5000.0 5500.0 6000.0]

    #define Fog_Density 1.0                         //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]
    #define Fog_Exponential_Fog_Vaule 16.0          //[1.0 2.0 4.0 8.0 16.0 32.0 64.0]
    #define Fog_Exponential_Fog_Bottom 2.0          //[1.0 2.0 4.0 8.0 16.0 32.0 64.0]
    #define Fog_Reduce_Density_Far 0.005            //[0.0 0.001 0.0025 0.005 0.0075 0.01]

    #define Rain_Fog_Density 1.0                    //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]
    #define Rain_Fog_Exponential_Fog_Vaule 1000.0   //[100.0 200.0 300.0 400.0 500.0 600.0 700.0 800.0 900.0 1000.0 1500.0 2000.0]
    #define Rain_Fog_Exponential_Fog_Bottom 2.0     //[1.0 2.0 4.0 8.0 16.0 32.0 64.0]
    #define Rain_Fog_Reduce_Density_Far 0.0         //[0.0 0.001 0.0025 0.005 0.0075 0.01]

    const vec3 fog_scattering = vec3(0.001);
    const vec3 fog_absorption = vec3(0.0);

    #define Reduce_Fog_Indoor_Density
    #define Reduce_Fog_Bottom_Density

#define Fog_Scattering_R 0.0005
#define Fog_Scattering_G 0.0005
#define Fog_Scattering_B 0.0005

#define Fog_Absorption_R 0.00001
#define Fog_Absorption_G 0.00001
#define Fog_Absorption_B 0.00001

#define Fog_Albedo_R 0.7
#define Fog_Albedo_G 0.8
#define Fog_Albedo_B 1.0

#define Fog_Eccentricity -0.3
#define Fog_Silver_Spread 0.4
#define Fog_Silver_Intensity 0.3
#define Fog_Front_Scattering 0.8
#define Fog_Scattering_Density 2.0
#define Fog_Absorption_Density 2.0
//#define Fog_Height 64.0
#define Fog_Distribution 16.0

#define RainFog_Eccentricity -0.1
#define RainFog_Silver_Spread 0.5
#define RainFog_Silver_Intensity 0.2
#define RainFog_Front_Scattering 0.4

#define RainFog_Scattering_Density 10.0
#define RainFog_Absorption_Density 10.0
#define RainFog_Height 1000.0
//#define RainFog_Distribution 16.0

//#define Haze_Scattering_Density 2.0
//#define Haze_Absorption_Density 8.0
//#define Haze_Height 128.0
//#define Haze_Front_Scattering 0.35

#ifndef VERTEX_DATA_INOUT
const float timeFog = 0.0;
const float timeHaze = 0.0;
#endif

struct AtmosphericData {
    vec3 fogScattering;
    vec3 fogAbsorption;
    vec3 fogTransmittance;
    vec3 fogAlbedo;

    float fogHeight;
    float fogDistribution;

    float fogEccentricity;
    float fogSilverSpread;
    float fogSilverIntensity;
    float fogFrontScattering;

    float fogDensity;
};

AtmosphericData GetAtmosphericDate(in float fog, in float haze) {
    AtmosphericData atmospheric;

    atmospheric.fogHeight = 63.0;//mix(Fog_Height, RainFog_Height, rainStrength);
    atmospheric.fogDistribution = Fog_Distribution;

    atmospheric.fogScattering = vec3(Fog_Scattering_R, Fog_Scattering_G, Fog_Scattering_B) * max(fog * Fog_Scattering_Density, rainStrength * RainFog_Scattering_Density);
    atmospheric.fogAbsorption = vec3(Fog_Absorption_R, Fog_Absorption_G, Fog_Absorption_B) * max(fog * Fog_Absorption_Density, rainStrength * RainFog_Absorption_Density);
    atmospheric.fogTransmittance = atmospheric.fogScattering + atmospheric.fogAbsorption;
    atmospheric.fogAlbedo = vec3(1.0);

    atmospheric.fogEccentricity     = mix(Fog_Eccentricity, RainFog_Eccentricity, rainStrength);
    atmospheric.fogSilverSpread     = 0.999 - mix(Fog_Silver_Spread, RainFog_Silver_Spread, rainStrength);
    atmospheric.fogSilverIntensity  = mix(Fog_Silver_Intensity, RainFog_Silver_Intensity, rainStrength);
    atmospheric.fogFrontScattering  = mix(Fog_Front_Scattering, RainFog_Front_Scattering, rainStrength);

    return atmospheric;
}

vec3 CalculateFogLight(in float depth, in vec3 t) {
    vec3 opticalDepth = depth * t;

    return (exp(-opticalDepth) + exp(-opticalDepth * 0.25) * 0.7) / 1.7;
}

float CalculateFogPhaseFunction(in float theta, in AtmosphericData atmospheric) {
    return mix(HG(theta, Fog_Eccentricity), HG(theta, atmospheric.fogSilverSpread) * atmospheric.fogSilverIntensity, atmospheric.fogFrontScattering); 
}