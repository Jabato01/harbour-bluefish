import QtQuick 2.0
import Sailfish.Silica 1.0
import Celeste 1.0

CoverBackground {
    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingMedium

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Celeste"
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.highlightColor
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            truncationMode: TruncationMode.Fade
            text: Bsky.loggedIn ? "@" + Bsky.handle : qsTr("Sin sesión")
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
