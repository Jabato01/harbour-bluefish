import QtQuick 2.0
import Sailfish.Silica 1.0

// Up to four images: one keeps its aspect ratio, more go in a two-column grid.
Item {
    id: grid
    property var images: []
    property bool sensitive
    property bool revealed: !sensitive

    readonly property real single: images.length === 1 && images[0].ratio > 0
                                   ? Math.max(0.6, Math.min(images[0].ratio, 2.5)) : 1.5
    width: parent.width
    height: images.length === 0 ? 0
          : images.length === 1 ? width / single
          : images.length === 2 ? width / 2
          : width
    visible: images.length > 0

    // [x, y, width, height] of image i. Three images: the first takes the whole left column.
    function cell(i) {
        var gap = Theme.paddingSmall
        var n = images.length
        var half = (width - gap) / 2
        var halfH = (height - gap) / 2
        if (n === 1) return [0, 0, width, height]
        if (n === 2) return [i * (half + gap), 0, half, height]
        if (n === 3) return i === 0 ? [0, 0, half, height] : [half + gap, (i - 1) * (halfH + gap), half, halfH]
        return [(i % 2) * (half + gap), Math.floor(i / 2) * (halfH + gap), half, halfH]
    }

    Repeater {
        model: grid.images
        delegate: BackgroundItem {
            readonly property var box: grid.cell(index)
            x: box[0]
            y: box[1]
            width: box[2]
            height: box[3]

            Image {
                anchors.fill: parent
                source: modelData.thumb
                sourceSize.width: width
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                clip: true
                opacity: grid.revealed ? 1 : 0.05
            }
            Label {
                anchors { left: parent.left; bottom: parent.bottom; margins: Theme.paddingSmall }
                visible: modelData.alt.length > 0 && grid.revealed
                text: "ALT"
                font.pixelSize: Theme.fontSizeTiny
                font.bold: true
                color: "white"
                Rectangle {
                    anchors { fill: parent; margins: -Theme.paddingSmall / 2 }
                    z: -1
                    radius: Theme.paddingSmall / 2
                    color: Qt.rgba(0, 0, 0, 0.6)
                }
            }
            onClicked: {
                if (!grid.revealed)
                    grid.revealed = true
                else
                    pageStack.push(Qt.resolvedUrl("../pages/ImagePage.qml"),
                                   { images: grid.images, currentIndex: index })
            }
        }
    }

    Label {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        visible: !grid.revealed
        text: qsTr("Contenido sensible. Toca para verlo.")
        color: Theme.highlightColor
    }
}
