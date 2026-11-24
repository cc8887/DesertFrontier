shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, fog_disabled;

varying float vRidge;
varying float vDepth;
varying vec3 vWorld;
varying vec3 vFace;

uniform vec3 uEarth = vec3(.765,.570,.354);
uniform float uPosts = 0.0;
uniform float uGrain = .63;
uniform float uBrush = .72;
uniform float uBrushSeed = 1.0;
uniform sampler2D uGrainMap : repeat_enable, filter_linear;
#include "res://shaders/desert_atmosphere.gdshaderinc"
void vertex() {
 vRidge=UV.y;
 vDepth=-(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).z;
 vWorld=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 vFace=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

vec4 winterTerrain(vec2 p){
 float seed=uBrushSeed;
 if(uPosts>=.5){
  float seen=exp(-(vDepth/370.)*(.34+.88*uSand));
  return vec4(mix(snowAir(p),vec3(.340,.380,.399),seen*.82),1.);
 }
 // Paint follows a curved stroke field in projection space, independent of
 // storm motion. Very broad broken cool wash over a restrained sandy base.
 float bend=p.y+.039*sin(p.x*6.2+seed)+.014*sin(p.x*12.2+seed*1.7);
 float broad=noise2(vec2(p.x*6.7+seed*5.1,bend*13.5+seed*3.2));
 float grain=noise2(vec2(p.x*17.0+seed*12.0,bend*32.+seed*12.1));
 float shale=noise2(vec2(p.x*13.8+seed,bend*22.0+11.7));
 vec3 n=normalize(vFace);
 if(n.y<0.)n=-n;
 float face=smoothstep(-.12,.72,dot(n,sunDir));
 float light=uRelief*(.45+.55*face);
 vec3 snow=mix(vec3(.613,.700,.759),vec3(.900,.914,.889),.28+light*.66);
 float foreground=1.-smoothstep(65.,175.,vDepth);
 float pigment=uBrush*(1.-smoothstep(95.,560.,vDepth)*.65);
 float stroke=smoothstep(.42,.75,broad)*(.56+.44*smoothstep(.38,.76,grain))*pigment;
 float wash=smoothstep(.38,.78,shale)*pigment*(1.-stroke*.75);
 snow=mix(snow,vec3(.942,.949,.919),stroke*mix(.68,.92,foreground));
 snow=mix(snow,vec3(.551,.641,.707),wash*mix(.34,.55,foreground));
 float scour=noise2(vec2(p.x*5.7+seed,bend*20.+seed*.93));
 float fields=smoothstep(.64,.85,scour)*smoothstep(.30,.88,vRidge);
 fields*=1.-smoothstep(84.,290.,vDepth)*.82;
 // Beige stone/sand only where wind has scoured snow on the near slopes.
 vec3 under=mix(vec3(.666,.606,.523),vec3(.781,.727,.618),light);
 vec3 cover=mix(snow,under,fields*.72);
 float gust=veil(p,.47,.15,.132,6.2)+.72*veil(p,.28,.10,.194,9.4);
 float trans=exp(-(vDepth/320.)*(.34+.94*uSand)-gust*uSand*.55);
 vec3 paint=mix(snowAir(p),cover,trans);
 float bristle=noise2(vec2(p.x*22.+seed*6.0,seed*7.2));
 float feather=mix(.021,.103,.63*broad+.37*bristle);
 float opacity=mix(1.,smoothstep(.001,feather,vRidge),uBrush*.82);
 return vec4(clamp(paint*edge(p),vec3(0.),vec3(1.)),opacity);
}
void fragment(){
 vec2 p=vec2(vWorld.x/uAspect,vWorld.y)/(2.0*vDepth*.393910476)+.5;
 if(uWinter>.5){
  vec4 snow=winterTerrain(p);
  ALBEDO=snow.rgb;
  ALPHA=snow.a;
 }else{
 vec3 haze=air(p);
 float phase1=veil(p,.545,.13,.057,2.2);
 float phase2=veil(p,.332,.118,.095,8.4);
 float phase3=veil(p,.205,.071,.145,5.7);
 float hazeDepth=(vDepth/265.0)*(.24+uSand*.92);
 float hazeBands=uSand*(phase1*.84+phase2*1.08+phase3*.50)*(.58+min(1.0,vDepth/185.0)*.62);
 float trans=exp(-hazeDepth-hazeBands);
 // The diffuse term is deliberately weak, never specular.
 float side=.52+.48*dot(normalize(vFace),normalize(vec3(-.42,.74,.52)));
 float body=mix(.86,1.075,smoothstep(.0,.83,vRidge));
 float sway=noise2(vec2(vWorld.x*.017,vWorld.z*.027));
 float groove=sin(169.0*p.y+14.0*p.x+6.0*noise2(vec2(4.0*p.x,6.0*p.y)));
 float micro=groove*.014*(1.0-smoothstep(60.0,270.0,vDepth));
 vec3 clay=uEarth*(body*(.86+.11*side+.12*sway)+micro);
 clay=mix(clay,uEarth*.77,uPosts*.65);
 float crestAlpha=1.0;
 if(uBrush>0.0&&uPosts<.5){
  // Static directional pigment marks, distinct from the wind-driven grain.
  float seed=uBrushSeed;
  float bend=p.y+.066*sin(5.4*p.x+seed)+.018*sin(12.6*p.x+2.0*seed);
  float bend2=bend+.014*(noise2(vec2(p.x*13.0+seed,p.y*8.0))-.5);
  vec2 block=vec2(p.x*6.2+.4*p.y,bend*17.3)+vec2(seed*9.7,seed*3.1);
  vec2 stroke=vec2(p.x*16.0+2.0*p.y,bend2*28.0)+vec2(seed*6.3,seed*9.13);
  float broad=noise2(block);
  float inner=noise2(stroke);
  float dry=smoothstep(.37,.75,broad)*(.42+.58*smoothstep(.24,.82,inner));
  float under=smoothstep(.28,.71,noise2(block*.79+vec2(19.4,6.7)))*(.34+.66*inner);
  float amount=uBrush*(1.0-smoothstep(134.0,560.0,vDepth)*.55);
  clay=mix(clay,clay*vec3(1.163,1.185,1.224)+vec3(.035,.023,.010),dry*amount*.84);
  clay=mix(clay,clay*vec3(.890,.870,.838),under*amount*.64);
  // Variable edge taper exposes the actual previously drawn background.
  float notch=noise2(vec2(p.x*14.2+seed*4.8,seed*17.0));
  float bristle=noise2(vec2(p.x*30.3+seed*12.3,seed*41.0));
  float feather=mix(.027,.146,.66*notch+.34*bristle);
  crestAlpha=mix(1.0,smoothstep(.001,feather,vRidge),smoothstep(0.0,.72,uBrush));
 }
 // Warm facing slope and cooler lee, applied BEFORE the depth-dependent haze.
 vec3 faceNormal=normalize(vFace);
 if(faceNormal.y<0.0)faceNormal=-faceNormal;
 float sunlit=dot(faceNormal,sunDir);
 float direct=smoothstep(.21,.72,sunlit);
 float lee=1.0-smoothstep(.07,.48,sunlit);
 float penumbra=smoothstep(.13,.74,phase2)*.21*uSand;
 float relief=drySun()*(1.0-uPosts)*(.68+.32*uLight);
 clay=mix(clay,clay*vec3(.60,.65,.79),lee*relief*.89);
 clay=mix(clay,clay*vec3(1.16,1.15,1.04)+vec3(.12,.078,.022),direct*relief*(1.0-penumbra));
 vec3 col=mix(haze,clay,trans);
 if(uGrain>0.0&&uPosts<.5){
  // Same animated periodic grains as compatibility mode, with true 3D depth attenuation here.
  float yt=1.0-p.y;
  float a=0.0;
  float u1=(yt-.655)/.198;
  float u2=(yt-.766)/.238;
  if(u1>0.0&&u1<1.0) a+=texture(uGrainMap,vec2((p.x-uTravel*.115)/.700,u1)).a*.59;
  if(u2>0.0&&u2<1.0) a+=texture(uGrainMap,vec2((p.x-uTravel*.178)/.920,u2)).a*.78;
  float depthFade=1.0-smoothstep(38.0,293.0,vDepth);
  col=mix(col,vec3(.510,.318,.196),clamp(a*uGrain*depthFade*trans*1.65,0.0,.64));
 }
 float paper=(hash21(floor(FRAGCOORD.xy))-.5)*.012;
 ALBEDO=clamp((col+paper)*edge(p),vec3(0.0),vec3(1.0));
 ALPHA=crestAlpha;
 }
}
