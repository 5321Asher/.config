import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../widgets"

// FAST TRAVEL ファストトラベル: the app launcher (SUPER + CTRL + Space) as the game's map. Every app is a
// building in a night city, seen in 3D from above: its district is its category (WATSON = development,
// HEYWOOD = network, JAPANTOWN = media…), its block never moves (the layout comes from the app list,
// not from use), and the more you run it the taller it stands. You start at the plaza in the middle.
// Typing searches: matching buildings light up in their district's colour, the rest go dark, and the
// camera glides to the best match while a GPS route draws itself along the streets to it. ↑ ↓ / Tab
// hop between destinations (the list on the left), Enter fast-travels: the camera dives into the
// building and the app starts (at once; the dive plays over it). Nothing matching: Enter runs what you
// typed as a command. Click a building or a row to pick it, double-click to travel, wheel to zoom.
// qs ipc call exec toggle | state
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    visible: ExecState.open || dive.running || outro.running

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "netrunner-exec"
    WlrLayershell.keyboardFocus: ExecState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: ExecState.open ? null : noInput
    Region { id: noInput }

    // ---------------------------------------------------------------- the apps, matching
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
    property string query: ""
    property int pick: 0
    property bool focused: false             // the camera follows the pick (else: the overview)
    property point pointer: Qt.point(-1, -1)
    property var launches: ({})
    property string randomId: ""             // a different destination picked at every open

    function match(a, q) {
        const name = a.name.toLowerCase();
        if (name.startsWith(q)) return 100 - name.length * 0.1;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80;
        if (q.length < 2) return 0;
        if (name.includes(q)) return 60;
        if (q.length < 3) return 0;
        const more = [a.genericName ?? "", (a.keywords ?? []).join(" "), a.comment ?? "", a.id ?? ""].join(" ").toLowerCase();
        return more.includes(q) ? 40 : 0;
    }
    function boost(a) { return Math.min(45, 9 * Math.log2(1 + (launches[a.id] ?? 0))); }
    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (q === "") {        // nothing typed: somewhere random, then the landmarks (the ones you run most)
            const lucky = apps.find(a => a.id === randomId) ?? null;
            return (lucky ? [lucky] : []).concat(apps.filter(a => a !== lucky)
                .sort((a, b) => boost(b) - boost(a) || a.name.localeCompare(b.name))).slice(0, 8);
        }
        return apps.map(a => ({ a: a, s: match(a, q) })).filter(m => m.s > 0)
            .map(m => Object.assign(m, { s: m.s + boost(m.a) }))
            .sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name)).slice(0, 8).map(m => m.a);
    }
    readonly property var matchIds: {
        const s = {};
        const q = query.trim().toLowerCase();
        if (q !== "") for (const a of apps) if (match(a, q) > 0) s[a.id] = true;
        return s;
    }
    readonly property bool searching: query.trim() !== ""
    readonly property var current: results[Math.min(pick, results.length - 1)] ?? null
    onQueryChanged: { pick = 0; if (searching) focused = true; }
    function exec(a) { return (a?.command ?? []).join(" ") || a?.execString || ""; }

    // ---------------------------------------------------------------- the city
    // Night City, roughly: the ocean down the west side, a bay cutting into Watson in the north-west,
    // City Center's towers in the middle (Arasaka's the tallest), Westbrook north-east, Heywood south,
    // Santo Domingo's low industry south-east, Pacifica and Dogtown on the southern coast, and the
    // Badlands desert all round the east and south. Blocks are on a grid (pitch 13: a 10 block and a 3
    // street), i west->east, j north->south, the plaza where you stand at 0,0.
    // Keep water() and the seeds in step with shaders/city/ground.frag, which draws the same map.
    readonly property real pitch: 13
    readonly property real blockSize: 10
    readonly property int half: 9
    readonly property var districts: [
        { id: "watson", name: "WATSON", jp: "ワトソン", sub: "development", seed: [-3.6, -5.0], w: 1.0, h: [4, 13], density: 0.85 },
        { id: "westbrook", name: "WESTBROOK", jp: "ウエストブルック", sub: "media // music // video", seed: [4.6, -4.2], w: 1.0, h: [5, 16], density: 0.8 },
        { id: "citycenter", name: "CITY CENTER", jp: "シティセンター", sub: "office // notes // ai", seed: [0.4, -0.6], w: 1.3, h: [14, 32], density: 0.95 },
        { id: "heywood", name: "HEYWOOD", jp: "ヘイウッド", sub: "web // comms", seed: [-2.6, 3.4], w: 1.0, h: [3, 10], density: 0.8 },
        { id: "santodomingo", name: "SANTO DOMINGO", jp: "サントドミンゴ", sub: "system // security", seed: [4.6, 4.2], w: 1.0, h: [2, 6], density: 0.75 },
        { id: "pacifica", name: "PACIFICA", jp: "パシフィカ", sub: "games", seed: [-5.0, 7.2], w: 1.1, h: [2, 8], density: 0.55 },
        { id: "dogtown", name: "DOGTOWN", jp: "ドッグタウン", sub: "graphics // design", seed: [-1.2, 7.8], w: 1.15, h: [3, 9], density: 0.85 },
        { id: "badlands", name: "BADLANDS", jp: "バッドランズ", sub: "everything else", seed: [8.2, 6.0], w: 1.0, h: [1, 2.5], density: 0.22 },
    ]
    function water(x, z) {
        const coast = -6.8 + 1.2 * Math.sin(z * 0.42 + 0.8) + (z > 3 ? (z - 3) * 0.25 : 0);
        if (x < coast) return true;                                    // the ocean
        if (z < -7.4 + 0.9 * Math.sin(x * 0.55 + 1.3)) return true;    // the north shore
        return Math.hypot(x + 3.2, z + 7.9) < 2.4;                     // the bay
    }
    function districtAt(i, j) {
        if (i > 7.0 || j > 8.6 || Math.hypot(i - 0.5, j) > 9.6) return 7;      // past the city: the desert
        let best = 0, bd = 1e9;
        for (let k = 0; k < 7; k++) {
            const sd = districts[k].seed, d = ((i - sd[0]) * (i - sd[0]) + (j - sd[1]) * (j - sd[1])) * districts[k].w;
            if (d < bd) { bd = d; best = k; }
        }
        return best;
    }
    // Which district an app lives in: games, then what the name (or a web app's address) says, then
    // the desktop categories, most telling first. Web apps (webapp.sh) all say Network/WebBrowser,
    // so their names decide (YouTube -> Westbrook, GitHub -> Watson, Claude -> City Center…).
    function districtIndex(a) {
        const cats = a.categories ?? [];
        const has = (...c) => c.some(x => cats.includes(x));
        const exec = ((a.command ?? []).join(" ") || a.execString || "").toLowerCase();
        const words = (a.name + " " + (a.genericName ?? "") + " " + (a.keywords ?? []).join(" ") + " " + (exec.includes("--app=") ? exec : "")).toLowerCase();
        const says = re => re.test(words);
        if (has("Game") || says(/\b(steam|lutris|heroic|minecraft|modrinth|retroarch)\b/)) return 5;
        if (says(/youtube|deezer|spotify|music|jellyfin|twitch|netflix|plex|tidal|soundcloud/)) return 1;
        if (says(/github|gitlab|codeberg|stackoverflow/) || has("Development", "IDE", "TextEditor", "Debugger")) return 0;
        if (says(/claude|chatgpt|gemini|notion|obsidian|notes|docs/) || has("Office", "Education", "Science", "Finance", "Spreadsheet", "WordProcessor", "Presentation", "Viewer") && !has("Graphics")) return 2;
        if (has("AudioVideo", "Audio", "Video", "Player", "Recorder", "Music", "Midi")) return 1;
        if (has("Graphics", "Photography", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics", "Publishing")) return 6;
        if (says(/\bnas\b|proxmox|router|portainer|tailscale|bitwarden|password|keys|vpn|firewall/) || has("System", "Settings", "Monitor", "TerminalEmulator", "FileManager", "HardwareSettings", "PackageManager", "Security", "Emulator")) return 4;
        if (has("Network", "WebBrowser", "Chat", "InstantMessaging", "Email", "FileTransfer", "P2P")) return 3;
        return 7;
    }
    // each district its own colour, turned round the colour wheel from the profile's red so the
    // neighbours differ: Watson orange, Westbrook neon pink, City Center cyan, Heywood green, Santo
    // Domingo blue, Pacifica violet, Dogtown red, the Badlands sand (as the circuit profile has them)
    readonly property var hues: [0.12, 0.88, 0.48, 0.3, 0.64, 0.76, 0.0]
    function districtColor(i) {
        const h0 = Theme.red.hslHue < 0 ? 0 : Theme.red.hslHue;
        return i === 7 ? Qt.hsla((h0 + 0.1) % 1, 0.3, 0.55, 1) : Qt.hsla((h0 + hues[i]) % 1, 0.85, 0.6, 1);
    }
    function hash(t) {
        let h = 2166136261;
        for (const c of t) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619) >>> 0; }
        return h;
    }

    // Where everything stands. Each app takes a block in its district near the district's heart,
    // chosen by a hash of its id (so a new app doesn't move the others); other land blocks get filler
    // towers by the district's density and height; City Center's tallest is Arasaka's.
    readonly property var city: {
        const blocks = [];
        for (let i = -half; i <= half; i++)
            for (let j = -half; j <= half; j++) {
                if (Math.abs(i) <= 1 && Math.abs(j) <= 1) continue;      // the plaza
                if (water(i, j) || water(i - 0.4, j) || water(i + 0.4, j) || water(i, j - 0.4) || water(i, j + 0.4)) continue;
                const h = hash(i + ":" + j), d = districtAt(i, j), sd = districts[d].seed;
                blocks.push({ i: i, j: j, x: i * pitch, z: j * pitch, r: Math.hypot(i, j), d: d, h: h, app: null, core: Math.hypot(i - sd[0], j - sd[1]) });
            }
        const byDistrict = districts.map(() => []);
        for (const a of apps) byDistrict[districtIndex(a)].push(a);
        byDistrict.forEach((list, k) => {
            if (!list.length) return;
            let own = blocks.filter(b => b.d === k).sort((p, q) => p.core - q.core || p.h - q.h);
            if (own.length < list.length)     // a crowded district spills into the desert
                own = own.concat(blocks.filter(b => b.d === 7 && !b.app).sort((p, q) => p.core - q.core).slice(0, list.length - own.length));
            const core = own.slice(0, Math.min(own.length, Math.max(list.length + 3, Math.round(list.length * 1.6))));
            for (const a of list.slice().sort((p, q) => p.id.localeCompare(q.id))) {
                let s = hash(a.id) % core.length;
                for (let n = 0; n < core.length && core[s].app; n++) s = (s + 1) % core.length;
                if (!core[s].app) { core[s].app = a; core[s].d = k; }
            }
        });
        const at = {};
        let tower = null;
        for (const b of blocks) {
            const g = b.h, ds = districts[b.d];
            const wide = b.d === 4 ? 1.25 : 1;                         // Santo Domingo's sheds are wide
            b.w = (6.2 + (g % 7) * 0.45) * wide;
            b.dp = (6.2 + ((g >> 3) % 7) * 0.45) * wide;
            const r = ((g >> 9) % 1000) / 1000;
            b.base = b.app ? ds.h[0] + (ds.h[1] - ds.h[0]) * 0.45 : ((g >> 6) % 100) / 100 < ds.density ? ds.h[0] + (ds.h[1] - ds.h[0]) * r * r : 0;
            if (b.app) at[b.app.id] = b;
            if (b.d === 2 && !b.app && b.base > 0 && (!tower || b.core < tower.core)) tower = b;
        }
        if (tower) { tower.base = 62; tower.arasaka = true; tower.w = 9; tower.dp = 9; }
        const labels = districts.map((dd, k) => ({ k: k, x: dd.seed[0] * pitch, z: dd.seed[1] * pitch }))
            .filter(l => blocks.some(b => b.d === l.k));
        return { blocks: blocks.filter(b => b.app || b.base > 0), at: at, labels: labels, extent: (half + 0.5) * pitch };
    }
    function heightOf(b) { return b.app ? b.base + 5 * Math.log2(1 + (launches[b.app.id] ?? 0)) : b.base; }
    readonly property var target: current ? city.at[current.id] ?? null : null
    function distance(b) { return b ? ((Math.abs(b.x) + Math.abs(b.z)) * 0.012).toFixed(1) + " KM" : ""; }

    // ---------------------------------------------------------------- travelling
    property bool uploading: false
    function run() {
        if (dive.running || (!current && !query.trim())) return;
        const a = current, cmd = query.trim();
        if (a) {
            const counts = Object.assign({}, launches);
            counts[a.id] = (counts[a.id] ?? 0) + 1;
            launches = counts;
            usage.setText(JSON.stringify(launches));
            a.execute();
        } else Quickshell.execDetached(["sh", "-c", cmd]);
        travelled = a ? a.name : cmd;
        dive.play();
        ExecState.open = false;              // the keyboard goes back now; the dive plays over the app starting
    }
    property string travelled: ""
    FileView {
        id: usage
        path: Quickshell.statePath("exec-launches.json")
        printErrors: false
        onLoaded: { try { root.launches = JSON.parse(text()); } catch (e) {} }
    }
    function close() { if (ExecState.open) { outro.play(); ExecState.open = false; } }
    // Esc: a search clears first, then the camera pulls back to the whole city, then it closes
    function back() {
        if (query !== "") { query = ""; focused = false; cam.zoom = 1; pick = 0; }
        else if (focused || cam.zoom !== 1) { focused = false; cam.zoom = 1; pick = 0; }
        else close();
    }

    Connections {
        target: ExecState
        function onOpenChanged() {
            if (ExecState.open) {
                dive.stop(); outro.stop();
                root.query = ""; root.pick = 0; root.focused = false; cam.zoom = 1;
                root.randomId = root.apps.length ? root.apps[Math.floor(Math.random() * root.apps.length)].id : "";
                root.pointer = Qt.point(-1, -1);
                field.focusField();
                title.replay();
                cam.dist = 640; cam.pitchDeg = 80; cam.yaw = 28; cam.x = 0; cam.z = 0;
                root.openedAt = Date.now(); root.firstFrame = -1;
                intro.play();
            } else if (!dive.running && !outro.running) outro.play();       // closed from outside
        }
    }

    // ---------------------------------------------------------------- the clocks
    Driver { id: intro; until: 800 }
    Driver { id: outro; until: 260 }
    Driver { id: dive; until: 460 }
    Driver { id: route; until: 520 }
    onTargetChanged: route.play()
    property real time: 0
    property int tick: 0                     // labels re-project each frame the camera moves
    property double openedAt: 0              // how long the first frame took after opening (tests)
    property int firstFrame: -1

    // the camera: glides (critically damped) towards where it should look
    QtObject {
        id: cam
        property real x: 0
        property real y: 0
        property real z: 0
        property real dist: 230
        property real pitchDeg: 56
        property real yaw: -28
        property real zoom: 1                // the wheel
        readonly property real tx: root.focused && root.target ? root.target.x : 0
        readonly property real tz: root.focused && root.target ? root.target.z : 14
        // a tall building: look at its middle and stand back far enough to see it, and its name, whole
        readonly property real th: root.focused && root.target ? root.heightOf(root.target) : 0
        readonly property real ty: th * 0.5
        readonly property real tdist: (root.focused && root.target ? Math.max(95, th * 2.6 + 40) : 370) * zoom
        readonly property real tyaw: root.focused ? 8 + Math.sin(root.time * 0.2) * 4 : Math.sin(root.time * 0.15) * 7
        readonly property real tpitch: root.focused && root.target ? 40 : 56
    }
    FrameAnimation {
        running: root.visible
        onTriggered: {
            const dt = Math.min(frameTime, 1 / 30);
            root.time += dt;
            const k = 1 - Math.exp(-dt * (intro.running ? 4.2 : 6.5));
            cam.x += (cam.tx - cam.x) * k;
            cam.z += (cam.tz - cam.z) * k;
            cam.y += (cam.ty - cam.y) * k;
            cam.dist += (cam.tdist - cam.dist) * k;
            cam.pitchDeg += (cam.tpitch - cam.pitchDeg) * k;
            cam.yaw += (cam.tyaw - cam.yaw) * k;
            root.tick++;
            if (root.firstFrame < 0 && root.openedAt) root.firstFrame = Date.now() - root.openedAt;
        }
    }
    // the dive (fast travel) and the pull-back (closing) take over the camera's distance and angle
    readonly property real diveT: dive.running ? Theme.inOut(Theme.seg(dive.ms, 0, 420)) : 0
    readonly property real camDist: dive.running ? cam.dist + (3 - cam.dist) * diveT : outro.running ? cam.dist * (1 + 0.5 * Theme.seg(outro.ms, 0, 260)) : cam.dist
    readonly property real camPitch: dive.running ? cam.pitchDeg + (6 - cam.pitchDeg) * diveT : cam.pitchDeg
    readonly property real rise: intro.running ? intro.ms : 1e9
    readonly property real hudAmt: intro.running ? 1 - Theme.out3(Theme.seg(intro.ms, 0, 300))
        : outro.running ? Theme.seg(outro.ms, 0, 220) : dive.running ? Theme.seg(dive.ms, 0, 200) : 0
    readonly property real fade: outro.running ? 1 - Theme.seg(outro.ms, 40, 260) : dive.running ? 1 - Theme.seg(dive.ms, 380, 460) : 1

    // ---------------------------------------------------------------- the 3D map
    Item {
        id: mapLayer
        anchors.fill: parent
        opacity: root.fade

        // The 3D view is built for each open and dropped on close: Qt Quick 3D 6.12 aborts
        // (QSSGGlobalRenderNodeData::reindex assertion) when a View3D's window is hidden and shown again.
        Loader {
            id: viewLoader
            anchors.fill: parent
            active: root.visible
            sourceComponent: viewComponent
        }
        readonly property var view: viewLoader.item
        Component {
            id: viewComponent
        View3D {
            id: view
            anchors.fill: parent
            camera: camera
            environment: ExtendedSceneEnvironment {
                backgroundMode: SceneEnvironment.Color
                clearColor: Theme.bgDark
                antialiasingMode: SceneEnvironment.MSAA
                antialiasingQuality: SceneEnvironment.Medium
                glowEnabled: true
                glowStrength: 1.1
                glowIntensity: 0.9
                glowBloom: 0.35
                glowHDRMinimumValue: 0.6
                glowBlendMode: ExtendedSceneEnvironment.GlowBlendMode.Additive
                glowLevel: ExtendedSceneEnvironment.GlowLevel.One | ExtendedSceneEnvironment.GlowLevel.Two | ExtendedSceneEnvironment.GlowLevel.Three
                vignetteEnabled: true
                vignetteStrength: 0.9
                vignetteRadius: 0.4
                vignetteColor: Theme.bgDark
            }

            Node {
                id: rig
                position: Qt.vector3d(cam.x, cam.y, cam.z)
                eulerRotation.y: cam.yaw
                PerspectiveCamera {
                    id: camera
                    position: Qt.vector3d(0, Math.sin(root.camPitch * Math.PI / 180) * root.camDist, Math.cos(root.camPitch * Math.PI / 180) * root.camDist)
                    eulerRotation.x: -root.camPitch
                    fieldOfView: 40
                    clipNear: 1
                    clipFar: 2500
                }
            }

            // the streets
            Model {
                source: "#Rectangle"
                eulerRotation.x: -90
                scale: Qt.vector3d(6.5, 6.5, 1)
                materials: CustomMaterial {
                    shadingMode: CustomMaterial.Unshaded
                    vertexShader: "../shaders/city/ground.vert"
                    fragmentShader: "../shaders/city/ground.frag"
                    property real grid: root.pitch
                    property real block: root.blockSize
                    property color c0: root.districtColor(0)
                    property color c1: root.districtColor(1)
                    property color c2: root.districtColor(2)
                    property color c3: root.districtColor(3)
                    property color c4: root.districtColor(4)
                    property color c5: root.districtColor(5)
                    property color c6: root.districtColor(6)
                    property color c7: root.districtColor(7)
                    property color sea: Theme.cyan
                    property color plazaColor: Theme.red
                    property color fogColor: Theme.bgDark
                    property real fogNear: 260
                    property real fogFar: 760
                    property real time: root.time
                }
            }

            // the buildings
            Repeater3D {
                model: root.city.blocks
                delegate: Model {
                    id: building
                    required property var modelData
                    readonly property var app: modelData.app
                    readonly property bool sel: app !== null && root.current?.id === app.id
                    readonly property bool hit: app !== null && (root.matchIds[app.id] ?? false)
                    readonly property real h: root.heightOf(modelData) * Theme.out3(Theme.seg(root.rise, modelData.r / root.half * 380, modelData.r / root.half * 380 + 420))
                    readonly property color dcol: root.districtColor(modelData.d)
                    source: "#Cube"
                    pickable: app !== null
                    position: Qt.vector3d(modelData.x, Math.max(0.01, h) / 2, modelData.z)
                    scale: Qt.vector3d(modelData.w / 100, Math.max(0.01, h) / 100, modelData.dp / 100)
                    materials: CustomMaterial {
                        shadingMode: CustomMaterial.Unshaded
                        vertexShader: "../shaders/city/building.vert"
                        fragmentShader: "../shaders/city/building.frag"
                        readonly property bool dimmed: root.searching && !building.hit
                        property color base: building.sel ? Qt.darker(building.dcol, 4) : Qt.tint(Qt.rgba(0.025, 0.03, 0.04, 1), Theme.alpha(building.dcol, 0.07))
                        property color edge: building.sel ? Qt.lighter(building.dcol, 1.35) : building.modelData.arasaka ? Theme.red
                            : dimmed ? Qt.darker(building.dcol, building.app ? 4 : 6)
                            : building.app ? building.dcol : Qt.darker(building.dcol, 1.7)
                        property color lights: dimmed ? Qt.rgba(0.25, 0.28, 0.32, 1) : building.modelData.arasaka ? Theme.red : Qt.lighter(building.dcol, 1.25)
                        property real glow: building.sel ? 1.2 : building.hit ? 0.8 : dimmed ? 0.0 : building.app ? 0.5 : building.modelData.arasaka ? 0.7 : 0.18
                        property real seed: building.modelData.h % 1000
                        property real time: root.time
                        property color fogColor: Theme.bgDark
                        property real fogNear: 260
                        property real fogFar: 760
                    }
                }
            }

            // the GPS route: plaza → the street beside the target's column → along it → into the block
            Repeater3D {
                model: 4
                delegate: Model {
                    id: seg
                    required property int index
                    readonly property var pts: {
                        const b = root.target;
                        if (!b) return null;
                        const P = root.pitch, si = b.i >= 0 ? 1 : -1, sj = b.j >= 0 ? 1 : -1;
                        const zs = sj * 0.5 * P, xs = (b.i - si * 0.5) * P;
                        const path = [[0, 0], [0, zs], [xs, zs], [xs, b.z], [b.x, b.z]];
                        return [path[index], path[index + 1]];
                    }
                    readonly property real len: pts ? Math.hypot(pts[1][0] - pts[0][0], pts[1][1] - pts[0][1]) : 0
                    // how much of this leg is drawn: the legs fill one after another as the route plays
                    readonly property real drawn: route.running ? Theme.seg(route.ms, index * 110, index * 110 + 160) : 1
                    visible: pts !== null && len > 0.01 && drawn > 0
                    source: "#Cube"
                    position: pts ? Qt.vector3d(pts[0][0] + (pts[1][0] - pts[0][0]) * drawn / 2, 0.2, pts[0][1] + (pts[1][1] - pts[0][1]) * drawn / 2) : Qt.vector3d(0, 0, 0)
                    scale: pts ? Qt.vector3d(Math.max(0.006, Math.abs(pts[1][0] - pts[0][0]) * drawn / 100 + 0.006),
                                             0.003,
                                             Math.max(0.006, Math.abs(pts[1][1] - pts[0][1]) * drawn / 100 + 0.006)) : Qt.vector3d(0, 0, 0)
                    materials: CustomMaterial {
                        shadingMode: CustomMaterial.Unshaded
                        sourceBlend: CustomMaterial.SrcAlpha
                        destinationBlend: CustomMaterial.One
                        vertexShader: "../shaders/city/glow.vert"
                        fragmentShader: "../shaders/city/glow.frag"
                        property color tint: Theme.yellow
                        property real strength: 1.6
                        property real beam: 0
                        property real time: root.time
                    }
                }
            }
            // the beacon over the destination
            Model {
                visible: root.target !== null
                source: "#Cylinder"
                position: root.target ? Qt.vector3d(root.target.x, 75 + root.heightOf(root.target) * 0.0, root.target.z) : Qt.vector3d(0, 0, 0)
                scale: Qt.vector3d(0.035, 1.5, 0.035)
                materials: CustomMaterial {
                    shadingMode: CustomMaterial.Unshaded
                    sourceBlend: CustomMaterial.SrcAlpha
                    destinationBlend: CustomMaterial.One
                    cullMode: Material.NoCulling
                    depthDrawMode: Material.NeverDepthDraw
                    vertexShader: "../shaders/city/glow.vert"
                    fragmentShader: "../shaders/city/glow.frag"
                    // the pillar of light over the destination, in its district's colour
                    property color tint: root.target ? Qt.lighter(root.districtColor(root.target.d), 1.15) : Theme.yellow
                    property real strength: 0.55 + 0.25 * Math.sin(root.time * 5)
                    property real beam: 1
                    property real time: root.time
                }
            }
        }

        }

        // ---------------------------------------------------------------- labels over the map
        // a point of the city on the screen (re-read every frame the camera moves)
        function screen(x, y, z) { root.tick; const v = mapLayer.view; return v && v.camera ? v.mapFrom3DScene(Qt.vector3d(x, y, z)) : Qt.vector3d(0, 0, -1); }

        // you are here
        Item {
            readonly property var p: mapLayer.screen(0, 0, 0)
            x: p.x; y: p.y
            visible: p.z > 0
            Rectangle { x: -7; y: -7; width: 14; height: 14; radius: 7; color: Theme.red }
            Rectangle {
                readonly property real k: (root.time * 0.8) % 1
                x: -width / 2; y: -height / 2
                width: 14 + k * 46; height: width; radius: width / 2
                color: "transparent"; border.width: 2; border.color: Theme.alpha(Theme.red, 1 - k)
            }
            Label { x: 14; y: -24; text: "YOU ARE HERE"; color: Theme.red; strong: true }
        }
        // district names on the ground, in the overview
        Repeater {
            model: root.city.labels
            Item {
                required property var modelData
                readonly property var p: mapLayer.screen(modelData.x, 0, modelData.z)
                x: p.x; y: p.y
                visible: p.z > 0
                opacity: Math.max(0, Math.min(1, (root.camDist - 160) / 60, (420 - root.camDist) / 80)) * 0.9     // the overview only
                Column {
                    x: -width / 2; y: -height / 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.districts[modelData.k].name
                        color: root.districtColor(modelData.k)
                        font.family: Theme.display; font.pixelSize: 22; font.weight: Font.Bold; font.letterSpacing: 4
                        style: Text.Outline; styleColor: Theme.bgDark
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.districts[modelData.k].jp + "  //  " + root.districts[modelData.k].sub.toUpperCase()
                        color: Theme.alpha(root.districtColor(modelData.k), 0.8)
                        font.family: Theme.mono; font.pixelSize: Theme.label; font.letterSpacing: Theme.tracking
                        style: Text.Outline; styleColor: Theme.bgDark
                    }
                }
            }
        }
        // the destinations' markers: numbered, the picked one with its name on a leader line
        Repeater {
            model: root.results
            Item {
                id: pin
                required property var modelData
                required property int index
                readonly property var b: root.city.at[modelData.id] ?? null
                readonly property bool sel: index === Math.min(root.pick, root.results.length - 1)
                readonly property var p: b ? mapLayer.screen(b.x, root.heightOf(b) + 1, b.z) : Qt.vector3d(0, 0, -1)
                x: p.x; y: p.y
                visible: b !== null && p.z > 0 && (root.searching || root.focused || pin.sel)
                Rectangle {
                    visible: pin.sel
                    x: -1; y: -leader.height
                    width: 2; height: leader.height
                    color: Theme.yellow
                }
                Item { id: leader; height: pin.sel ? 70 : 0 }
                Rectangle {
                    x: -10; y: -leader.height - 20
                    width: 20; height: 20
                    rotation: 45
                    color: pin.sel ? Theme.yellow : Theme.alpha(Theme.bgDark, 0.85)
                    border.width: 1; border.color: Theme.yellow
                }
                Text {
                    x: -width / 2; y: -leader.height - 20 + (20 - height) / 2
                    text: pin.index + 1
                    color: pin.sel ? Theme.bgDark : Theme.yellow
                    font.family: Theme.mono; font.pixelSize: 11; font.weight: Font.Bold
                }
                Column {
                    visible: pin.sel
                    x: 18; y: -leader.height - 30
                    Text {
                        text: pin.modelData.name.toUpperCase()
                        color: Theme.bright
                        font.family: Theme.display; font.pixelSize: 20; font.weight: Font.Bold; font.letterSpacing: 1
                        style: Text.Outline; styleColor: Theme.bgDark
                    }
                    Label {
                        text: root.districts[pin.b?.d ?? 0].name + "  //  " + root.distance(pin.b)
                        color: Theme.yellow
                        style: Text.Outline; styleColor: Theme.bgDark
                    }
                }
            }
        }

        // a click picks a building, a double-click travels; the wheel zooms
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: m => {
                if (!mapLayer.view) return;
                const r = mapLayer.view.pick(m.x, m.y);
                const a = r.objectHit?.app ?? null;
                if (!a) return;
                const i = root.results.findIndex(x => x.id === a.id);
                if (i >= 0) root.pick = i;
                else { root.query = a.name; root.pick = 0; field.text = a.name; }
                root.focused = true;
            }
            onDoubleClicked: m => { const r = mapLayer.view?.pick(m.x, m.y); if (r?.objectHit?.app) root.run(); }
            onWheel: w => cam.zoom = Math.max(0.35, Math.min(1.8, cam.zoom * (w.angleDelta.y > 0 ? 0.88 : 1.14)))
        }
    }

    // the white-out at the end of the dive
    Rectangle {
        anchors.fill: parent
        visible: dive.running
        color: Theme.bright
        opacity: Theme.seg(dive.ms, 300, 400) * (1 - Theme.seg(dive.ms, 400, 460))
    }

    // ---------------------------------------------------------------- the HUD
    Item {
        id: hud
        anchors.fill: parent
        anchors.margins: 36
        layer.enabled: root.hudAmt > 0.002
        layer.effect: ShaderEffect {
            fragmentShader: Qt.resolvedUrl("../shaders/glitch.frag.qsb")
            property vector2d size: Qt.vector2d(hud.width, hud.height)
            property real amount: root.hudAmt
            property real time: root.time
            property real seed: 0.71
            property color red: Theme.red
            property color cyan: Theme.cyan
        }

        Row {
            id: head
            spacing: 10
            Tag { anchors.verticalCenter: parent.verticalCenter; text: "FAST TRAVEL"; height: 26; pixelSize: Theme.label + 3 }
            Scramble {
                id: title
                anchors.verticalCenter: parent.verticalCenter
                target: "NIGHT CITY // " + root.apps.length + " LOCATIONS"
                color: Theme.bright; font.family: Theme.mono; font.pixelSize: Theme.label + 1; font.letterSpacing: Theme.tracking; font.weight: Font.DemiBold
            }
            Jp { anchors.verticalCenter: parent.verticalCenter; text: "ファストトラベル" }
        }

        // destinations: the search and the list
        Item {
            id: side
            y: 48
            width: Math.min(420, hud.width * 0.3)
            height: list.y + list.height

            Chamfer { anchors.fill: parent; cut: 14; corners: "tl br"; fill: Theme.alpha(Theme.bgDark, 0.86); stroke: Theme.alpha(Theme.yellow, 0.45) }
            Field {
                id: field
                x: 14; y: 14
                width: parent.width - 28
                height: 38
                accent: Theme.yellow
                text: root.query
                placeholder: "search destinations"
                input.font.pixelSize: 15
                onEdited: root.query = text
                onAccepted: root.run()
                input.Keys.onPressed: e => {
                    const n = root.results.length;
                    if (e.key === Qt.Key_Escape) root.back();
                    else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) { if (n) root.pick = (Math.min(root.pick, n - 1) + 1) % n; root.focused = true; }
                    else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { if (n) root.pick = (Math.min(root.pick, n - 1) - 1 + n) % n; root.focused = true; }
                    else return;
                    e.accepted = true;
                }
            }
            Label {
                id: listHead
                x: 16; y: field.y + field.height + 14
                text: root.searching ? (root.results.length ? "DESTINATIONS  //  " + Object.keys(root.matchIds).length + " FOUND" : "NO DESTINATION  //  ENTER RUNS IT AS A COMMAND")
                                     : "RANDOM PICK  +  LANDMARKS"
                color: root.searching && !root.results.length ? Theme.red : Theme.yellow
            }
            Column {
                id: list
                x: 8; y: listHead.y + listHead.height + 8
                width: parent.width - 16
                bottomPadding: 10
                Repeater {
                    model: root.results
                    Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool sel: index === Math.min(root.pick, root.results.length - 1)
                        readonly property var b: root.city.at[modelData.id] ?? null
                        width: list.width
                        height: 44
                        Rectangle {
                            anchors.fill: parent
                            color: row.sel ? Theme.alpha(Theme.yellow, 0.18) : "transparent"
                            Rectangle { visible: row.sel; width: 3; height: parent.height; color: Theme.yellow }
                        }
                        Text {
                            x: 12; anchors.verticalCenter: parent.verticalCenter
                            text: !root.searching && row.index === 0 ? "?" : row.index + 1
                            color: row.sel ? Theme.yellow : Theme.alpha(Theme.yellow, 0.5)
                            font.family: Theme.mono; font.pixelSize: Theme.label; font.weight: Font.Bold
                        }
                        IconImage {
                            x: 32; anchors.verticalCenter: parent.verticalCenter; implicitSize: 24
                            source: Quickshell.iconPath(row.modelData.icon || "application-x-executable", "application-x-executable")
                        }
                        Column {
                            x: 66; width: parent.width - x - 10
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                width: parent.width; elide: Text.ElideRight
                                text: row.modelData.name.toUpperCase()
                                color: row.sel ? Theme.bright : Theme.fg
                                font.family: Theme.condensed; font.pixelSize: 18; font.weight: Font.DemiBold; font.letterSpacing: 1
                            }
                            Row {
                                spacing: 6
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; color: root.districtColor(row.b?.d ?? 0) }
                                Label { text: root.districts[row.b?.d ?? 0].name + "  //  " + root.distance(row.b); color: row.sel ? Theme.yellow : Theme.dim }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onPositionChanged: m => {
                                const p = mapToGlobal(m.x, m.y);
                                if (root.pointer.x < 0) root.pointer = p;
                                else if (p.x !== root.pointer.x || p.y !== root.pointer.y) { root.pointer = p; root.pick = row.index; root.focused = true; }
                            }
                            onClicked: { root.pick = row.index; root.run(); }
                        }
                    }
                }
            }
        }

        // the destination
        Item {
            id: card
            anchors.right: parent.right
            anchors.bottom: foot.top; anchors.bottomMargin: 12
            width: Math.min(460, hud.width * 0.34)
            height: cardCol.implicitHeight + 36
            visible: root.current !== null || root.searching
            Chamfer { anchors.fill: parent; cut: 16; corners: "tr bl"; fill: Theme.alpha(Theme.bgDark, 0.9); stroke: Theme.alpha(Theme.yellow, 0.6) }
            Column {
                id: cardCol
                x: 18; y: 18
                width: parent.width - 36
                spacing: 8
                Row {
                    spacing: 10
                    Tag {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 20
                        text: root.target ? root.districts[root.target.d].name : "RAW COMMAND"
                        color: root.target ? root.districtColor(root.target.d) : Theme.red
                    }
                    Jp { anchors.verticalCenter: parent.verticalCenter; text: root.target ? root.districts[root.target.d].jp : "コマンド" }
                }
                Row {
                    spacing: 14
                    IconImage {
                        visible: root.current !== null
                        implicitSize: 52
                        source: Quickshell.iconPath(root.current?.icon || "application-x-executable", "application-x-executable")
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: cardCol.width - 70
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: (root.current?.name ?? root.query.trim()).toUpperCase()
                            color: Theme.bright
                            font.family: Theme.display; font.pixelSize: 26; font.weight: Font.Bold
                        }
                        Label { text: root.current ? (root.current.genericName || "program") : "nothing here by that name" }
                    }
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                    text: root.current ? (root.current.comment || "") : "Enter runs it as a shell command."
                    color: Theme.fg
                    font.family: Theme.sans; font.pixelSize: Theme.data + 1
                }
                Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.line, 0.9) }
                KV { width: parent.width; key: "EXEC"; value: root.current ? root.exec(root.current) : root.query.trim() }
                KV { width: parent.width; visible: root.current !== null; key: "VISITS"; value: String(root.current ? (root.launches[root.current.id] ?? 0) : 0) }
                KV { width: parent.width; visible: root.target !== null; key: "DISTANCE"; value: root.distance(root.target) }
                Row {
                    spacing: 10
                    topPadding: 6
                    Rectangle {
                        width: 34; height: 24
                        color: Theme.yellow
                        Text { anchors.centerIn: parent; text: "↵"; color: Theme.bgDark; font.family: Theme.mono; font.pixelSize: 14; font.weight: Font.Bold }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.current ? "FAST TRAVEL" : "RUN COMMAND"
                        color: Theme.yellow
                        font.family: Theme.display; font.pixelSize: 18; font.weight: Font.Bold; font.letterSpacing: 2
                    }
                }
            }
        }

        // the legend: the districts
        Column {
            anchors.left: parent.left
            anchors.bottom: foot.top; anchors.bottomMargin: 12
            spacing: 4
            Repeater {
                model: root.districts.map((d, i) => ({ d: d, i: i })).filter(x => root.city.labels.some(l => l.k === x.i))
                Row {
                    required property var modelData
                    spacing: 8
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; color: root.districtColor(modelData.i) }
                    Label { text: modelData.d.name + "  " + modelData.d.sub.toUpperCase(); color: Theme.alpha(root.districtColor(modelData.i), 0.9) }
                }
            }
        }

        Label {
            id: foot
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: "TYPE  SEARCH   //   ↑↓  DESTINATION   //   ↵  FAST TRAVEL   //   WHEEL  ZOOM   //   ESC  " + (root.focused || root.searching || cam.zoom !== 1 ? "BACK TO THE CITY" : "CLOSE")
        }
    }

    // FAST TRAVEL: the name of where you're going, over the dive
    Text {
        anchors.centerIn: parent
        visible: dive.running
        opacity: Theme.seg(dive.ms, 60, 160) * (1 - Theme.seg(dive.ms, 330, 420))
        text: "FAST TRAVEL  //  " + root.travelled.toUpperCase()
        color: Theme.yellow
        font.family: Theme.display; font.pixelSize: 34; font.weight: Font.Bold; font.letterSpacing: 4
        style: Text.Outline; styleColor: Theme.bgDark
    }

    Binding {
        target: ExecState; property: "report"
        value: root.districts.map((d, k) => d.name + " (" + root.apps.filter(a => root.city.at[a.id]?.d === k).length + "): "
            + root.apps.filter(a => root.city.at[a.id]?.d === k).map(a => a.name).join(", ")).join("\n")
    }
    // for tests: qs ipc call exec state
    Binding {
        target: ExecState; property: "status"
        value: `open=${ExecState.open} visible=${root.visible} apps=${root.apps.length} query=${root.query} results=${root.results.length} pick=${root.current?.id ?? ""} focused=${root.focused} buildings=${root.city.blocks.length} firstFrameMs=${root.firstFrame} random=${root.randomId}`
    }
}
