#pragma language glsl3

uniform vec3 uLightPosView = vec3(0, 0, 0);
uniform vec3 uSpecularColor = vec3(1.0);
uniform float uShininess = 32.0; // shininess exponent (higher = sharper)

in vec3 vNormalView;  // the normal vector of this fragment
in vec3 vPositionView; // we will need the view-space position to calculate the view vector

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    // normalized surface normal
    vec3 N = normalize(vNormalView);
    // normalized vector from the vertex position -> light
    vec3 L = normalize(uLightPosView - vPositionView);
    // in view space, the camera is at (0, 0, 0), so the direction to the camera is just -position
    // (Flipped back-to-front depending on your winding logic, but standard view space is -vPositionView)
    vec3 V = normalize(-vPositionView);
    // the half vector for Blinn-Phong
    vec3 H = normalize(L + V);

    // diffuse term (Lambertian, so 180 uniform reflectance)
    float dotNL = max(dot(N, L), 0.0);
    vec3 diffuse = color.rgb * mix(0.35, 1.0, dotNL);  // makes sure no point is in COMPLETE darkness

    // specular term (Blinn-Phong using the half-vector H)
    float dotNH = max(dot(N, H), 0.0);
    float specularIntensity = pow(dotNH, uShininess);
    
    // Only apply specular highlights if the surface is actually facing the light source
    vec3 specular = uSpecularColor * specularIntensity * (dotNL > 0.0 ? 1.0 : 0.0);

    // combine them
    vec3 finalColor = diffuse + specular;

    // alpha stays the same
    return vec4(finalColor, color.a);
}