import QtQuick
import QtQuick.Layouts

// In-depth settings: Wi-Fi, Bluetooth, Tailscale
ColumnLayout {
    id: root

    property int page: 0

    spacing: 12

    // Section switcher
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: [
                { name: "Wi-Fi", icon: 0xF05A9 },
                { name: "Bluetooth", icon: 0xF00AF },
                { name: "Tailscale", icon: 0xF0582 }
            ]

            IconButton {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                icon: String.fromCodePoint(modelData.icon)
                label: modelData.name
                primary: root.page === index
                onClicked: root.page = index
            }
        }
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: root.page

        WifiPage {}
        BluetoothPage {}
        TailscalePage {}
    }
}
