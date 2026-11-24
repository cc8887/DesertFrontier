uniform float uSand = .59;
uniform float uWinter = 0.0;
uniform float uLight = .68;
uniform float uTravel = 1.5;
uniform float uAspect = 1.77778;
uniform float uRelief = .72;
const vec3 sunDir=vec3(-0.677007786,0.468005382,-0.568006532);
float drySun(){return uRelief*(1.-.44*uSand);}
float hash21(vec2 p){
 vec3 p3=fract(vec3(p.xyx)*.1031);p3+=dot(p3,p3.yzx+33.33);return fract((p3.x+p3.y)*p3.z);
}
float noise2(vec2 p){
 vec2 c=floor(p),f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(hash21(c),hash21(c+vec2(1.,0.)),f.x),mix(hash21(c+vec2(0.,1.)),hash21(c+vec2(1.)),f.x),f.y);
}
float veil(vec2 p,float y,float w,float v,float off){
 float a=p.x-uTravel*v;
 float mid=y + .035*sin(p.x*5.5+off) + .024*(noise2(vec2(a*3.4,off))-.5);
 float z=(p.y-mid)/w;
 float longFade=.24+.76*smoothstep(.23,.75,noise2(vec2(a*4.8+off,p.y*8.+off)));
 float texture=.53+.47*noise2(vec2(a*14.+off,(p.y-mid)*40.+off));
 return exp(-z*z)*longFade*texture;
}
vec3 air(vec2 p){
 vec3 pale=vec3(.978,.866,.631);vec3 warm=vec3(.875,.697,.439);
 vec3 airColor=mix(warm,pale,smoothstep(.05,.80,p.y));
 float soft=(noise2(vec2(p.x*3.4,p.y*5.1)+2.)-.5)*.10;
 return airColor+soft*vec3(1.,.83,.50);
}
float edge(vec2 p){
 return 1.-smoothstep(.49,.79,length((p-vec2(.52,.52))*vec2(.85,.87)))*.058;
}


// Cool diffuse light catches the full whiteout; its broken broad strokes
// deliberately have much less contrast than the paper pigment in the dunes.
vec3 snowAir(vec2 p) {
 vec3 ground=vec3(.638,.714,.754), upper=vec3(.810,.858,.872);
 float offset=(noise2(vec2(p.x*3.4,p.y*4.8)+2.)-.5)*.10;
 return mix(ground,upper,smoothstep(.025,.89,p.y))+offset*vec3(.79,.88,.95);
}
