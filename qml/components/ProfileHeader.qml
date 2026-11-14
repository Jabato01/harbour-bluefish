import QtQuick 2.0
import Sailfish.Silica 1.0
import Celeste 1.0
import "../js/feed.js" as Feed

// Banner, avatar, bio, counters and follow button of a profile (app.bsky.actor.defs#profileViewDetailed).
Column {
    id: header
    property var profile
    property bool busy
    signal refreshRequested()

    readonly property bool isMe: profile && profile.did === Bsky.did
    readonly property var viewer: (profile && profile.viewer) || {}

    width: parent.width
    spacing: Theme.paddingMedium

    function toggleFollow() {
        busy = true
        if (viewer.following) {
            Bsky.post("com.atproto.repo.deleteRecord",
                      { repo: Bsky.did, collection: "app.bsky.graph.follow", rkey: Feed.rkey(viewer.following) },
                      function() { busy = false; refreshRequested() })
        } else {
            Bsky.post("com.atproto.repo.createRecord", {
                          repo: Bsky.did, collection: "app.bsky.graph.follow",
                          record: { "$type": "app.bsky.graph.follow", subject: profile.did, createdAt: Bsky.now() }
                      }, function() { busy = false; refreshRequested() })
        }
    }

    Item {
        width: parent.width
        height: banner.height + avatar.height / 2

        Image {
            id: banner
            width: parent.width
            height: width / 3
            source: profile.banner || ""
            sourceSize.width: width
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            clip: true
        }

        Avatar {
            id: avatar
            x: Theme.horizontalPageMargin
            y: banner.height - height / 2
            width: Theme.iconSizeExtraLarge
            source: profile.avatar || ""
        }

        Button {
            anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; bottom: parent.bottom }
            visible: !isMe && !viewer.blocking && !viewer.blockedBy
            enabled: !busy
            preferredWidth: Theme.buttonWidthSmall
            text: viewer.following ? qsTr("Siguiendo") : qsTr("Seguir")
            onClicked: toggleFollow()
        }
    }

    Label {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        wrapMode: Text.Wrap
        text: Feed.plain(profile.displayName) || profile.handle
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.highlightColor
    }

    Label {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        wrapMode: Text.Wrap
        text: "@" + profile.handle + (viewer.followedBy ? "  · " + qsTr("Te sigue") : "")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.secondaryColor
    }

    Label {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        wrapMode: Text.Wrap
        text: qsTr("%1 seguidores · %2 siguiendo · %3 posts")
              .arg(Feed.count(profile.followersCount || 0))
              .arg(Feed.count(profile.followsCount || 0))
              .arg(Feed.count(profile.postsCount || 0))
        font.pixelSize: Theme.fontSizeExtraSmall
        color: Theme.secondaryHighlightColor
    }

    Label {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        visible: text.length > 0
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: Feed.plain(profile.description)
        font.pixelSize: Theme.fontSizeSmall
    }

    Label {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        visible: !!(viewer.blocking || viewer.blockedBy)
        wrapMode: Text.Wrap
        text: viewer.blocking ? qsTr("Has bloqueado esta cuenta") : qsTr("Esta cuenta te ha bloqueado")
        color: Theme.errorColor
    }

    Separator {
        width: parent.width
        color: Theme.primaryColor
        horizontalAlignment: Qt.AlignHCenter
    }
}
