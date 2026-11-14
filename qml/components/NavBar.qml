import QtQuick 2.0
import Sailfish.Silica 1.0

// Bottom bar with the app's main sections. `current` is the section of the page showing it
// ("home", "feeds", "messages", "search", "notifications", "profile" or "" for none).
Rectangle {
    id: bar
    property string current

    width: parent ? parent.width : 0
    height: Theme.itemSizeMedium
    color: Theme.rgba(Theme.highlightDimmerColor, 0.95)

    Separator {
        width: parent.width
        color: Theme.rgba(Theme.primaryColor, 0.2)
        horizontalAlignment: Qt.AlignHCenter
    }

    Row {
        anchors.fill: parent

        Repeater {
            model: [
                { section: "home", icon: "image://theme/icon-m-home", label: qsTr("Siguiendo") },
                { section: "feeds", icon: "image://theme/icon-m-levels", label: qsTr("Feeds y listas") },
                { section: "messages", icon: Qt.resolvedUrl("../icons/icon-m-mail.svg"), label: qsTr("Mensajes") },
                { section: "search", icon: "image://theme/icon-m-search", label: qsTr("Buscar") },
                { section: "notifications", icon: Qt.resolvedUrl("../icons/icon-m-bell.svg"), label: qsTr("Notificaciones") },
                { section: "profile", icon: "", label: qsTr("Mi perfil") }
            ]

            delegate: BackgroundItem {
                id: button
                readonly property bool selected: bar.current === modelData.section
                readonly property int badge: modelData.section === "messages" ? app.unreadMessages
                                           : modelData.section === "notifications" ? app.unreadNotifications : 0
                width: bar.width / 6
                height: bar.height
                highlighted: down || selected

                HighlightImage {
                    anchors.centerIn: parent
                    visible: modelData.section !== "profile"
                    width: Theme.iconSizeMedium
                    height: width
                    sourceSize.width: width
                    sourceSize.height: height
                    source: modelData.icon
                    color: Theme.primaryColor
                    highlightColor: Theme.highlightColor
                    highlighted: button.highlighted
                }

                // "Mi perfil" shows the user's own avatar, ringed when selected.
                Rectangle {
                    anchors.centerIn: parent
                    visible: modelData.section === "profile"
                    width: Theme.iconSizeMedium * 0.8 + 2 * Theme.paddingSmall / 2
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: button.highlighted ? Theme.paddingSmall / 2 : 0
                    border.color: Theme.highlightColor
                    Avatar {
                        anchors.centerIn: parent
                        width: Theme.iconSizeMedium * 0.8
                        source: app.myAvatar
                    }
                }

                Rectangle {
                    visible: button.badge > 0
                    anchors { horizontalCenter: parent.horizontalCenter; horizontalCenterOffset: Theme.iconSizeMedium / 2
                              verticalCenter: parent.verticalCenter; verticalCenterOffset: -Theme.iconSizeMedium / 2 }
                    width: Math.max(height, badgeLabel.implicitWidth + Theme.paddingSmall * 2)
                    height: badgeLabel.implicitHeight
                    radius: height / 2
                    color: Theme.highlightBackgroundColor
                    Label {
                        id: badgeLabel
                        anchors.centerIn: parent
                        text: button.badge > 99 ? "99+" : button.badge
                        font.pixelSize: Theme.fontSizeTiny
                        font.bold: true
                        color: Theme.primaryColor
                    }
                }

                onClicked: app.showSection(modelData.section)
            }
        }
    }
}
