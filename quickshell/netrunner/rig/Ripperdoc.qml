import QtQuick
import QtQuick.Shapes
import QtQuick3D
import QtQuick3D.Helpers
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"
import "pages"
import "../launcher"
import "../utilities"
import "../dash"
import "pose.js" as Pose

// RIPPERDOC リッパードク: the rig (Netrunner's control panel) as the game's cyberware screen. A human body
// (rig/body.json: MakeHuman's CC0 mesh and skeleton, setups/netrunner/body.py) stands in the middle in
// translucent red (shaders/body/holo.frag), its circulatory system lit up inside it: every beat of
// the heart (faster with the CPU's load) sends a wave out along every vessel to the fingertips
// (shaders/body/vessels.frag). A ticked ring behind it, a yellow one at its feet. It strikes a pose
// for each implant (rig/poses.json, setups/netrunner/poses.py: a hand to the temple for the cortex,
// over the heart for the circulatory system, a fighting stance for the skeleton…), blending over. Every page of the rig is one of the game's
// cyberware categories (RigState.pages: FRONTAL CORTEX = claude … LEGS = chrono), a row either side:
// its name and state, the implant in a square slot with its rarity on a bar, its everyday switches and
// readouts one click each (tilesOf), empty "+" sockets, a red cable to where it sits on the body.
// The top bar is the game's (LEVEL, STREET CRED, the tabs to the other screens, weight, eddies).
// It opens on the whole body, nothing selected (a page asked for when opening is only lit up).
// Selecting an implant (click it, or ↑ ↓ ← → and Enter, 1–9 0 -) zooms the camera onto that part of
// the body and unfolds its page on the right; Tab / Shift+Tab step to the next implant (the camera
// glides, the page's content changes over); Esc goes back to the whole body, then closes.
// qs ipc call deck toggle | open <page> | close | state
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    visible: RigState.open || outro.running

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "netrunner-rig"
    WlrLayershell.keyboardFocus: RigState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: RigState.open ? null : noInput
    Region { id: noInput }

    readonly property bool paged: RigState.current !== null
    // with a page open, the body and its categories move into the room left of the panel
    readonly property real pageCx: Math.max(root.width * 0.3, (root.width - Math.min(680, root.width * 0.44) - 40) / 2 + 10)
    property string hoverId: ""              // the slot picked in the overview (pointer or keys)
    readonly property var focusSlot: paged ? RigState.current : (RigState.pages.find(p => p.id === hoverId) ?? null)
    // the keys' order: down the left column, then down the right
    readonly property var order: RigState.pages.filter(p => p.side === 0).sort((a, b) => b.anchor[1] - a.anchor[1])
        .concat(RigState.pages.filter(p => p.side === 1).sort((a, b) => b.anchor[1] - a.anchor[1]))

    function openPage(id) { RigState.page = id; }
    // Esc: a selected implant goes back to the whole body, then the rig closes
    function back() {
        if (paged) { RigState.page = ""; return; }
        close();
    }
    function close() { if (RigState.open) { outro.play(); RigState.open = false; } }

    // ---------------------------------------------------------------- the top bar's numbers and tabs
    property int uptimeHours: 0
    property string eddies: "--"
    readonly property string memUsed: (SysInfo.mem * root.memTotalGb).toFixed(0)
    readonly property string memTotal: root.memTotalGb.toFixed(0)
    property real memTotalGb: 16
    Process {
        id: facts
        command: ["sh", "-c", "cut -d. -f1 /proc/uptime; df -m --output=avail / | tail -1; awk '/MemTotal/ {print $2}' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split(/\s+/);
                root.uptimeHours = Math.floor((+l[0] || 0) / 3600);
                root.eddies = (+l[1] || 0).toLocaleString(Qt.locale("en_US"), "f", 0);
                root.memTotalGb = (+l[2] || 16777216) / 1048576;
            }
        }
    }
    readonly property var tabsList: [
        { id: "journal", name: "JOURNAL", g: "\u{f0219}", go: () => DeckState.toggle() },
        { id: "shards", name: "BRAINDANCE", g: "\u{f0147}", go: () => ClipboardState.open = true },
        { id: "cyberware", name: "CYBERWARE", g: "◆", go: null },
        { id: "map", name: "MAP", g: "\u{f034d}", go: () => ExecState.open = true },
        { id: "net", name: "SUBNET", g: "\u{f0570}", go: () => OverviewState.open = true },
    ]
    function goTab(i) {
        const t = tabsList[(i + tabsList.length) % tabsList.length];
        if (t.go) later(t.go);
    }

    // ---------------------------------------------------------------- live state for the cards
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink].filter(n => n) }
    function statusOf(id) {
        switch (id) {
        case "claude": {
            const l = (ClaudeStatus.data?.limits ?? [])[0];
            return l ? (l.label + " " + Math.round(l.percent ?? 0) + "%") : ClaudeStatus.data ? ClaudeStatus.prettyModel(ClaudeStatus.data.model?.lastUsed ?? "") || "linked" : "no link";
        }
        case "optics": return Brightness.displays.length + (Brightness.displays.length === 1 ? " screen" : " screens");
        case "radio": return root.sink ? "vol " + Math.round((root.sink.audio?.volume ?? 0) * 100) + "%" + (root.sink.audio?.muted ? " // muted" : "") : "no output";
        case "log": return Notifs.history.length + " messages" + (Notifs.dnd ? " // dnd" : "");
        case "helm": return "idle " + (StayAwake.on ? "hold" : "auto");
        case "telemetry": return "cpu " + Math.round(SysInfo.cpu * 100) + "% // mem " + Math.round(SysInfo.mem * 100) + "%";
        case "comms": return !Net.wifiEnabled ? "radio off" : (Net.ssid || "not connected");
        case "chronometer": return FocusTimer.active ? FocusTimer.phaseLabel + " " + FocusTimer.remainingText : "idle";
        case "almanac": return Weather.ready ? Math.round(Weather.current.temp) + "° " + Weather.describe(Weather.current.code) : "no forecast";
        case "lamps": return !Rgb.available ? "no rgb" : Rgb.followWallpaper ? "follows profile" : "manual";
        case "hangar": return Devices.drives.length ? Devices.drives.length + " drives" : "scanning";
        }
        return "";
    }
    function alertOf(id) {             // a red dot on the card: something needs a look
        switch (id) {
        case "comms": return !Net.wifiEnabled || !Net.ssid;
        case "telemetry": return SysInfo.cpu > 0.9 || SysInfo.mem > 0.9;
        case "log": return Notifs.unread > 0;
        }
        return false;
    }

    // ---------------------------------------------------------------- the clocks
    Driver { id: intro; until: 1300 }
    Driver { id: outro; until: 300 }
    Driver { id: swapFx; until: 380 }
    property real pageK: 0                   // 0 = the whole body, 1 = an implant open: eased, never jumps
    property real time: 0
    property int tick: 0
    property real flicker: 1
    Connections {
        target: RigState
        function onOpenChanged() {
            if (RigState.open) {
                outro.stop();
                root.hoverId = RigState.highlight;
                RigState.highlight = "";
                root.pageK = 0;
                cam.dist = 7.5;
                root.strike(RigState.page, true);
                intro.play();
                keys.forceActiveFocus();
                Net.refresh();
                facts.running = true;
                if (!Brightness.scanned) Brightness.scan();
                if (!Rgb.scanned) Rgb.scan();
            } else if (!outro.running) outro.play();
        }
        // another implant: only the page's content changes over (the panel and the body glide)
        function onPageChanged() {
            if (!RigState.open) return;
            if (RigState.page !== "") swapFx.play();
            root.strike(RigState.page, false);
        }
    }
    property bool direct: false              // opened straight into a page: the body builds faster

    // ---------------------------------------------------------------- the pose
    // The body strikes a pose for each implant (RigState.posePages), blending over from wherever it
    // is (the trunk leads, the hands follow on), and breathes on top of it. Its bones are flat Nodes in
    // the 3D view (jointNodes), placed from here every frame: the body and its vessels are skinned to them.
    QtObject {
        id: pose
        property var from: null              // each bone's local turn where the blend began
        property var fromHips: [0, 0, 0]
        property var to: null                // and the pose it's going to
        property var toHips: [0, 0, 0]
        property real t: 1
        property var cur: null               // the blend now
        property var curHips: [0, 0, 0]
        property var now: null               // its bones' places now, breathing included
        property var target: null            // and once the pose is struck
        property var lag: []                 // each bone's delay into a blend (deeper bones later)
        property var named: ({})             // bone name -> index
        property string name: ""
    }
    property var jointNodes: []
    readonly property real blendTime: 1.15
    function strike(id, instant) {
        const bones = RigState.bones;
        const P = RigState.poses[RigState.posePages[id] ?? "stand"] ?? RigState.poses.stand;
        if (!P || !bones.length) return;
        if (!pose.lag.length) {
            const depth = [], named = {};
            bones.forEach((b, i) => { depth[i] = b.parent < 0 ? 0 : depth[b.parent] + 1; named[b.name] = i; });
            pose.lag = depth.map(d => Math.min(d, 10) * 0.02);
            pose.named = named;
        }
        const to = Pose.locals(P, bones.length);
        pose.target = Pose.solve(bones, to, P.hips);
        if (instant || !pose.cur) {
            pose.cur = to;
            pose.curHips = P.hips;
            pose.t = 1;
        } else {
            pose.from = pose.cur;
            pose.fromHips = pose.curHips;
            pose.t = 0;
        }
        pose.to = to;
        pose.toHips = P.hips;
        pose.name = RigState.posePages[id] ?? "stand";
        stepPose(0);
    }
    function stepPose(dt) {
        const bones = RigState.bones, n = bones.length;
        if (!pose.cur || !n) return;
        if (pose.t < 1) {
            pose.t = Math.min(1, pose.t + dt / root.blendTime);
            const cur = new Array(n);
            for (let i = 0; i < n; i++)
                cur[i] = Pose.slerp(pose.from[i], pose.to[i], Theme.inOut(Math.max(0, Math.min(1, (pose.t - pose.lag[i]) / 0.8))));
            const e = Theme.inOut(pose.t);
            pose.cur = cur;
            pose.curHips = [0, 1, 2].map(k => pose.fromHips[k] + (pose.toHips[k] - pose.fromHips[k]) * e);
        }
        // breathing (the chest and shoulders rising) and the head drifting, on top of the pose
        const b = Math.sin(root.time * 1.3), live = pose.cur.slice(), at = pose.named;
        const add = (name, q) => { const i = at[name]; if (i !== undefined) live[i] = Pose.mul(live[i], q); };
        add("spine02", Pose.axis(1, 0, 0, -1.4 * b));
        add("spine01", Pose.axis(1, 0, 0, -0.8 * b));
        add("neck01", Pose.axis(1, 0, 0, 1.6 * b));
        add("clavicle.L", Pose.axis(0, 0, 1, 1.2 * b));
        add("clavicle.R", Pose.axis(0, 0, 1, -1.2 * b));
        add("head", Pose.mul(Pose.axis(0, 1, 0, Math.sin(root.time * 0.31) * 2.5), Pose.axis(1, 0, 0, Math.sin(root.time * 0.23) * 1.2)));
        const fk = Pose.solve(bones, live, pose.curHips);
        pose.now = fk;
        const nodes = root.jointNodes;
        for (let i = 0; i < nodes.length; i++) {
            const g = fk.G[i], p = fk.P[i];
            nodes[i].position = Qt.vector3d(p[0], p[1], p[2]);
            nodes[i].rotation = Qt.quaternion(g[0], g[1], g[2], g[3]);
        }
    }
    // where an implant sits on the body now, and where it will once the pose is struck
    function anchorNow(p) {
        root.tick;
        const sk = RigState.anchorSkin[p.id];
        return pose.now && sk ? Pose.place(pose.now, RigState.bones, p.anchor, sk) : p.anchor;
    }
    function anchorTo(p) {
        const sk = RigState.anchorSkin[p.id];
        return pose.target && sk ? Pose.place(pose.target, RigState.bones, p.anchor, sk) : p.anchor;
    }
    // the heart: its rate eased (so the waves don't jump), its beats counted
    property real heartRate: 1
    property real beats: 0
    property real surge: 0                   // the circulatory implant selected: the blood runs hot
    // the blood filling the vessels from the heart on opening, draining on closing (0..1)
    readonly property real fill: intro.running ? Theme.out3(Theme.seg(intro.ms, direct ? 0 : 280, direct ? 600 : 1250))
        : outro.running ? root.build : 1

    readonly property real presence: intro.running ? Theme.seg(intro.ms, 0, 250) : outro.running ? 1 - Theme.seg(outro.ms, 0, 300) : RigState.open ? 1 : 0
    readonly property real build: intro.running ? Theme.out3(Theme.seg(intro.ms, direct ? 0 : 150, direct ? 550 : 950))
        : outro.running ? 1 - Theme.inOut(Theme.seg(outro.ms, 0, 260)) : 1
    readonly property real disc: intro.running ? Theme.out3(Theme.seg(intro.ms, 0, 420)) : outro.running ? 1 - Theme.seg(outro.ms, 60, 300) : 1
    function arrive(i) { return intro.running && !direct ? Theme.out3(Theme.seg(intro.ms, 760 + i * 45, 960 + i * 45)) : 1; }
    function line(i) { return intro.running && !direct ? Theme.seg(intro.ms, 680 + i * 45, 860 + i * 45) : 1; }
    readonly property real hudAmt: outro.running ? Theme.seg(outro.ms, 0, 220) : 0
    readonly property real panelOpen: Theme.inOut(pageK)

    // the camera: glides towards the slot in view
    // which way the camera looks at an implant: square on from the front or back, three-quarters from a side
    function angleOf(a) {
        const d = Math.atan2(a[0], a[2]) * 180 / Math.PI;
        return Math.abs(d) > 50 && Math.abs(d) < 130 ? Math.sign(d) * 50 : d;
    }
    QtObject {
        id: cam
        property real yaw: 0
        property real ty: 0.93
        property real dist: 4.6
        property real viewX: 0
        property real focusAmt: 0
        readonly property var slot: root.focusSlot
        readonly property var at: slot ? root.anchorTo(slot) : [0, 0.93, 0]   // where the implant will be, posed
        // (a pose may say where to film it from and how: the legs' stride from the side, whole)
        readonly property var shot: root.paged ? RigState.poses[RigState.posePages[RigState.page]] : null
        readonly property var view: shot?.view
        readonly property var frame: shot?.frame
        readonly property real tyaw: root.paged ? (view ?? root.angleOf(at)) : slot ? Math.max(-16, Math.min(16, root.angleOf(at) * 0.35)) : Math.sin(root.time * 0.25) * 6
        readonly property real tty: root.paged ? (frame ? frame[0] : at[1]) : 0.93
        // with a page open the body has the room between the rail and the panel: frame the implant so
        // about 0.9 m (head) or 1.3 m (the rest) fits across it, whatever the screen's shape
        readonly property real room: Math.max(200, root.width - Math.min(680, root.width * 0.44) - 40 - 40)
        readonly property real tdist: root.paged ? (frame ? frame[1] : slot.anchor[1] > 1.45 ? 1.35 : 1.95) : 4.6
        readonly property real tviewX: root.paged ? root.pageCx - root.width / 2 : 0
    }
    FrameAnimation {
        running: root.visible
        onTriggered: {
            const dt = Math.min(frameTime, 1 / 30);
            root.time += dt;
            const k = 1 - Math.exp(-dt * 5.5);
            let dy = ((cam.tyaw - cam.yaw) % 360 + 540) % 360 - 180;
            cam.yaw += dy * k;
            cam.ty += (cam.tty - cam.ty) * k;
            cam.dist += (cam.tdist - cam.dist) * (1 - Math.exp(-dt * (intro.running ? 3.5 : 5.5)));
            cam.viewX += (cam.tviewX - cam.viewX) * k;
            cam.focusAmt += ((root.focusSlot ? 1 : 0) - cam.focusAmt) * k;
            root.pageK += ((root.paged ? 1 : 0) - root.pageK) * (1 - Math.exp(-dt * 6));
            if (Math.abs(root.pageK - (root.paged ? 1 : 0)) < 0.002) root.pageK = root.paged ? 1 : 0;
            root.flicker = Math.random() < 0.025 ? 0.2 + Math.random() * 0.5 : 1;
            root.heartRate += ((60 + SysInfo.cpu * 110) / 60 - root.heartRate) * (1 - Math.exp(-dt * 0.8));
            root.beats += dt * root.heartRate;
            root.surge += ((RigState.page === "telemetry" ? 1 : 0) - root.surge) * k;
            root.stepPose(dt);
            root.tick++;
        }
    }

    // ---------------------------------------------------------------- the backdrop
    Rectangle { anchors.fill: parent; color: Theme.alpha(Qt.tint(Theme.bgDark, Theme.alpha(Theme.red, 0.05)), 0.93 * root.presence) }
    Rectangle {           // a red bloom behind the body
        anchors.centerIn: parent
        width: root.height * 1.1; height: width; radius: width / 2
        opacity: 0.5 * root.presence * (1 - root.panelOpen)
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Theme.alpha(Theme.red, 0.07) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    // the ring behind the body, with its ticks, turning slowly
    Item {
        id: halo
        readonly property point c: root.screen([0, 1.15, 0])
        readonly property real r: root.height * 0.33 * 4.6 / Math.max(1, cam.dist)
        x: c.x; y: c.y
        opacity: root.presence * (1 - root.panelOpen) * (intro.running ? Theme.seg(intro.ms, 100, 700) : 1)
        Shape {
            x: -halo.r - 20; y: -halo.r - 20
            width: halo.r * 2 + 40; height: width
            rotation: root.time * 3
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.alpha(Theme.red, 0.3); strokeWidth: 1.5; fillColor: "transparent"
                PathAngleArc { centerX: halo.r + 20; centerY: halo.r + 20; radiusX: halo.r; radiusY: halo.r; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: Theme.alpha(Theme.red, 0.55); strokeWidth: 3; fillColor: "transparent"
                PathAngleArc { centerX: halo.r + 20; centerY: halo.r + 20; radiusX: halo.r + 10; radiusY: halo.r + 10; startAngle: 200; sweepAngle: 70 }
            }
            ShapePath {
                strokeColor: Theme.alpha(Theme.red, 0.4); strokeWidth: 3; fillColor: "transparent"
                PathAngleArc { centerX: halo.r + 20; centerY: halo.r + 20; radiusX: halo.r + 10; radiusY: halo.r + 10; startAngle: 20; sweepAngle: 40 }
            }
        }
        Repeater {
            model: 72
            Rectangle {
                required property int index
                readonly property real a: index * 5 * Math.PI / 180 + root.time * 0.05
                x: Math.cos(a) * (halo.r - 8) - 1; y: Math.sin(a) * (halo.r - 8) - (index % 6 === 0 ? 5 : 2)
                width: 2; height: index % 6 === 0 ? 10 : 4
                rotation: a * 180 / Math.PI + 90
                color: Theme.alpha(Theme.red, index % 6 === 0 ? 0.45 : 0.2)
            }
        }
    }
    Canvas {        // scanlines
        anchors.fill: parent
        opacity: 0.6 * root.presence
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = Theme.alpha(Theme.cyan, 0.035);
            for (let y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1);
        }
    }
    MouseArea { anchors.fill: parent; onClicked: root.close() }

    // ---------------------------------------------------------------- the hologram
    Item {
        id: stage3d
        x: cam.viewX
        width: root.width
        height: root.height
        opacity: root.presence

        // Built for each open and dropped on close: Qt Quick 3D 6.12 aborts
        // (QSSGGlobalRenderNodeData::reindex assertion) when a View3D's window is hidden and shown again.
        Loader {
            id: viewLoader
            anchors.fill: parent
            active: root.visible
            sourceComponent: View3D {
                id: view
                anchors.fill: parent
                camera: camera
                environment: ExtendedSceneEnvironment {
                    backgroundMode: SceneEnvironment.Transparent
                    antialiasingMode: SceneEnvironment.MSAA
                    antialiasingQuality: SceneEnvironment.Medium
                    glowEnabled: true
                    glowStrength: 1.0
                    glowIntensity: 0.55
                    glowBloom: 0.1
                    glowHDRMinimumValue: 0.75
                    glowBlendMode: ExtendedSceneEnvironment.GlowBlendMode.Additive
                    glowLevel: ExtendedSceneEnvironment.GlowLevel.One | ExtendedSceneEnvironment.GlowLevel.Two | ExtendedSceneEnvironment.GlowLevel.Three
                }
                Node {
                    position: Qt.vector3d(0, cam.ty, 0)
                    eulerRotation.y: cam.yaw
                    PerspectiveCamera {
                        id: camera
                        position: Qt.vector3d(0, 0.05, cam.dist)
                        fieldOfView: 30
                        clipNear: 0.05
                        clipFar: 60
                    }
                }
                // the skeleton: a Node per bone, placed by stepPose
                property var made: []
                property int madeCount: 0
                Node {
                    Repeater3D {
                        model: RigState.bones.length
                        delegate: Node {}
                        onObjectAdded: (index, object) => {
                            view.made[index] = object;
                            if (++view.madeCount === RigState.bones.length) {
                                rigSkin.joints = view.made;
                                root.jointNodes = view.made;
                                root.stepPose(0);
                            }
                        }
                    }
                }
                Component.onDestruction: root.jointNodes = []
                Skin {
                    id: rigSkin
                    inverseBindPoses: RigState.inverseBinds
                }
                // the vessels first (sorted as if further away), so the flesh adds over them
                Model {
                    visible: RigState.vessels !== null
                    skin: rigSkin
                    depthBias: 100
                    geometry: ProceduralMesh {
                        positions: RigState.vessels?.positions ?? []
                        normals: RigState.vessels?.normals ?? []
                        uv0s: RigState.vessels?.uvs ?? []
                        joints: RigState.vessels?.joints ?? []
                        weights: RigState.vessels?.weights ?? []
                        indexes: RigState.vessels?.indexes ?? []
                    }
                    materials: CustomMaterial {
                        shadingMode: CustomMaterial.Unshaded
                        sourceBlend: CustomMaterial.One
                        destinationBlend: CustomMaterial.One
                        depthDrawMode: Material.NeverDepthDraw
                        cullMode: Material.BackFaceCulling
                        vertexShader: "../shaders/body/vessels.vert"
                        fragmentShader: "../shaders/body/vessels.frag"
                        property color tint: Theme.yellow
                        property color hot: Theme.cyan
                        property vector3d focus: cam.slot ? Qt.vector3d(cam.slot.anchor[0], cam.slot.anchor[1], cam.slot.anchor[2]) : Qt.vector3d(0, -5, 0)
                        property real focusAmt: cam.focusAmt
                        property real fill: root.fill * ((RigState.vessels?.length ?? 2) + 0.1)
                        property real surge: root.surge
                        property real time: root.time
                        property real beats: root.beats
                        property real heartRate: root.heartRate
                        property real speed: 1.3
                        property real flicker: root.flicker
                        property real pxScale: 0.5359 / Math.max(1, view.height)
                    }
                }
                Model {
                    visible: RigState.bodyIndexes.length > 0
                    skin: rigSkin
                    geometry: ProceduralMesh {
                        positions: RigState.bodyPositions
                        normals: RigState.bodyNormals
                        joints: RigState.bodyJoints
                        weights: RigState.bodyWeights
                        indexes: RigState.bodyIndexes
                    }
                    materials: CustomMaterial {
                        shadingMode: CustomMaterial.Unshaded
                        sourceBlend: CustomMaterial.One
                        destinationBlend: CustomMaterial.One
                        depthDrawMode: Material.AlwaysDepthDraw
                        cullMode: Material.BackFaceCulling
                        vertexShader: "../shaders/body/holo.vert"
                        fragmentShader: "../shaders/body/holo.frag"
                        property color tint: Theme.red
                        property color veins: Theme.yellow
                        property color hot: Theme.cyan
                        property vector3d focus: cam.slot ? Qt.vector3d(cam.slot.anchor[0], cam.slot.anchor[1], cam.slot.anchor[2]) : Qt.vector3d(0, -5, 0)
                        property real focusAmt: cam.focusAmt
                        property vector3d heart: Qt.vector3d(RigState.heart[0], RigState.heart[1], RigState.heart[2])
                        property real build: root.build
                        property real time: root.time
                        property real beats: root.beats
                        property real flicker: root.flicker
                    }
                }
                Model {
                    source: "#Rectangle"
                    eulerRotation.x: -90
                    position: Qt.vector3d(0, 0.002, 0)
                    scale: Qt.vector3d(0.0135, 0.0135, 1)
                    materials: CustomMaterial {
                        shadingMode: CustomMaterial.Unshaded
                        sourceBlend: CustomMaterial.One
                        destinationBlend: CustomMaterial.One
                        cullMode: Material.NoCulling
                        depthDrawMode: Material.NeverDepthDraw
                        vertexShader: "../shaders/body/floor.vert"
                        fragmentShader: "../shaders/body/floor.frag"
                        property color tint: Theme.yellow
                        property real time: root.time
                        property real open: Math.max(0.001, root.disc)
                    }
                }
            }
        }
    }
    // where a point on the body is on the screen, now
    function screen(a) {
        root.tick;
        const v = viewLoader.item;
        if (!v) return Qt.point(-100, -100);
        const p = v.mapFrom3DScene(Qt.vector3d(a[0], a[1], a[2]));
        return Qt.point(p.x + stage3d.x, p.y);
    }

    // ---------------------------------------------------------------- the HUD
    // the implants' slot tiles: what each one reads out live, and what a click does
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.source].filter(n => n) }
    function later(fn) { root.close(); afterClose.fn = fn; afterClose.restart(); }
    Timer { id: afterClose; property var fn; interval: 360; onTriggered: fn() }
    function tilesOf(id) {
        const pct = v => Math.round(v * 100) + "%";
        switch (id) {
        case "claude": {
            const l = (ClaudeStatus.data?.limits ?? [])[0], m = ClaudeStatus.prettyModel(ClaudeStatus.data?.model?.configured || ClaudeStatus.data?.model?.lastUsed || "");
            return [{ g: "\u{f06a9}", label: "session", value: l ? Math.round(l.percent ?? 0) + "%" : "--", on: !!l, alert: (l?.percent ?? 0) >= 90, tip: l ? l.label + " used" : "no usage data yet" },
                    { g: "\u{f09d1}", label: "model", value: (m.split(" ")[0] || "--").slice(0, 6).toUpperCase(), on: !!m, tip: m || "no model yet" }];
        }
        case "optics":
            return (Brightness.displays.length ? Brightness.displays : Quickshell.screens.map(s => ({ name: s.name, value: -1 }))).slice(0, 3)
                .map(d => ({ g: "\u{f0379}", label: (d.name || "display").slice(0, 7), value: d.value >= 0 ? pct(d.value) : "", on: true, tip: d.value >= 0 ? (d.name || "display") + " brightness" : d.name }));
        case "radio":
            return [{ g: "\u{f057e}", label: "out", value: root.sink ? pct(root.sink.audio?.volume ?? 0) : "--", on: !(root.sink?.audio?.muted ?? true), tip: "speakers: click to mute",
                      go: root.sink ? () => root.sink.audio.muted = !root.sink.audio.muted : null },
                    { g: "\u{f036c}", label: "mic", value: "", on: !(root.source?.audio?.muted ?? true), tip: "microphone: click to mute",
                      go: root.source ? () => root.source.audio.muted = !root.source.audio.muted : null }];
        case "log":
            return [{ g: "\u{f009b}", label: "dnd", value: "", on: Notifs.dnd, tip: "do not disturb: only urgent messages", go: () => Notifs.dnd = !Notifs.dnd },
                    { g: "\u{f011c}", label: "inbox", value: String(Notifs.history.length), on: Notifs.unread > 0, alert: Notifs.unread > 0, tip: Notifs.unread + " unread" }];
        case "helm":
            return [{ g: "\u{f0176}", label: "awake", value: "", on: StayAwake.on, tip: "stay awake: no dim, lock or sleep", go: () => StayAwake.on = !StayAwake.on },
                    { g: "\u{f0100}", label: "snap", value: "", on: false, tip: "screenshot a region", go: () => root.later(() => Capture.screenshot("region")) },
                    { g: "\u{f033e}", label: "lock", value: "", on: false, tip: "lock the session now", go: () => root.later(() => Quickshell.execDetached(["sh", "-c", "~/.config/theme/theme lock"])) }];
        case "telemetry":
            return [{ g: "\u{f0ee0}", label: "cpu", value: pct(SysInfo.cpu), on: true, alert: SysInfo.cpu > 0.9, tip: "processor load" },
                    { g: "\u{f035b}", label: "mem", value: pct(SysInfo.mem), on: true, alert: SysInfo.mem > 0.9, tip: "memory in use" },
                    { g: "\u{f050f}", label: "temp", value: SysInfo.hasTemp ? Math.round(SysInfo.temp) + "°" : "--", on: SysInfo.hasTemp, alert: SysInfo.temp > 85, tip: "cpu temperature" }];
        case "comms":
            return [{ g: "\u{f05a9}", label: "wi-fi", value: "", on: Net.wifiEnabled, tip: Net.wifiEnabled ? (Net.ssid || "not connected") : "radio off", go: () => Net.toggleWifi() },
                    { g: "\u{f00af}", label: "bt", value: "", on: root.bt?.enabled ?? false, tip: "bluetooth", go: root.bt ? () => root.bt.enabled = !root.bt.enabled : null },
                    { g: "\u{f0582}", label: "tailnet", value: "", on: Net.tsRunning, tip: Net.tsRunning ? Net.tsPeersOnline + " peers online" : "tailscale down", go: Net.tsAvailable ? () => Net.toggleTailscale() : null }];
        case "chronometer":
            return [{ g: "\u{f06ad}", label: FocusTimer.running ? "pause" : "start", value: FocusTimer.active ? FocusTimer.remainingText : "", on: FocusTimer.running, tip: FocusTimer.phaseLabel + ": click to " + (FocusTimer.running ? "pause" : "start"), go: () => FocusTimer.toggle() }];
        case "almanac":
            return [{ g: "\u{f0595}", label: "out", value: Weather.ready ? Math.round(Weather.current.temp) + "°" : "--", on: Weather.ready, tip: Weather.ready ? Weather.describe(Weather.current.code) : "no forecast" },
                    { g: "\u{f0f64}", label: Qt.formatDate(new Date(), "ddd"), value: Qt.formatDate(new Date(), "dd"), on: true, tip: Qt.formatDate(new Date(), "dddd d MMMM") }];
        case "lamps":
            return [{ g: "\u{f03d8}", label: "sync", value: "", on: Rgb.followWallpaper, tip: Rgb.available ? "lights follow the profile's colour" : "openrgb not found", go: Rgb.available ? () => Rgb.setFollowWallpaper(!Rgb.followWallpaper) : null }];
        case "hangar": {
            const b = UPower.displayDevice;
            const t = [{ g: "\u{f02ca}", label: "drives", value: Devices.drives.length ? String(Devices.drives.length) : "--", on: Devices.drives.length > 0, tip: "drives attached" }];
            if (b?.isLaptopBattery) t.push({ g: "\u{f0079}", label: "batt", value: Math.round(b.percentage * (b.percentage > 1 ? 1 : 100)) + "%", on: true, tip: "battery" });
            return t;
        }
        }
        return [];
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const k = e.key;
            if (k === Qt.Key_Escape) root.back();
            else if (k === Qt.Key_Q) root.goTab(1);
            else if (k === Qt.Key_E) root.goTab(3);
            else if (root.paged) {
                const i = RigState.pages.findIndex(p => p.id === RigState.page), n = RigState.pages.length;
                if (k === Qt.Key_Tab || k === Qt.Key_PageDown) RigState.page = RigState.pages[(i + 1) % n].id;
                else if (k === Qt.Key_Backtab || k === Qt.Key_PageUp) RigState.page = RigState.pages[(i - 1 + n) % n].id;
                else return;
            } else {
                const o = root.order, i = o.findIndex(p => p.id === root.hoverId);
                const digit = "1234567890-".indexOf(e.text);
                if (k === Qt.Key_Down || k === Qt.Key_Tab) root.hoverId = o[(i + 1) % o.length].id;
                else if (k === Qt.Key_Up || k === Qt.Key_Backtab) root.hoverId = o[(i - 1 + o.length) % o.length].id;
                else if (k === Qt.Key_Left || k === Qt.Key_Right) {
                    const side = k === Qt.Key_Left ? 0 : 1, cur = o[i];
                    const col = o.filter(p => p.side === side);
                    if (col.length) root.hoverId = (cur ? col.reduce((b, p) => Math.abs(p.anchor[1] - cur.anchor[1]) < Math.abs(b.anchor[1] - cur.anchor[1]) ? p : b, col[0]) : col[0]).id;
                }
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.openPage(root.hoverId || o[0].id);
                else if (digit >= 0 && digit < RigState.pages.length) root.openPage(RigState.pages[digit].id);
                else return;
            }
            e.accepted = true;
        }

        Item {
            id: hud
            anchors.fill: parent
            layer.enabled: root.hudAmt > 0.002
            layer.effect: ShaderEffect {
                fragmentShader: Qt.resolvedUrl("../shaders/glitch.frag.qsb")
                property vector2d size: Qt.vector2d(hud.width, hud.height)
                property real amount: root.hudAmt
                property real time: root.time
                property real seed: 0.47
                property color red: Theme.red
                property color cyan: Theme.cyan
            }

            // ---------------------------------------------------------------- the top bar, as the game's
            Item {
                id: topbar
                width: parent.width
                height: 74
                opacity: root.presence * (1 - root.panelOpen * 0.0)
                // LEVEL: hours this machine has been up; STREET CRED: how many times this shell has started
                Row {
                    x: 36; y: 16
                    spacing: 26
                    Row {
                        spacing: 8
                        Text { text: root.uptimeHours; color: Theme.cyan; font.family: Theme.display; font.pixelSize: 30; font.weight: Font.Bold }
                        Column { anchors.verticalCenter: parent.verticalCenter
                            Label { text: "LEVEL"; color: Theme.cyan; strong: true }
                            Rectangle { width: 70; height: 3; color: Theme.alpha(Theme.cyan, 0.3)
                                Rectangle { width: parent.width * ((root.uptimeHours % 24) / 24); height: 3; color: Theme.cyan } } }
                    }
                    Row {
                        spacing: 8
                        Text { text: Status.session; color: Theme.green; font.family: Theme.display; font.pixelSize: 30; font.weight: Font.Bold }
                        Column { anchors.verticalCenter: parent.verticalCenter
                            Label { text: "STREET CRED"; color: Theme.green; strong: true }
                            Rectangle { width: 90; height: 3; color: Theme.alpha(Theme.green, 0.3)
                                Rectangle { width: parent.width * ((Status.session % 50) / 50); height: 3; color: Theme.green } } }
                    }
                }
                // the tabs: the other screens, one click away (Q / E step through them)
                Row {
                    id: tabs
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 18
                    spacing: 22
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; color: "transparent"; border.width: 1; border.color: Theme.alpha(Theme.fg, 0.5)
                        Text { anchors.centerIn: parent; text: "Q"; color: Theme.fg; font.family: Theme.mono; font.pixelSize: 11; font.weight: Font.Bold } }
                    Repeater {
                        model: root.tabsList
                        Row {
                            id: tabItem
                            required property var modelData
                            required property int index
                            readonly property bool here: modelData.id === "cyberware"
                            spacing: 6
                            HoverHandler { id: tabHover }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: tabItem.here ? "◆" : tabItem.modelData.g
                                   color: tabItem.here ? Theme.cyan : tabHover.hovered ? Theme.bright : Theme.alpha(Theme.red, 0.8); font.family: Theme.mono; font.pixelSize: 14 }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: tabItem.modelData.name
                                   color: tabItem.here ? Theme.cyan : tabHover.hovered ? Theme.bright : Theme.alpha(Theme.red, 0.85)
                                   font.family: Theme.condensed; font.pixelSize: 16; font.weight: Font.Bold; font.letterSpacing: 1.5 }
                            TapHandler { onTapped: root.goTab(tabItem.index) }
                        }
                    }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; color: "transparent"; border.width: 1; border.color: Theme.alpha(Theme.fg, 0.5)
                        Text { anchors.centerIn: parent; text: "E"; color: Theme.fg; font.family: Theme.mono; font.pixelSize: 11; font.weight: Font.Bold } }
                }
                // carry weight: the memory in use; eddies: free space on / in MB
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 36
                    y: 20
                    spacing: 26
                    Row { spacing: 6
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "\u{f035b}"; color: Theme.red; font.family: Theme.mono; font.pixelSize: 16 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: root.memUsed + "/" + root.memTotal; color: Theme.red; font.family: Theme.display; font.pixelSize: 19; font.weight: Font.Bold } }
                    Row { spacing: 6
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "€$"; color: Theme.yellow; font.family: Theme.display; font.pixelSize: 17; font.weight: Font.Bold }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: root.eddies; color: Theme.bright; font.family: Theme.display; font.pixelSize: 19; font.weight: Font.Bold } }
                }
                Rectangle { x: 24; y: 56; width: parent.width - 48; height: 1; color: Theme.alpha(Theme.red, 0.55) }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 60
                    text: root.paged ? "CYBERWARE  //  " + (RigState.current?.slot ?? "").toUpperCase() : "CYBERWARE"
                    color: Theme.alpha(Theme.red, 0.9)
                    font.family: Theme.condensed; font.pixelSize: 15; font.weight: Font.Bold; font.letterSpacing: 2
                }
            }

            // ---------------------------------------------------------------- the categories, either side of the body
            Item {
                id: mods
                anchors.fill: parent
                visible: opacity > 0.01
                readonly property real pk: root.panelOpen
                readonly property real cx: root.width / 2 + (root.pageCx - root.width / 2) * pk
                readonly property real slot: Math.min(68, root.height * 0.063) * (1 - 0.14 * pk)
                // from the body's middle to the first slot: the arms' reach, at the camera's distance
                readonly property real inner: (root.width * 0.165) * (1 - pk) + Math.max(140, root.pageCx - 470) * pk
                readonly property var capacity: ({ claude: 3, optics: 3, telemetry: 4, log: 3, comms: 4, almanac: 3, helm: 4, hangar: 3, lamps: 2, radio: 3, chronometer: 2 })
                Repeater {
                    model: RigState.pages
                    Item {
                        id: mod
                        required property var modelData
                        required property int index
                        readonly property bool westward: modelData.side === 0
                        readonly property bool hot: root.paged ? RigState.page === modelData.id : root.hoverId === modelData.id
                        readonly property int n: root.order.indexOf(modelData)
                        readonly property var p: root.screen(root.anchorNow(modelData))
                        readonly property real k: root.arrive(n)
                        readonly property color tier: RigState.tierColor(modelData.tier)
                        readonly property var tiles: root.tilesOf(modelData.id).slice(0, (mods.capacity[modelData.id] ?? 3) - 1)
                        readonly property int empties: Math.max(0, (mods.capacity[modelData.id] ?? 3) - 1 - tiles.length)
                        readonly property real slotsW: (1 + tiles.length + empties) * (mods.slot + 6) - 6
                        // the row's edge nearest the body
                        readonly property real edge: westward ? mods.cx - mods.inner : mods.cx + mods.inner
                        readonly property real cy: root.height * modelData.row
                        x: 0; y: 0; width: root.width; height: root.height
                        opacity: k

                        // the cable from the row to its implant
                        Shape {
                            id: cable
                            anchors.fill: parent
                            opacity: mod.hot || !root.paged ? 1 : Math.max(0, 1 - mods.pk * 1.5)
                            preferredRendererType: Shape.CurveRenderer
                            readonly property point a: Qt.point(mod.edge + (mod.westward ? 4 : -4), mod.cy)
                            readonly property point b: mod.p
                            ShapePath {
                                strokeColor: mod.hot ? Theme.alpha(Theme.cyan, 0.35) : "transparent"
                                strokeWidth: 7
                                fillColor: "transparent"
                                startX: cable.a.x; startY: cable.a.y
                                PathCubic { x: cable.b.x; y: cable.b.y
                                    control1X: cable.a.x + (mod.westward ? 90 : -90); control1Y: cable.a.y
                                    control2X: cable.b.x + (mod.westward ? -70 : 70); control2Y: cable.b.y + 20 }
                            }
                            ShapePath {
                                strokeColor: mod.hot ? Theme.cyan : Theme.alpha(Theme.red, 0.55)
                                strokeWidth: mod.hot ? 2 : 1.2
                                fillColor: "transparent"
                                startX: cable.a.x; startY: cable.a.y
                                PathCubic { x: cable.b.x; y: cable.b.y
                                    control1X: cable.a.x + (mod.westward ? 90 : -90); control1Y: cable.a.y
                                    control2X: cable.b.x + (mod.westward ? -70 : 70); control2Y: cable.b.y + 20 }
                            }
                        }
                        // a pulse running down the cable (in from the implant as it arrives, then now and then)
                        Rectangle {
                            readonly property real t: root.line(mod.n) < 1 ? 1 - root.line(mod.n) : ((root.time * 0.45 + mod.index * 0.37) % 2.5) / 2.5 * 2.5
                            visible: t <= 1 && cable.opacity > 0.5
                            readonly property real u: 1 - t
                            readonly property point c1: Qt.point(cable.a.x + (mod.westward ? 90 : -90), cable.a.y)
                            readonly property point c2: Qt.point(cable.b.x + (mod.westward ? -70 : 70), cable.b.y + 20)
                            x: u * u * u * cable.a.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * cable.b.x - 4
                            y: u * u * u * cable.a.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * cable.b.y - 4
                            width: 8; height: 8; radius: 4
                            color: mod.hot ? Theme.bright : Theme.yellow
                        }
                        Rectangle {
                            opacity: cable.opacity
                            x: mod.p.x - width / 2; y: mod.p.y - height / 2
                            width: mod.hot ? 12 : 6; height: width; radius: width / 2
                            color: mod.hot ? Theme.cyan : Theme.alpha(Theme.red, 0.9)
                        }

                        // the slots: the implant (its rarity on a bar down its side), its switches and readouts, empty sockets
                        Row {
                            id: slots
                            x: mod.westward ? mod.edge - mod.slotsW + (1 - mod.k) * -50 : mod.edge + (1 - mod.k) * 50
                            y: mod.cy - mods.slot / 2
                            spacing: 6
                            layoutDirection: mod.westward ? Qt.LeftToRight : Qt.RightToLeft
                            // the implant itself
                            Item {
                                id: implant
                                width: mods.slot; height: mods.slot
                                HoverHandler { id: ih; onHoveredChanged: if (hovered) root.hoverId = mod.modelData.id }
                                Chamfer {
                                    anchors.fill: parent; cut: 9; corners: mod.westward ? "tr" : "tl"
                                    fill: mod.hot ? Theme.alpha(mod.tier, 0.22) : Theme.alpha(Qt.darker(Theme.red, 5), 0.92)
                                    stroke: mod.hot ? Theme.bright : Theme.alpha(Theme.red, 0.6)
                                }
                                Rectangle { x: 2; y: 4; width: 4; height: parent.height - 8; color: mod.tier }
                                Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: 2; text: mod.modelData.glyph; color: mod.hot ? Theme.bright : Theme.alpha(Theme.fg, 0.85); font.family: Theme.mono; font.pixelSize: mods.slot * 0.64 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openPage(mod.modelData.id) }
                            }
                            Repeater {
                                model: mod.tiles
                                Item {
                                    id: tileItem
                                    required property var modelData
                                    readonly property bool live: !!modelData.go
                                    readonly property color c: modelData.alert ? Theme.red : modelData.on ? Theme.cyan : Theme.dim
                                    width: mods.slot; height: mods.slot
                                    HoverHandler { id: th; onHoveredChanged: if (hovered) { root.hoverId = mod.modelData.id; tip.show(tileItem, tileItem.modelData); } else tip.hide(tileItem) }
                                    Chamfer {
                                        anchors.fill: parent; cut: 9; corners: mod.westward ? "tr" : "tl"
                                        fill: tileItem.modelData.on ? Theme.alpha(tileItem.c, th.hovered ? 0.28 : 0.13) : Theme.alpha(Qt.darker(Theme.red, 6), 0.9)
                                        stroke: th.hovered ? Theme.bright : Theme.alpha(Theme.red, 0.5)
                                    }
                                    Rectangle { x: 2; y: 4; width: 3; height: parent.height - 8; color: tileItem.c }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: tileItem.modelData.value ? 7 : 10
                                        text: tileItem.modelData.value || tileItem.modelData.g
                                        color: tileItem.modelData.on || tileItem.modelData.alert ? Theme.bright : Theme.alpha(Theme.fg, 0.4)
                                        font.family: tileItem.modelData.value ? Theme.display : Theme.mono
                                        font.pixelSize: tileItem.modelData.value ? mods.slot * (tileItem.modelData.value.length > 4 ? 0.25 : 0.33) : mods.slot * 0.52
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 5
                                        text: tileItem.modelData.label.toUpperCase()
                                        color: Theme.alpha(Theme.fg, tileItem.modelData.on ? 0.75 : 0.4)
                                        font.family: Theme.mono; font.pixelSize: 8; font.weight: Font.Bold; font.letterSpacing: 1
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: tileItem.live ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: if (tileItem.live) tileItem.modelData.go(); else root.openPage(mod.modelData.id)
                                    }
                                }
                            }
                            Repeater {
                                model: mod.empties
                                Item {
                                    width: mods.slot; height: mods.slot
                                    Chamfer { anchors.fill: parent; cut: 9; corners: mod.westward ? "tr" : "tl"; fill: Theme.alpha(Qt.darker(Theme.red, 6), 0.85); stroke: Theme.alpha(Theme.red, 0.35) }
                                    Text { anchors.centerIn: parent; text: "+"; color: Theme.alpha(Theme.red, 0.5); font.family: Theme.mono; font.pixelSize: 22 }
                                }
                            }
                        }

                        // the name, outside the slots, the way the game sets it
                        Column {
                            id: name
                            readonly property real w: Math.min(210, root.width * 0.115)
                            x: mod.westward ? slots.x - 14 - w : slots.x + slots.width + 14
                            y: mod.cy - height / 2
                            width: w
                            spacing: 2
                            Text {
                                width: parent.width
                                horizontalAlignment: mod.westward ? Text.AlignRight : Text.AlignLeft
                                wrapMode: Text.WordWrap
                                text: mod.modelData.slot.toUpperCase()
                                color: mod.hot ? Theme.bright : Qt.lighter(Theme.red, 1.25)
                                font.family: Theme.condensed; font.pixelSize: 19 - 4 * mods.pk; font.weight: Font.Bold; font.letterSpacing: 1
                                lineHeight: 0.9
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: mod.westward ? Text.AlignRight : Text.AlignLeft
                                elide: Text.ElideRight
                                text: root.statusOf(mod.modelData.id).toUpperCase()
                                color: root.alertOf(mod.modelData.id) ? Theme.red : Theme.alpha(Theme.fg, 0.55)
                                font.family: Theme.mono; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2
                            }
                        }
                        MouseArea {
                            x: name.x; y: name.y; width: name.width; height: name.height
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: root.hoverId = mod.modelData.id
                            onClicked: root.openPage(mod.modelData.id)
                        }
                    }
                }

                Text {      // the way back, bottom right, as the game has it
                    anchors.right: parent.right; anchors.rightMargin: 40
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 26
                    text: "\u{f037d}  BACK"
                    color: Theme.alpha(Theme.fg, 0.8)
                    font.family: Theme.mono; font.pixelSize: 14; font.weight: Font.Bold
                    TapHandler { onTapped: root.close() }
                }
            }

            // the tooltip: the slot as an item card
            Item {
                id: tip
                property var owner: null
                property var info: null
                function show(item, info) { owner = item; tip.info = info; const p = item.mapToItem(hud, 0, 0); tip.x = Math.min(hud.width - width - 10, p.x); tip.y = p.y + item.height + 8; }
                function hide(item) { if (owner === item) owner = null; }
                visible: owner !== null && info !== null
                width: 250
                height: tipCol.implicitHeight + 20
                z: 10
                Chamfer { anchors.fill: parent; cut: 10; corners: "tr bl"; fill: Theme.alpha(Theme.bgDark, 0.96); stroke: tip.info?.alert ? Theme.red : Theme.alpha(Theme.fg, 0.6) }
                Column {
                    id: tipCol
                    x: 12; y: 10
                    width: parent.width - 24
                    spacing: 4
                    Text { text: (tip.info?.label ?? "").toUpperCase(); color: Theme.bright; font.family: Theme.condensed; font.pixelSize: 16; font.weight: Font.Bold; font.letterSpacing: 1 }
                    Label { text: tip.info?.alert ? "WARNING" : tip.info?.on ? "ACTIVE" : "INACTIVE"; color: tip.info?.alert ? Theme.red : tip.info?.on ? Theme.cyan : Theme.dim; strong: true }
                    Text { width: parent.width; wrapMode: Text.Wrap; text: tip.info?.tip ?? ""; color: Theme.fg; font.family: Theme.sans; font.pixelSize: Theme.data }
                    Label { text: tip.info?.go ? "CLICK  //  " + (tip.info?.on ? "TURN OFF" : "USE") : "CLICK  //  OPEN THE IMPLANT"; color: Theme.yellow }
                }
            }

            // ---------------------------------------------------------------- an implant open
            // the implant's page, unfolding from its line
            Item {
                id: panel
                visible: root.panelOpen > 0.01
                width: Math.min(680, root.width * 0.44)
                height: root.height - 120
                x: root.width - width - 40
                y: 72
                MouseArea { anchors.fill: parent }

                Shape {
                    id: panelWire
                    x: -panel.x; y: -panel.y
                    width: root.width; height: root.height
                    preferredRendererType: Shape.CurveRenderer
                    readonly property point p: RigState.current ? root.screen(root.anchorNow(RigState.current)) : Qt.point(0, 0)
                    ShapePath {
                        strokeColor: Theme.red
                        strokeWidth: 1.5
                        fillColor: "transparent"
                        PathPolyline {
                            path: {
                                const p = panelWire.p, ax = panel.x, ay = panel.y + 48;
                                const t = root.panelOpen;
                                return [p, Qt.point(p.x + (ax - 40 - p.x) * t, p.y + (ay - p.y) * t), Qt.point(ax - 40 + 40 * t, ay)];
                            }
                        }
                    }
                }
                Rectangle {
                    readonly property point p: RigState.current ? root.screen(root.anchorNow(RigState.current)) : Qt.point(0, 0)
                    x: p.x - panel.x - 7; y: p.y - panel.y - 7
                    width: 14; height: 14; radius: 7
                    color: Theme.red
                    Rectangle {
                        readonly property real q: (root.time * 1.4) % 1
                        anchors.centerIn: parent
                        width: 14 + q * 34; height: width; radius: width / 2
                        color: "transparent"; border.width: 1.5; border.color: Theme.alpha(Theme.red, 1 - q)
                    }
                }

                Item {
                    id: sheet
                    width: parent.width
                    height: parent.height * root.panelOpen
                    clip: true
                    Chamfer {
                        width: panel.width; height: panel.height
                        cut: 18; corners: "tl br"
                        fill: Theme.alpha(Theme.bgDark, 0.94)
                        stroke: Theme.alpha(Theme.red, 0.6)
                    }
                    Hazard { x: 30; y: 0; width: 80; height: 5 }
                    Item {
                        id: pageArea
                        x: 22; y: 20
                        width: panel.width - 44
                        height: panel.height - 40
                        readonly property real swap: swapFx.running ? 1 - Theme.seg(swapFx.ms, 40, 380) : 0
                        opacity: swapFx.running ? Theme.seg(swapFx.ms, 0, 160) : 1
                        layer.enabled: swap > 0.002
                        layer.effect: ShaderEffect {
                            fragmentShader: Qt.resolvedUrl("../shaders/glitch.frag.qsb")
                            property vector2d size: Qt.vector2d(pageArea.width, pageArea.height)
                            property real amount: pageArea.swap * 0.8
                            property real time: root.time
                            property real seed: 0.13
                            property color red: Theme.red
                            property color cyan: Theme.cyan
                        }

                        // the implant as an item card: icon in its rarity, name, tier, what it does
                        Item {
                            id: card
                            width: parent.width
                            height: 96
                            readonly property var cur: RigState.current
                            readonly property color tier: RigState.tierColor(cur?.tier ?? "")
                            Rectangle {
                                id: icon
                                width: 80; height: 80
                                color: Theme.alpha(card.tier, 0.14)
                                border.width: 2; border.color: card.tier
                                Text { anchors.centerIn: parent; text: card.cur?.glyph ?? ""; color: Theme.bright; font.family: Theme.mono; font.pixelSize: 40 }
                                Rectangle {          // its glow, breathing
                                    anchors.fill: parent; anchors.margins: -5
                                    color: "transparent"; border.width: 1; border.color: Theme.alpha(card.tier, 0.25 + 0.2 * Math.sin(root.time * 2))
                                }
                            }
                            Column {
                                x: icon.width + 16
                                width: parent.width - x
                                spacing: 3
                                Row {
                                    spacing: 10
                                    Tag { anchors.verticalCenter: parent.verticalCenter; text: card.cur?.code ?? ""; height: 20; pixelSize: 11 }
                                    Scramble {
                                        anchors.verticalCenter: parent.verticalCenter
                                        target: (card.cur?.slot ?? "").toUpperCase()
                                        color: Theme.bright
                                        font.family: Theme.display; font.pixelSize: 24; font.weight: Font.Bold
                                    }
                                    Jp { anchors.verticalCenter: parent.verticalCenter; text: card.cur?.jp ?? ""; font.pixelSize: 13 }
                                }
                                Row {
                                    spacing: 10
                                    Text { text: (card.cur?.tier ?? "").toUpperCase(); color: card.tier; font.family: Theme.mono; font.pixelSize: Theme.label; font.weight: Font.Bold; font.letterSpacing: 2 }
                                    Label { text: (card.cur?.title ?? "") + "  //  " + (card.cur?.sub ?? "") }
                                }
                                Text { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; text: card.cur?.desc ?? ""; color: Theme.fg; font.family: Theme.sans; font.pixelSize: Theme.data }
                                Row {
                                    spacing: 6
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: root.alertOf(card.cur?.id ?? "") ? Theme.red : Theme.green }
                                    Label { text: root.statusOf(card.cur?.id ?? ""); color: Theme.bright }
                                }
                            }
                        }
                        Rectangle { id: rule; y: card.height + 8; width: parent.width; height: 1; color: Theme.alpha(Theme.red, 0.5) }
                        Flickable {
                            id: flick
                            y: rule.y + 14
                            width: parent.width
                            height: parent.height - y
                            clip: true
                            contentHeight: loader.item ? loader.item.implicitHeight + 16 : 0
                            boundsBehavior: Flickable.StopAtBounds
                            Loader {
                                id: loader
                                width: flick.width
                                active: root.visible && root.paged
                                sourceComponent: root.components[RigState.page] ?? null
                                onLoaded: flick.contentY = 0
                            }
                        }
                        Rectangle {        // scroll position
                            visible: flick.contentHeight > flick.height
                            x: parent.width + 10
                            y: flick.y + flick.visibleArea.yPosition * flick.height
                            width: 2
                            height: Math.max(20, flick.visibleArea.heightRatio * flick.height)
                            color: Theme.red
                        }
                    }
                    // the unfold's scan line
                    Rectangle {
                        visible: root.panelOpen > 0.02 && root.panelOpen < 0.98
                        y: sheet.height - 2
                        width: panel.width; height: 2
                        color: Theme.bright
                    }
                }
            }

            Label {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 26
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: root.presence
                text: root.paged ? "TAB NEXT IMPLANT   //   SHIFT TAB BACK   //   ESC BACK TO THE WHOLE BODY"
                                 : "↑↓←→ PICK AN IMPLANT   //   ENTER OPEN   //   1 – 9  0  -  JUMP   //   CLICK A SLOT TO USE IT   //   ESC CLOSE"
            }
        }
    }

    // pages as types (so live reload sees them)
    readonly property var components: ({
        helm: helm, comms: comms, radio: radio, log: log, almanac: almanac, telemetry: telemetry,
        hangar: hangar, optics: optics, lamps: lamps, chronometer: chrono, claude: claude,
    })
    Component { id: helm; Helm {} }
    Component { id: comms; Comms {} }
    Component { id: radio; Airwaves {} }
    Component { id: log; Log {} }
    Component { id: almanac; Almanac {} }
    Component { id: telemetry; Telemetry {} }
    Component { id: hangar; Hangar {} }
    Component { id: optics; Optics {} }
    Component { id: lamps; Lamps {} }
    Component { id: chrono; Chrono {} }
    Component { id: claude; Claude {} }

    Binding {
        target: RigState; property: "status"
        value: `open=${RigState.open} visible=${root.visible} page=${RigState.page} hover=${root.hoverId} pageK=${root.pageK.toFixed(2)} body=${RigState.bodyIndexes.length / 3} pose=${pose.name}:${pose.t.toFixed(2)} joints=${root.jointNodes.length} vessels=${(RigState.vessels?.indexes.length ?? 0) / 3} dnd=${Notifs.dnd}`
    }
}
