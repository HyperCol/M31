#define time frameTimeCounter*2.
#define aurora_power.3//[0.0 0.001 0.005 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]
#define aurora_r.7//[0.0 0.5 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]
#define aurora_g 1.0//[0.0 0.5 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]
#define aurora_b 1.3//[0.0 0.5 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]
#define aurora_noise 5.0//[0.0 0.5 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]
#define aurora_map 40.0//[0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0 31.0 32.0 33.0 34.0 35.0 36.0 37.0 38.0 39.0 40.0 41.0 42.0 43.0 44.0 45.0 46.0 47.0 48.0 49.0 50.0 51.0 52.0 53.0 54.0 55.0 56.0 57.0 58.0 59.0 60.0 61.0 62.0 63.0 64.0 65.0 66.0 67.0 68.0 69.0 70.0 71.0 72.0 73.0 74.0 75.0 76.0 77.0 78.0 79.0 80.0 81.0 82.0 83.0 84.0 85.0 86.0 87.0 88.0 89.0 90.0 91.0 92.0 93.0 94.0 95.0 96.0 97.0 98.0 99.0 100.0]

mat2 mm2(in float a){float c=cos(a),s=sin(a);return mat2(c,s,-s,c);}
mat2 m2=mat2(.95534,.29552,-.29552,.95534);
float tri(in float x){return clamp(abs(fract(x)-.5),.01,.49);}
vec2 tri2(in vec2 p){return vec2(tri(p.x)+tri(p.y),tri(p.y+tri(p.x)));}

float triNoise2d(in vec2 p,float spd)
{
    float z=1.8;
    float z2=2.5;
    float rz=0.;
    p*=mm2(p.x*.06);
    vec2 bp=p;
    if(worldTime<22975&&worldTime>12925){
        for(float i=0.;i<aurora_noise;i++){
            vec2 dg=tri2(bp*1.85)*.75;
            dg*=mm2(time*spd);
            p-=dg/z2;
            
            bp*=1.3;
            z2*=.45;
            z*=.42;
            p*=1.21+(rz-1.)*.02;
            
            rz+=tri(p.x+tri(p.y))*z;
            p*=-m2;
        }
    }
    return clamp(1./pow(rz*29.,1.3),0.,.55);
}

vec2 hash22(vec2 p)
{
    p=vec2(dot(p,vec2(127.1,311.7)),
    dot(p,vec2(269.5,183.3)));
    
    return-1.+2.*fract(sin(p)*43758.5453123);
}

float simplex_noise(vec2 p)
{
    const float K1=.366025404;// (sqrt(3)-1)/2;
    const float K2=.211324865;// (3-sqrt(3))/6;
    
    vec2 i=floor(p+(p.x+p.y)*K1);
    
    vec2 a=p-(i-(i.x+i.y)*K2);
    vec2 o=(a.x<a.y)?vec2(0.,1.):vec2(1.,0.);
    vec2 b=a-o+K2;
    vec2 c=a-1.+2.*K2;
    
    vec3 h=max(.5-vec3(dot(a,a),dot(b,b),dot(c,c)),0.);
    vec3 n=h*h*h*h*vec3(dot(a,hash22(i)),dot(b,hash22(i+o)),dot(c,hash22(i+1.)));
    
    return dot(vec3(70.,70.,70.),n);
}

const mat2 mtx=mat2(.80,.60,-.60,.80);
float fbm6(vec2 p){
    float f=0.;
    
    f+=.500000*simplex_noise(p);p=mtx*p*2.02;
    f+=.250000*simplex_noise(p);p=mtx*p*2.03;
    f+=.125000*simplex_noise(p);p=mtx*p*2.01;
    f+=.062500*simplex_noise(p);p=mtx*p*2.04;
    f+=.031250*simplex_noise(p);p=mtx*p*2.01;
    f+=.015625*simplex_noise(p);
    
    return f/.96875;
}

vec4 aurora(vec3 ro,vec3 rd)
{
    vec4 col=vec4(0);
    vec4 avgCol=vec4(0);
    vec4 excolor=vec4(aurora_r,aurora_g,aurora_b,1.);
    vec3 GlobleColor=vec3(abs((sin(worldTime/(1205*acos(-1.)))-.059)),abs(sin(worldTime/(1200*acos(-1.)))),abs((sin(worldTime/(1195*acos(-1.)))+.059)))*abs((sin(.265*worldDay)/4+.5));
    if(worldTime<22975&&worldTime>12925){
        for(float i=0.;i<aurora_map;i++)
        {
            float of=.006*fbm6(gl_FragCoord.xy)*smoothstep(0.,15.,i);
            float pt=((.8+pow(i,1.4)*.002)-ro.y)/(rd.y*2.+.4);
            pt-=of;
            vec3 bpos=ro+pt*rd;
            vec2 p=bpos.zx;
            float rzt=triNoise2d(p,.06);
            vec4 col2=vec4(0,0,0,rzt);
            col2.rgb=(sin(1.-vec3(2.15,-.5,1.2)+i*.043)*.5+.5)*rzt;
            avgCol=mix(avgCol,col2,.5);
            col+=avgCol*exp2(-i*.065-2.5)*smoothstep(0.,5.,i);
        }
    }
    col*=(clamp(rd.y*15.+.4,0.,1.));
    col*=excolor;
    col*=vec4(GlobleColor,1.);
    
    float tmp=(worldTime>22975&&worldTime<12925)?0:1;
    float timetmp=smoothstep(0.,1.,tmp);
    return col/20*aurora_power*timetmp;
}
