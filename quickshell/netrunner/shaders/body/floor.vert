VARYING vec2 vXz;
void MAIN()
{
    vXz = VERTEX.xy / 50.0;          // the built-in rectangle: -50..50
    POSITION = MODELVIEWPROJECTION_MATRIX * vec4(VERTEX, 1.0);
}
