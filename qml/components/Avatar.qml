import QtQuick 2.0
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0

Item {
    id: avatar
    property string source
    width: Theme.iconSizeMedium
    height: width

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.3)
        visible: image.status !== Image.Ready
    }

    Image {
        id: image
        anchors.fill: parent
        source: avatar.source
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: width / 2
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        source: image
        maskSource: mask
        visible: image.status === Image.Ready
    }
}
