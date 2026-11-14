import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/feed.js" as Feed

// Icon with a counter under a post (reply, repost, like).
BackgroundItem {
    id: button
    property alias iconSource: icon.source
    property int count
    property bool active

    width: icon.width + countLabel.width + 3 * Theme.paddingSmall
    height: Theme.itemSizeExtraSmall

    Icon {
        id: icon
        x: Theme.paddingSmall
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSizeSmallPlus
        height: width
        sourceSize.width: width
        sourceSize.height: height
        highlighted: button.active || button.highlighted
        opacity: button.enabled ? 1 : 0.4
    }
    Label {
        id: countLabel
        anchors { left: icon.right; leftMargin: Theme.paddingSmall; verticalCenter: parent.verticalCenter }
        text: button.count > 0 ? Feed.count(button.count) : ""
        font.pixelSize: Theme.fontSizeExtraSmall
        color: button.active ? Theme.highlightColor : Theme.secondaryColor
    }
}
