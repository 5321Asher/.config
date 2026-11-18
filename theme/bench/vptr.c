// vptr: drive a virtual pointer on $WAYLAND_DISPLAY (testing aid).
//   vptr W H  move X Y | rel DX DY | click [BTN] | down | up | wheel N | sleep MS ...
// W H = the layout's logical size (absolute moves are fractions of it). BTN 272 left, 273 right.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include "vp.h"
static struct zwlr_virtual_pointer_manager_v1 *mgr; static struct wl_seat *seat;
static void reg(void *d, struct wl_registry *r, uint32_t n, const char *i, uint32_t v) {
    if (!strcmp(i, "zwlr_virtual_pointer_manager_v1")) mgr = wl_registry_bind(r, n, &zwlr_virtual_pointer_manager_v1_interface, 1);
    else if (!strcmp(i, "wl_seat") && !seat) seat = wl_registry_bind(r, n, &wl_seat_interface, 1);
}
static void unreg(void *d, struct wl_registry *r, uint32_t n) {}
static const struct wl_registry_listener rl = { reg, unreg };
static uint32_t now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1000 + t.tv_nsec / 1000000; }
int main(int c, char **v) {
    if (c < 3) { fprintf(stderr, "usage\n"); return 2; }
    struct wl_display *dpy = wl_display_connect(NULL); if (!dpy) { fprintf(stderr, "no display\n"); return 1; }
    struct wl_registry *r = wl_display_get_registry(dpy); wl_registry_add_listener(r, &rl, NULL); wl_display_roundtrip(dpy);
    if (!mgr) { fprintf(stderr, "no virtual pointer manager\n"); return 1; }
    struct zwlr_virtual_pointer_v1 *p = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(mgr, seat);
    uint32_t W = atoi(v[1]), H = atoi(v[2]);
    for (int i = 3; i < c; i++) {
        if (!strcmp(v[i], "move") && i + 2 < c) { zwlr_virtual_pointer_v1_motion_absolute(p, now(), atoi(v[i+1]), atoi(v[i+2]), W, H); zwlr_virtual_pointer_v1_frame(p); i += 2; }
        else if (!strcmp(v[i], "rel") && i + 2 < c) { zwlr_virtual_pointer_v1_motion(p, now(), wl_fixed_from_double(atof(v[i+1])), wl_fixed_from_double(atof(v[i+2]))); zwlr_virtual_pointer_v1_frame(p); i += 2; }
        else if (!strcmp(v[i], "click")) { int b = 272; if (i + 1 < c && atoi(v[i+1]) > 0) b = atoi(v[++i]);
            zwlr_virtual_pointer_v1_button(p, now(), b, 1); zwlr_virtual_pointer_v1_frame(p); wl_display_roundtrip(dpy); usleep(30000);
            zwlr_virtual_pointer_v1_button(p, now(), b, 0); zwlr_virtual_pointer_v1_frame(p); }
        else if (!strcmp(v[i], "down")) { zwlr_virtual_pointer_v1_button(p, now(), 272, 1); zwlr_virtual_pointer_v1_frame(p); }
        else if (!strcmp(v[i], "up")) { zwlr_virtual_pointer_v1_button(p, now(), 272, 0); zwlr_virtual_pointer_v1_frame(p); }
        else if (!strcmp(v[i], "wheel") && i + 1 < c) { int n = atoi(v[++i]); zwlr_virtual_pointer_v1_axis_source(p, 0);
            zwlr_virtual_pointer_v1_axis_discrete(p, now(), 0, wl_fixed_from_int(15 * n), n); zwlr_virtual_pointer_v1_frame(p); }
        else if (!strcmp(v[i], "sleep") && i + 1 < c) { wl_display_roundtrip(dpy); usleep(atoi(v[++i]) * 1000); }
        wl_display_roundtrip(dpy);
    }
    usleep(50000); wl_display_roundtrip(dpy);
    zwlr_virtual_pointer_v1_destroy(p); wl_display_roundtrip(dpy); wl_display_disconnect(dpy);
    return 0;
}
