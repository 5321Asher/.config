VARYING float vUp;
VARYING float vAlong;
void MAIN()
{
    vUp = VERTEX.y / 100.0;
    vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vAlong = w.x + w.z;
    POSITION = MODELVIEWPROJECTION_MATRIX * vec4(VERTEX, 1.0);
}
