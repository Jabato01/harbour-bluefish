import QtQuick 2.0
import Sailfish.Silica 1.0

// Full-size images of a post, swipe between them; the alt text shows below.
Page {
    id: page
    property var images: []
    property int currentIndex
    allowedOrientations: Orientation.All
    backNavigation: true

    SlideshowView {
        id: view
        anchors.fill: parent
        model: images
        currentIndex: page.currentIndex
        itemWidth: width
        itemHeight: height

        delegate: Item {
            width: view.itemWidth
            height: view.itemHeight

            Image {
                id: full
                anchors.fill: parent
                source: modelData.fullsize
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: Math.max(page.width, page.height)
            }
            BusyIndicator {
                anchors.centerIn: parent
                running: full.status === Image.Loading
                size: BusyIndicatorSize.Large
            }
            Label {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.horizontalPageMargin }
                visible: modelData.alt.length > 0
                wrapMode: Text.Wrap
                maximumLineCount: 6
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: modelData.alt
                font.pixelSize: Theme.fontSizeSmall
                Rectangle {
                    anchors { fill: parent; margins: -Theme.paddingSmall }
                    z: -1
                    color: Qt.rgba(0, 0, 0, 0.6)
                }
            }
        }
    }
}
