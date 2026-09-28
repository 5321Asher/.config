import QtQuick
import QtQuick.Effects
import "../theme"
import "../widgets"
import "../services"

// The ticker: the machine's state as a slow crawl ("12 AFFECTED // PKG 16 PENDING // QUEUE 1/3 //
// PROFILE CIRCUIT // ICE NOMINAL // 0 FAILED UNITS …"), fading out at both ends. Click for SYS.DIAG.
Item {
    id: root

    signal clicked()

    readonly property string line: [
        Status.auditAvailable ? `${Status.vulnCount} affected` : "vuln scan offline",
        Status.pkgAvailable ? `pkg ${Status.pkgPending} pending` : "pkg feed offline",
        `queue ${Queue.cleared}/${Queue.total}`,
        `profile ${Status.profile || "—"}`,
        `shield ${Status.shield || "none"}`,
        `ice ${Status.ice}`,
        `${Status.failedUnits} failed units`,
        Status.ping >= 0 ? `ping ${Status.ping} ms` : "no uplink",
        `session ${Status.session}`,
    ].join("  //  ").toUpperCase() + "  //  "

    clip: true

    // the crawl, faded out at both ends through an alpha mask (so it blends with whatever's behind the bar)
    Item {
        id: crawlBox
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fadeMask
            maskThresholdMin: 0.0
            maskSpreadAtMin: 1.0
        }
        Row {
            id: crawl
            y: (root.height - height) / 2
            Repeater {
                model: 2
                Label { text: root.line }
            }
            NumberAnimation on x {
                from: 0
                to: -crawl.width / 2
                duration: Math.max(1, crawl.width / 2) * 45      // ~22 px a second
                loops: Animation.Infinite
                running: root.visible
            }
        }
    }
    Item {
        id: fadeMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.06; color: "white" }
                GradientStop { position: 0.94; color: "white" }
                GradientStop { position: 1; color: "transparent" } }
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
