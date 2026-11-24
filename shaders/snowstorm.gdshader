shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform float uPhase = 1.5;
uniform float uDensity = .59;
uniform float uSize = .63;
#include "res://shaders/desert_atmosphere.gdshaderinc"

// Three manually depth-tiered fields: few larger streaks in foreground,
// increasingly short and small pigment specks at distance. No background taps.
float drift(vec2 p, vec2 grid, float rate, float seed, float radius){
 vec2 travel=vec2(uPhase*rate,uPhase*rate*.25);
 vec2 g=(p-travel)*grid+seed;
 vec2 id=floor(g);
 vec2 xy=fract(g);
 vec2 center=vec2(hash21(id+11.41),hash21(id+57.13))*.60+vec2(.20);
 vec2 d=xy-center;
 d.y-=d.x*.24;
 float shape=1.-smoothstep(.40,1.,length(d/vec2(radius,.073)));
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
 float wash=(.072*flange+.060*low)*uDensity;
 float a=clamp(wash+flakes*(.29+.71*uDensity)*uSize,0.,.63);
 COLOR=vec4(.923,.951,.954,a);
}
