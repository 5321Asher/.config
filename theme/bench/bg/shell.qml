import QtQuick
import Quickshell
import Quickshell.Wayland
// bench wallpaper: a still of Netrunner's city
ShellRoot { Variants { model: Quickshell.screens
  PanelWindow { required property var modelData; screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore; WlrLayershell.layer: WlrLayer.Background; WlrLayershell.namespace: "bench-bg"
    Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; source: "file://" + (Quickshell.env("BENCH_WALLPAPER") ?? "") } } } }
