shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec4 uSun = vec4(.281,.835,.033,.006);
uniform float uSky = .72;
#include "res://shaders/desert_atmosphere.gdshaderinc"
float skyWash(vec2 p,float altitude,float thickness,float slant,float speed,float seed){
 // Transport the broken pigment pattern along the slope. Its height envelope
 // stays in frame; the two independently translated patterns never pulse in place.
 float a=p.x-uTravel*speed;
 float localY=p.y-(altitude+slant*(p.x-.5)+.012*sin(p.x*7.0+seed));
 float y=localY/thickness;
 float broad=noise2(vec2(a*5.4+seed,localY*18.0+seed*1.4));
 float inlet=noise2(vec2(a*3.7-seed,1.9+seed));
 float bristle=noise2(vec2(a*11.0+seed*.63,localY*43.0+seed));
 return exp(-y*y)*smoothstep(.27,.74,broad*.83+.17*bristle)*
        (.52+.48*smoothstep(.18,.68,inlet));
}
vec3 winterSky(vec2 p){
 vec3 paint=snowAir(p);
 float layerA=skyWash(p,.83,.16,.18,.20,4.81);
 float layerB=skyWash(p,.68,.135,.23,.30,11.68);
 float layerC=skyWash(p,.46,.12,.16,.255,18.83);
 float gust=uSky*(.30+.70*uSand);
 paint=mix(paint,vec3(.651,.736,.782),layerA*gust*.56);
 paint=mix(paint,vec3(.932,.949,.933),layerB*gust*.71);
 paint=mix(paint,vec3(.811,.867,.900),layerC*gust*.62);
 vec2 delta=(p-uSun.xy)*vec2(uAspect,1.0);
 float disc=1.-smoothstep(.019,.044,length(delta));
 float tau=exp(-uSand*(.80+layerA*.88+layerB*.71));
 return mix(paint,vec3(.966,.954,.909),disc*uLight*tau*.73);
}
void fragment(){
 vec2 p=vec2(UV.x,1.0-UV.y);
 if(uWinter>.5){
  ALBEDO=clamp(winterSky(p)*edge(p),vec3(0.),vec3(1.));
 }else{
 vec3 haze=air(p);
 vec3 amber=vec3(.933,.785,.517),cream=vec3(.986,.895,.678);
 float cloud=noise2(vec2(p.x*4.1+p.y*1.1,p.y*7.2));
 float wisp=noise2(vec2(p.x*10.4-uTravel*.13,p.y*19.7+4.3));
 float cover=veil(p,.64,.145,.038,8.0);
 vec3 col=mix(mix(amber,cream,smoothstep(.15,.81,cloud)*.75),haze,.39+cover*.43*uSand);
 col=mix(col,cream,smoothstep(.13,.61,cover)*.19);
 vec2 ds=(p-uSun.xy)*vec2(uAspect,1.0);
 float dist=length(ds);
 float disc=1.0-smoothstep(uSun.z-uSun.w,uSun.z+uSun.w,dist);
 float tau=exp(-uSand*(.62+1.05*cover)-.06*wisp);
 if(uSky>0.0){
  float thin=skyWash(p,.896,.078,.155,.140,4.81);
  float trail=skyWash(p,.775,.065,.245,.220,11.68);
  float strength=uSky*(.56+.44*uSand);
  // A warm pigment wash and a lighter torn edge, no additive light.
  col=mix(col,vec3(.887,.701,.455),clamp(strength*thin*.53,0.0,.61));
  col=mix(col,vec3(.969,.847,.596),clamp(strength*trail*.53,0.0,.55));
  tau*=exp(-uSky*(thin*.17+trail*.25));
 }
 float moment=(.92+.08*sin(uTravel*.51+1.5));
 // Deliberately display-range warm white, with no emissive pass, glow or halo.
 col=mix(col,vec3(.968,.968,.923),disc*uLight*tau*moment);
 float paper=(hash21(floor(FRAGCOORD.xy))-.5)*.012;
 ALBEDO=clamp((col+paper)*edge(p), vec3(0.0), vec3(1.0));
 }
}
