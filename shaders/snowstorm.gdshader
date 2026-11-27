shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform float uPhase = 1.5;
uniform float uDensity = .59;
uniform float uSize = .63;
uniform float uGust = 0.0;
uniform bool uIsSnow = true;
#include "res://shaders/desert_atmosphere.gdshaderinc"

// Three manually depth-tiered fields: few larger streaks in foreground,
// increasingly short and small pigment specks at distance. No background taps.
float drift(vec2 p, vec2 grid, float rate, float seed, float radius){
 float dir = uGust > .002 ? -1.0 : 1.0;
 vec2 travel=vec2(uPhase*rate*dir,uPhase*rate*.25*dir);
 vec2 g=(p-travel)*grid+seed;
 vec2 id=floor(g);
 vec2 xy=fract(g);
 vec2 center=vec2(hash21(id+11.41),hash21(id+57.13))*.60+vec2(.20);
 vec2 d=xy-center;
 d.y-=d.x*.24;
 float shape=1.-smoothstep(.40,1.,length(d/vec2(radius*(1.+.92*uGust),.073)));
 float exist=smoothstep(.33,.65,hash21(id+94.2));
 float ribbon=.21+.79*smoothstep(.17,.84,noise2(p*vec2(4.0,6.3)+vec2(-uPhase*.35,seed)));
 return shape*exist*ribbon;
}
void fragment(){
 vec2 p=vec2(UV.x*uAspect,UV.y);
 float billow=noise2(vec2((p.x-uPhase*.20)*4.0,p.y*7.6+3.8));
 float sheet=(p.y-(.50+.09*sin((p.x-uPhase*.08)*4.3)))/.16;
 float flange=exp(-sheet*sheet);
 float low=smoothstep(.60,.97,p.y)*smoothstep(.25,.83,billow);
 float flakes=drift(p,vec2(70.,75.),.19,17.13,.12)*.35;
 flakes+=drift(p,vec2(44.,51.),.31,36.74,.18)*.48;
 flakes+=drift(p,vec2(25.,39.),.48,81.9,.23)*.67;
 // Torn, broad strokes move with the snow flecks, not a uniform haze.
 float stream=0.0;
 float sweeping=0.0;
 float lifts=smoothstep(.07,.55,p.y);
 if (uGust > .002) {
  vec2 sheared=vec2(p.x+uPhase*.39,p.y-p.x*.155);
  float frayed=pow(smoothstep(.35,.80,noise2(sheared*vec2(5.1,20.)+7.)),1.6);
  stream=pow(smoothstep(.40,.78,noise2(sheared*vec2(8.6,38.)+17.)),2.0);
  sweeping=(.10*frayed+.048*stream)*uGust*lifts;
 }
 float wash=(.072*flange+.060*low)*uDensity;
 if (uIsSnow) {
  float a=clamp(wash+sweeping+flakes*(.29+.71*uDensity)*uSize*(1.+.68*uGust),0.,.67);
  COLOR=vec4(.923,.951,.954,a);
 } else {
  float a=clamp(sweeping*2.10+flakes*.095*uGust*lifts,0.,.25);
  vec3 pigment=mix(vec3(.965,.857,.643),vec3(.631,.421,.247),stream*.70);
  COLOR=vec4(pigment,a);
 }
}
