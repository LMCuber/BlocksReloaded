#pragma language glsl3

uniform vec3 uLightPosView = vec3(0, 0, 0);
uniform vec3 uSpecularColor = vec3(1.0);
uniform float uShininess = 100.0;

in vec3 vNormalView;  // the normal vector of this fragment
in vec3 vPositionView; // we will need the view-space position to calculate the view vector

// a fragment in the middle of a triangle gets a normal that's a blend of its 3 corner normals, NOT a single flat face normal
// this gives the face smooth interpolated shading along the 3 vertices INSTEAD of 1 shade per face

vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords)
{
    // normalized surface normal
    vec3 N = normalize(vNormalView);
    // normalized vector from the vertex position -> light
    vec3 L = normalize(uLightPosView - vPositionView);
    // in view space, the camera is at (0 ,0, 0), so the direction to the camera is just -position
    vec3 V = normalize(-vPositionView);
    // the half vector for Blinn-Phong
    vec3 H = normalize(L + V);

    // diffuse term (Lambertian, so 180 uniform reflectance)
    float dotNL = max(dot(N, L), 0.0);
    vec3 diffuse = color.rgb * mix(0.2, 1, dotNL);  // makes sure no point is in COMPLETE darkness but minimum 0.2

    // specular term (Blinn-Phong), calculates whether the camera perfectly catches the reflected rays
    float dotNH = max(dot(N, H), 0.0);
    vec3 specular = uSpecularColor * pow(dotNH, uShininess) * dotNL;

    // combine them (plus a small ambient term so shadows aren't pitch black)
    vec3 ambient = color.rgb * 0.1;
    vec3 finalColor = diffuse + specular;

    // alpha stays the same
    return vec4(finalColor, color.a);
}