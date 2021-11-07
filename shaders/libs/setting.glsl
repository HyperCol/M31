//Option
#define Auto -2
#define OFF -1
#define Low 0
#define Medium 1
#define High 2
#define Ultra 3

//Lighting Setting
#define Sun_Light_Luminance 4.0
#define Moon_Light_Luminance 0.1
#define Blocks_Light_Luminance 0.1
#define Nature_Light_Min_Luminance 0.1
#define No_Nature_Light_Luminance 0.0

#define Held_Light_Quality Medium                   //[Medium High]

//Atmosphere
#define Atmospheric_Rayleigh_Scattering 1.0
#define Atmospheric_Rayleigh_Absorption 0.0
#define Atmospheric_Mie_Scattering 1.0
#define Atmospheric_Mie_Absorption 1.0
#define Atmospheric_Ozone_Scattering 0.0
#define Atmospheric_Ozone_Absorption 1.0
#define Atmospheric_Shape Sphere                    //[Sphere Cube]

//Sky
#define Moon_Texture_Luminance 4.0                  //[1.0 2.0 3.0 4.0 5.0 6.0 7.0]
#define Moon_Radius 1.0                             //[0.125 0.25 0.5 1.0 2.0 4.0 8.0]
#define Moon_Distance 1.0                           //[0.125 0.25 0.5 1.0 2.0 4.0 8.0]

#define Stars_Fade_In 0.1                           //[0.01 0.05 0.1 0.15 0.2]
#define Stars_Fade_Out 0.0                          //[-1.0 -0.25 -0.2 -0.15 -0.1 -0.05 0.0]
#define Stars_Visible 0.005                         //[0.00062 0.00125 0.0025 0.005 0.01 0.02 0.04]
#define Stars_Luminance 0.1                         //[0.1 0.25 0.5 0.75 1.0 2.5 5.0 7.5 10.0 25.0 50.0 75.0 100.0]
#define Stars_Speed 1.0                             //[0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]
#define Planet_Angle 0.1                            //[-0.3 -0.2 -0.1 0.0 0.1 0.2 0.3 0.4 0.5] +:north -:south

#define Polaris_Size 2.0                            //[1.0 2.0 3.0 4.0]
#define Polaris_Luminance 1.0                       //[1.0]
#define Polaris_Offset_X 4.0                        //[1.0 2.0 3.0 4.0 5.0 6.0 7.0]
#define Polaris_Offset_Y 4.0                        //[1.0 2.0 3.0 4.0 5.0 6.0 7.0]

//Camera Settings
#define Camera_ISO 200                              //[25 50 100 200 400 800 1600]

#define Camera_Exposure_Value 0.0                   //[-4.0 -3.0 -2.0 -1.0 0.0 1.0 2.0 3.0 4.0]
#define Camera_Exposure_Min_EV 0.0                  //[-2.0 -1.0 0.0 1.0 2.0]
#define Camera_Exposure_Max_EV 8.0                  //[4.0 6.0 8.0 10.0 12.0]

#define Camera_Average_Exposure                     //
#define Camera_Exposure_Delay 2.0                   //[0.5 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0]

//#define Camera_DOF                                  //
#define Camera_Aperture 2.8                         //[1.0 1.4 2.0 2.8 4.0 5.6 8.0 11.0 16.0 22.0 32.0 44.0 64.0]
#define Camera_Focal_Length 0.004                   //[0.001 0.002 0.003 0.004 0.005 0.006 0.007 0.008 0.009 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1]
#define Camera_Focal_Distance_Auto                  //
#define Camera_Focal_Distance 1.0                   //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0 3.5 4.0 4.5 5.0 6.0 7.0 8.0 9.0 10.0]

#define Camera_FPS 45.0                             //[25.0 30.0 45.0 60.0 90.0 120.0 144.0 240.0]
#define Camera_Shutter_Speed 0                      //[0 10 20 30 40 50 60 70 80 90 100 150 200 300 400]

//#define Bloom_Intensity 0.2                         //[0.05 0.1 0.2 0.4 0.6 0.8 1.0 2.0 4.0 8.0 16.0]
#define Bloom_Exposure_Value -2.0                     //[-3.0 -2.5 -2.0 -1.5 -1.0]
    //#define Bloom_Intensity_Test                    //

//Antialiasing
#define Enabled_TAA
#define TAA_Accumulation_Shapress 50                //[0 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100]
#define TAA_Post_Processing_Sharpeness 50           //[0 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100]
#define TAA_Post_Processing_Sharpen_Limit 0.125     //[0.5 0.25 0.125 0.0625 0.03125]
//#define TAA_No_Clip