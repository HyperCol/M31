void FsrEasuCon(out vec4 con0, out vec4 con1, out vec4 con2, out vec4 con3,
// This the rendered image resolution being upscaled
in vec2 inputViewportInPixels,
// This is the resolution of the resource containing the input image (useful for dynamic resolution)
in vec2 inputSizeInPixels,
// This is the display resolution which the input image gets upscaled to
in vec2 outputSizeInPixels) {
    // Output integer position to a pixel position in viewport.
    vec2 invOutputSize = 1.0 / vec2(outputSizeInPixels.x, outputSizeInPixels.y);
    vec2 invInputSize = 1.0 / vec2(inputSizeInPixels.x, inputSizeInPixels.y);

    con0.x = inputViewportInPixels.x * invOutputSize.x;
    con0.y = inputViewportInPixels.y * invOutputSize.y;
    con0.z = 0.5 * inputViewportInPixels.x * invOutputSize.x - 0.5;
    con0.w = 0.5 * inputViewportInPixels.y * invOutputSize.y - 0.5;
    // Viewport pixel position to normalized image space.
    // This is used to get upper-left of 'F' tap.
    con1.x = invInputSize.x;
    con1.y = invInputSize.y;
    // Centers of gather4, first offset from upper-left of 'F'.
    //      +---+---+
    //      |   |   |
    //      +--(0)--+
    //      | b | c |
    //  +---F---+---+---+
    //  | e | f | g | h |
    //  +--(1)--+--(2)--+
    //  | i | j | k | l |
    //  +---+---+---+---+
    //      | n | o |
    //      +--(3)--+
    //      |   |   |
    //      +---+---+
    con1.z =  1.0 * invInputSize.x;
    con1.w = -1.0 * invInputSize.y;
    // These are from (0) instead of 'F'.
    con2.x = -1.0 * invInputSize.x;
    con2.y =  2.0 * invInputSize.y;
    con2.z =  1.0 * invInputSize.x;
    con2.w =  2.0 * invInputSize.y;

    con3.x = 0.0 * invInputSize.x;
    con3.y = 4.0 * invInputSize.y;
    con3.z = 0.0;
    con3.w = 0.0;
}

// Gather 4 ordering.
//  a b
//  r g
vec4 FsrEasuRF(in vec2 coord) {
    return vec4(texture(composite, coord).r,
                texture(composite, coord + vec2(texelSize.x, 0.0)).r,
                texture(composite, coord + vec2(texelSize.x, texelSize.y)).r,
                texture(composite, coord + vec2(0.0, texelSize.y)).r
                );
}

vec4 FsrEasuGF(in vec2 coord) {
    return vec4(texture(composite, coord).g,
                texture(composite, coord + vec2(texelSize.x, 0.0)).g,
                texture(composite, coord + vec2(texelSize.x, texelSize.y)).g,
                texture(composite, coord + vec2(0.0, texelSize.y)).g
                );
}

vec4 FsrEasuBF(in vec2 coord) {
    return vec4(texture(composite, coord).b,
                texture(composite, coord + vec2(texelSize.x, 0.0)).b,
                texture(composite, coord + vec2(texelSize.x, texelSize.y)).b,
                texture(composite, coord + vec2(0.0, texelSize.y)).b
                );
}

void FsrEasuSetF(
inout vec2 dir,
inout float len,
vec2 pp,
bool biS,bool biT,bool biU,bool biV,
float lA,float lB,float lC,float lD,float lE){
    // Compute bilinear weight, branches factor out as predicates are compiler time immediates.
    //  s t
    //  u v
    float w = (0.0);
    if(biS)w=((1.0)-pp.x)*((1.0)-pp.y);
    if(biT)w=           pp.x *((1.0)-pp.y);
    if(biU)w=((1.0)-pp.x)*           pp.y ;
    if(biV)w=           pp.x *           pp.y ;
    // Direction is the '+' diff.
    //    a
    //  b c d
    //    e
    // Then takes magnitude from abs average of both sides of 'c'.
    // Length converts gradient reversal to 0, smoothly to non-reversal at 1, shaped, then adding horz and vert terms.
    float dc=lD-lC;
    float cb=lC-lB;
    float lenX=max(abs(dc),abs(cb));
    lenX=1.0 / (lenX);
    float dirX=lD-lB;
    dir.x+=dirX*w;
    lenX=saturate(abs(dirX)*lenX);
    lenX*=lenX;
    len+=lenX*w;
    // Repeat for the y axis.
    float ec=lE-lC;
    float ca=lC-lA;
    float lenY=max(abs(ec),abs(ca));
    lenY=1.0 / (lenY);
    float dirY=lE-lA;
    dir.y+=dirY*w;
    lenY=saturate(abs(dirY)*lenY);
    lenY*=lenY;
    len+=lenY*w;
}

 void FsrEasuTapF(
 inout vec3 aC, // Accumulated color, with negative lobe.
 inout float aW, // Accumulated weight.
 vec2 off, // Pixel offset from resolve position to tap.
 vec2 dir, // Gradient direction.
 vec2 len, // Length.
 float lob, // Negative lobe strength.
 float clp, // Clipping point.
 vec3 c){ // Tap color.
    // Rotate offset by direction.
    vec2 v;
    v.x=(off.x*( dir.x))+(off.y*dir.y);
    v.y=(off.x*(-dir.y))+(off.y*dir.x);
    // Anisotropy.
    v*=len;
    // Compute distance^2.
    float d2=v.x*v.x+v.y*v.y;
    // Limit to the window as at corner, 2 taps can easily be outside.
    d2=min(d2,clp);
    // Approximation of lancos2 without sin() or rcp(), or sqrt() to get x.
    //  (25/16 * (2/5 * x^2 - 1)^2 - (25/16 - 1)) * (1/4 * x^2 - 1)^2
    //  |_______________________________________|   |_______________|
    //                   base                             window
    // The general form of the 'base' is,
    //  (a*(b*x^2-1)^2-(a-1))
    // Where 'a=1/(2*b-b^2)' and 'b' moves around the negative lobe.
    float wB=(2.0/5.0)*d2+(-1.0);
    float wA=lob*d2+(-1.0);
    wB*=wB;
    wA*=wA;
    wB=(25.0/16.0)*wB+(-(25.0/16.0-1.0));
    float w=wB*wA;
    // Do weighted average.
    aC+=c*w;aW+=w;
}

void FsrEasuF(
out vec3 pix,
vec2 coord, // Integer pixel position in output.
vec4 con0, // Constants generated by FsrEasuCon().
vec4 con1,
vec4 con2,
vec4 con3){
    vec2 ip = (coord * resolution);

    //pix = texture(colortex7, ip * texelSize).rgb;
    //return;

    //------------------------------------------------------------------------------------------------------------------------------
    // Get position of 'f'.
    vec2 pp = ip * con0.xy + con0.zw;
    vec2 fp = floor(pp);
    pp -= (fp);
    //------------------------------------------------------------------------------------------------------------------------------
    // 12-tap kernel.
    //    b c
    //  e f g h
    //  i j k l
    //    n o
    // Gather 4 ordering.
    //  a b
    //  r g
    // For packed FP16, need either {rg} or {ab} so using the following setup for gather in all versions,
    //    a b    <- unused (z)
    //    r g
    //  a b a b
    //  r g r g
    //    a b
    //    r g    <- unused (z)
    // Allowing dead-code removal to remove the 'z's.
    vec2 p0=fp*(con1.xy)+(con1.zw);
    // These are from p0 to avoid pulling two constants on pre-Navi hardware.
    vec2 p1=p0+(con2.xy);       
    vec2 p2=p0+(con2.zw);
    vec2 p3=p0+(con3.xy);
    vec4 bczzR=FsrEasuRF(p0);
    vec4 bczzG=FsrEasuGF(p0);
    vec4 bczzB=FsrEasuBF(p0);
    vec4 ijfeR=FsrEasuRF(p1);
    vec4 ijfeG=FsrEasuGF(p1);
    vec4 ijfeB=FsrEasuBF(p1);
    vec4 klhgR=FsrEasuRF(p2);
    vec4 klhgG=FsrEasuGF(p2);
    vec4 klhgB=FsrEasuBF(p2);
    vec4 zzonR=FsrEasuRF(p3);
    vec4 zzonG=FsrEasuGF(p3);
    vec4 zzonB=FsrEasuBF(p3);
    //------------------------------------------------------------------------------------------------------------------------------
    // Simplest multi-channel approximate luma possible (luma times 2, in 2 FMA/MAD).
    vec4 bczzL=bczzB*vec4(0.5)+(bczzR*vec4(0.5)+bczzG);
    vec4 ijfeL=ijfeB*vec4(0.5)+(ijfeR*vec4(0.5)+ijfeG);
    vec4 klhgL=klhgB*vec4(0.5)+(klhgR*vec4(0.5)+klhgG);
    vec4 zzonL=zzonB*vec4(0.5)+(zzonR*vec4(0.5)+zzonG);
    // Rename.
    float bL=bczzL.x;
    float cL=bczzL.y;
    float iL=ijfeL.x;
    float jL=ijfeL.y;
    float fL=ijfeL.z;
    float eL=ijfeL.w;
    float kL=klhgL.x;
    float lL=klhgL.y;
    float hL=klhgL.z;
    float gL=klhgL.w;
    float oL=zzonL.z;
    float nL=zzonL.w;
    // Accumulate for bilinear interpolation.
    vec2 dir=vec2(0.0);
    float len=(0.0);
    FsrEasuSetF(dir,len,pp,true, false,false,false,bL,eL,fL,gL,jL);
    FsrEasuSetF(dir,len,pp,false,true ,false,false,cL,fL,gL,hL,kL);
    FsrEasuSetF(dir,len,pp,false,false,true ,false,fL,iL,jL,kL,nL);
    FsrEasuSetF(dir,len,pp,false,false,false,true ,gL,jL,kL,lL,oL);
    //------------------------------------------------------------------------------------------------------------------------------
    // Normalize with approximation, and cleanup close to zero.
    vec2 dir2=dir*dir;
    float dirR=dir2.x+dir2.y;
    bool zro=dirR<(1.0/32768.0);
    dirR=(1.0 / dirR);
    dirR=zro?(1.0):dirR;
    dir.x=zro?(1.0):dir.x;
    dir*=(dirR);
    // Transform from {0 to 2} to {0 to 1} range, and shape with square.
    len=len*(0.5);
    len*=len;
    // Stretch kernel {1.0 vert|horz, to sqrt(2.0) on diagonal}.
    float stretch = (dir.x*dir.x+dir.y*dir.y) * (1.0 / max(abs(dir.x), abs(dir.y)));
    // Anisotropic length after rotation,
    //  x := 1.0 lerp to 'stretch' on edges
    //  y := 1.0 lerp to 2x on edges
    vec2 len2 = vec2((1.0) + (stretch - (1.0)) * len, 1.0 + -0.5 * len);
    // Based on the amount of 'edge',
    // the window shifts from +/-{sqrt(2.0) to slightly beyond 2.0}.
    float lob = (0.5)+((1.0/4.0-0.04)-0.5) * len;
    // Set distance^2 clipping point to the end of the adjustable window.
    float clp = 1.0 / lob;
    //------------------------------------------------------------------------------------------------------------------------------
    // Accumulation mixed with min/max of 4 nearest.
    //    b c
    //  e f g h
    //  i j k l
    //    n o
    vec3 min4=min(min(vec3(ijfeR.z,ijfeG.z,ijfeB.z), vec3(klhgR.w,klhgG.w,klhgB.w)),
                  min(vec3(ijfeR.y,ijfeG.y,ijfeB.y), vec3(klhgR.x,klhgG.x,klhgB.x)));
    vec3 max4=max(max(vec3(ijfeR.z,ijfeG.z,ijfeB.z), vec3(klhgR.w,klhgG.w,klhgB.w)), 
                  max(vec3(ijfeR.y,ijfeG.y,ijfeB.y), vec3(klhgR.x,klhgG.x,klhgB.x)));
    // Accumulation.
    vec3 aC=vec3(0.0);
    float aW=(0.0);
    FsrEasuTapF(aC,aW,vec2( 0.0,-1.0)-pp,dir,len2,lob,clp,vec3(bczzR.x,bczzG.x,bczzB.x)); // b
    FsrEasuTapF(aC,aW,vec2( 1.0,-1.0)-pp,dir,len2,lob,clp,vec3(bczzR.y,bczzG.y,bczzB.y)); // c
    FsrEasuTapF(aC,aW,vec2(-1.0, 1.0)-pp,dir,len2,lob,clp,vec3(ijfeR.x,ijfeG.x,ijfeB.x)); // i
    FsrEasuTapF(aC,aW,vec2( 0.0, 1.0)-pp,dir,len2,lob,clp,vec3(ijfeR.y,ijfeG.y,ijfeB.y)); // j
    FsrEasuTapF(aC,aW,vec2( 0.0, 0.0)-pp,dir,len2,lob,clp,vec3(ijfeR.z,ijfeG.z,ijfeB.z)); // f
    FsrEasuTapF(aC,aW,vec2(-1.0, 0.0)-pp,dir,len2,lob,clp,vec3(ijfeR.w,ijfeG.w,ijfeB.w)); // e
    FsrEasuTapF(aC,aW,vec2( 1.0, 1.0)-pp,dir,len2,lob,clp,vec3(klhgR.x,klhgG.x,klhgB.x)); // k
    FsrEasuTapF(aC,aW,vec2( 2.0, 1.0)-pp,dir,len2,lob,clp,vec3(klhgR.y,klhgG.y,klhgB.y)); // l
    FsrEasuTapF(aC,aW,vec2( 2.0, 0.0)-pp,dir,len2,lob,clp,vec3(klhgR.z,klhgG.z,klhgB.z)); // h
    FsrEasuTapF(aC,aW,vec2( 1.0, 0.0)-pp,dir,len2,lob,clp,vec3(klhgR.w,klhgG.w,klhgB.w)); // g
    FsrEasuTapF(aC,aW,vec2( 1.0, 2.0)-pp,dir,len2,lob,clp,vec3(zzonR.z,zzonG.z,zzonB.z)); // o
    FsrEasuTapF(aC,aW,vec2( 0.0, 2.0)-pp,dir,len2,lob,clp,vec3(zzonR.w,zzonG.w,zzonB.w)); // n
    //------------------------------------------------------------------------------------------------------------------------------
    // Normalize and dering.
    pix=min(max4,max(min4,aC*vec3(1.0 / aW)));
}