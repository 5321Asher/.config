.pragma library

// Positional astronomy for the live sky. Accurate to well under a degree for 1800-2050, which is
// plenty for a wallpaper: stars from the catalogue (J2000, precession ignored: ~0.35° by 2026),
// planets from JPL's Keplerian elements (E. M. Standish, "Approximate Positions of the Planets"),
// the Moon from Paul Schlyter's method with its largest perturbation terms.

const RAD = Math.PI / 180;
const DEG = 180 / Math.PI;
const OBLIQUITY = 23.43928 * RAD;

function norm360(x) { x %= 360; return x < 0 ? x + 360 : x; }

// Julian day from a JS Date
function julian(date) { return date.getTime() / 86400000 + 2440587.5; }

// Greenwich mean sidereal time, degrees
function gmst(jd) {
    const t = (jd - 2451545.0) / 36525;
    return norm360(280.46061837 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * t * t);
}

// Equatorial (RA, Dec in degrees) -> horizontal {alt, az} in degrees (az from north through east)
function horizontal(ra, dec, lat, lst) {
    const h = (lst - ra) * RAD, d = dec * RAD, p = lat * RAD;
    const sinAlt = Math.sin(d) * Math.sin(p) + Math.cos(d) * Math.cos(p) * Math.cos(h);
    const alt = Math.asin(Math.max(-1, Math.min(1, sinAlt)));
    const az = Math.atan2(-Math.cos(d) * Math.sin(h), Math.sin(d) * Math.cos(p) - Math.cos(d) * Math.sin(p) * Math.cos(h));
    return { alt: alt * DEG, az: norm360(az * DEG) };
}

// Ecliptic rectangular -> {ra, dec} degrees
function eclipticToEquatorial(x, y, z) {
    const ye = y * Math.cos(OBLIQUITY) - z * Math.sin(OBLIQUITY);
    const ze = y * Math.sin(OBLIQUITY) + z * Math.cos(OBLIQUITY);
    return { ra: norm360(Math.atan2(ye, x) * DEG), dec: Math.atan2(ze, Math.hypot(x, ye)) * DEG };
}
function eclipticLonLatToEquatorial(lon, lat) {
    const l = lon * RAD, b = lat * RAD;
    return eclipticToEquatorial(Math.cos(b) * Math.cos(l), Math.cos(b) * Math.sin(l), Math.sin(b));
}

// ------------------------------------------------------------------ planets
// a (au), e, I, L, long. perihelion, long. ascending node (deg) and their rates per Julian century
const ELEMENTS = {
    mercury: [0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593,
              0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081],
    venus:   [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255,
              0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418],
    earth:   [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0,
              0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0],
    mars:    [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891,
              0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343],
    jupiter: [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909,
              -0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106],
    saturn:  [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448,
              -0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794],
    uranus:  [19.18916464, 0.04725744, 0.77263783, 313.23810451, 170.95427630, 74.01692503,
              -0.00196176, -0.00004397, -0.00242939, 428.48202785, 0.40805281, 0.04240589],
    neptune: [30.06992276, 0.00859048, 1.77004347, -55.12002969, 44.96476227, 131.78422574,
              0.00026291, 0.00005105, 0.00035372, 218.45945325, -0.32241464, -0.00508664],
};

function kepler(M, e) {
    // M, E in radians
    let E = M + e * Math.sin(M);
    for (let i = 0; i < 8; i++) E -= (E - e * Math.sin(E) - M) / (1 - e * Math.cos(E));
    return E;
}

// Heliocentric ecliptic rectangular coordinates (au), J2000 ecliptic
function heliocentric(name, jd) {
    const k = ELEMENTS[name], t = (jd - 2451545.0) / 36525;
    const a = k[0] + k[6] * t, e = k[1] + k[7] * t, I = (k[2] + k[8] * t) * RAD;
    const L = k[3] + k[9] * t, peri = k[4] + k[10] * t, node = k[5] + k[11] * t;
    const w = (peri - node) * RAD, O = node * RAD;
    const M = norm360(L - peri) * RAD;
    const E = kepler(M > Math.PI ? M - 2 * Math.PI : M, e);
    const xp = a * (Math.cos(E) - e), yp = a * Math.sqrt(1 - e * e) * Math.sin(E);
    const cw = Math.cos(w), sw = Math.sin(w), cO = Math.cos(O), sO = Math.sin(O), cI = Math.cos(I), sI = Math.sin(I);
    return {
        x: (cw * cO - sw * sO * cI) * xp + (-sw * cO - cw * sO * cI) * yp,
        y: (cw * sO + sw * cO * cI) * xp + (-sw * sO + cw * cO * cI) * yp,
        z: (sw * sI) * xp + (cw * sI) * yp,
    };
}

// Geocentric {ra, dec, dist} of each planet and the Sun
function planets(jd) {
    const earth = heliocentric("earth", jd);
    const out = {};
    for (const name of ["mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"]) {
        const p = heliocentric(name, jd);
        const x = p.x - earth.x, y = p.y - earth.y, z = p.z - earth.z;
        out[name] = Object.assign(eclipticToEquatorial(x, y, z), { dist: Math.hypot(x, y, z) });
    }
    out.sun = Object.assign(eclipticToEquatorial(-earth.x, -earth.y, -earth.z), { dist: Math.hypot(earth.x, earth.y, earth.z) });
    return out;
}

// ------------------------------------------------------------------ moon
function moon(jd) {
    const d = jd - 2451543.5;
    const N = norm360(125.1228 - 0.0529538083 * d) * RAD;
    const i = 5.1454 * RAD;
    const w = norm360(318.0634 + 0.1643573223 * d) * RAD;
    const a = 60.2666, e = 0.054900;
    const M = norm360(115.3654 + 13.0649929509 * d);
    const Ms = norm360(356.0470 + 0.9856002585 * d);
    const ws = 282.9404 + 4.70935e-5 * d;
    const E = kepler(M * RAD, e);
    const xv = a * (Math.cos(E) - e), yv = a * Math.sqrt(1 - e * e) * Math.sin(E);
    const v = Math.atan2(yv, xv), r = Math.hypot(xv, yv);
    const xh = r * (Math.cos(N) * Math.cos(v + w) - Math.sin(N) * Math.sin(v + w) * Math.cos(i));
    const yh = r * (Math.sin(N) * Math.cos(v + w) + Math.cos(N) * Math.sin(v + w) * Math.cos(i));
    const zh = r * Math.sin(v + w) * Math.sin(i);
    let lon = Math.atan2(yh, xh) * DEG, lat = Math.atan2(zh, Math.hypot(xh, yh)) * DEG;

    // largest perturbations (degrees)
    const Ls = Ms + ws, Lm = N * DEG + w * DEG + M;
    const D = (Lm - Ls) * RAD, F = (Lm - N * DEG) * RAD, m = M * RAD, ms = Ms * RAD;
    lon += -1.274 * Math.sin(m - 2 * D) + 0.658 * Math.sin(2 * D) - 0.186 * Math.sin(ms)
         - 0.059 * Math.sin(2 * m - 2 * D) - 0.057 * Math.sin(m - 2 * D + ms) + 0.053 * Math.sin(m + 2 * D)
         + 0.046 * Math.sin(2 * D - ms) + 0.041 * Math.sin(m - ms) - 0.035 * Math.sin(D)
         - 0.031 * Math.sin(m + ms) - 0.015 * Math.sin(2 * F - 2 * D) + 0.011 * Math.sin(m - 4 * D);
    lat += -0.173 * Math.sin(F - 2 * D) - 0.055 * Math.sin(m - F - 2 * D) - 0.046 * Math.sin(m + F - 2 * D)
         + 0.033 * Math.sin(F + 2 * D) + 0.017 * Math.sin(2 * m + F);
    return Object.assign(eclipticLonLatToEquatorial(lon, lat), { lon: norm360(lon), lat: lat });
}

// Fraction of the Moon lit (0-1) from its elongation from the Sun, and whether it's waxing
function moonPhase(m, sun) {
    const a = m.ra * RAD, b = m.dec * RAD, c = sun.ra * RAD, d = sun.dec * RAD;
    const cosE = Math.sin(b) * Math.sin(d) + Math.cos(b) * Math.cos(d) * Math.cos(a - c);
    const fraction = (1 - cosE) / 2;
    const waxing = norm360(m.ra - sun.ra) < 180;
    return { fraction: fraction, waxing: waxing };
}

// ------------------------------------------------------------------ reference curves
// Points along the ecliptic, as [ra, dec]
function eclipticPoints(step) {
    const out = [];
    for (let l = 0; l <= 360; l += step) {
        const q = eclipticLonLatToEquatorial(l, 0);
        out.push([q.ra, q.dec]);
    }
    return out;
}

// Points along the galactic plane (the Milky Way's spine), as [ra, dec]
function galacticPoints(step) {
    // J2000 north galactic pole and the galactic centre direction
    const pole = { ra: 192.85948 * RAD, dec: 27.12825 * RAD };
    const lNcp = 122.93192 * RAD;
    const out = [];
    for (let l = 0; l <= 360; l += step) {
        const lr = l * RAD, b = 0;
        const sinDec = Math.sin(pole.dec) * Math.sin(b) + Math.cos(pole.dec) * Math.cos(b) * Math.cos(lNcp - lr);
        const dec = Math.asin(sinDec);
        const y = Math.cos(b) * Math.sin(lNcp - lr);
        const x = Math.cos(pole.dec) * Math.sin(b) - Math.sin(pole.dec) * Math.cos(b) * Math.cos(lNcp - lr);
        out.push([norm360((Math.atan2(y, x) + pole.ra) * DEG), dec * DEG]);
    }
    return out;
}

// B-V colour index -> an RGB star colour
function starColor(bv) {
    const t = Math.max(-0.4, Math.min(2.0, bv));
    let r, g, b;
    if (t < 0) { r = 0.68 + t * 0.2; g = 0.78 + t * 0.15; b = 1.0; }
    else if (t < 0.4) { r = 0.8 + t * 0.5; g = 0.85 + t * 0.3; b = 1.0 - t * 0.35; }
    else if (t < 1.0) { r = 1.0; g = 0.97 - (t - 0.4) * 0.35; b = 0.86 - (t - 0.4) * 0.8; }
    else { r = 1.0; g = 0.76 - (t - 1.0) * 0.3; b = 0.38 - (t - 1.0) * 0.25; }
    return [Math.round(r * 255), Math.round(g * 255), Math.round(Math.max(0, b) * 255)];
}
