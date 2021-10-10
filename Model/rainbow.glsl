vec3 rainbow(in vec3 ray_dir){
    
    if(worldTime>100&&worldTime<11900)
    {
        vec3 rainbow_dir=normalize(vec3(sunPosition));
        float theta=degrees(acos(dot(rainbow_dir,ray_dir)));
        float brightness=0.;
        const float intensity=.30;
        if(abs(sunPosition.y)>.1){
            brightness=1.;
        }
        if(sunPosition.y<.1){
            brightness=0.;
        }
        vec3 color_range=vec3(50.,53.,56.);// angle for red, green and blue
        vec3 nd=clamp(1.-abs((color_range-theta)*.2),0.,1.);
        vec3 color=(3.*nd*nd-2.*nd*nd*nd)*intensity;
        return color*max((brightness-.8)*3.5,0.)*max(wetness-rainStrength,0.);
    }
}
