import QtQuick 2.0
import Sailfish.Silica 1.0
import Bluefish 1.0
import "../components"
import "../js/feed.js" as Feed

// Activity on the account (app.bsky.notification.listNotifications). Opening it marks
// everything as seen and clears the app's notifications in the Events view.
Page {
    id: page

    // Main section this page belongs to, for the bottom bar.
    readonly property string navSection: "notifications"

    property bool loading
    property string error
    property string cursor

    function load(more) {
        if (loading || (more && !cursor))
            return
        loading = true
        error = ""
        var params = { limit: 40 }
        if (more)
            params.cursor = cursor
        var startedAt = new Date().toISOString()
        Bsky.get("app.bsky.notification.listNotifications", params, function(err, data) {
            if (err) {
                loading = false
                error = err
                return
            }
            var items = data.notifications || []
            cursor = data.cursor || ""
            // Liked and reposted posts come as URIs only: fetch their texts (25 per call).
            var uris = []
            for (var i = 0; i < items.length; i++) {
                var u = Feed.notificationPost(items[i])
                if (u && items[i].reason !== "mention" && items[i].reason !== "reply"
                        && items[i].reason !== "quote" && uris.indexOf(u) < 0)
                    uris.push(u)
            }
            fetchTexts(uris, {}, function(texts) {
                loading = false
                if (!more)
                    entries.clear()
                for (var j = 0; j < items.length; j++)
                    entries.append(entry(items[j], texts))
                if (!more) {
                    Bsky.post("app.bsky.notification.updateSeen", { seenAt: startedAt }, function() {})
                    app.unreadNotifications = 0
                    app.closeNotifications("post:")
                    app.closeNotifications("notifications")
                }
            })
        })
    }

    function fetchTexts(uris, texts, done) {
        if (uris.length === 0)
            return done(texts)
        Bsky.get("app.bsky.feed.getPosts", { uris: uris.slice(0, 25) }, function(err, data) {
            var posts = (data && data.posts) || []
            for (var i = 0; i < posts.length; i++)
                texts[posts[i].uri] = Feed.plain(posts[i].record && posts[i].record.text)
            fetchTexts(uris.slice(25), texts, done)
        })
    }

    function entry(n, texts) {
        var name = Feed.plain(n.author.displayName) || n.author.handle
        var post = Feed.notificationPost(n)
        var own = n.reason === "mention" || n.reason === "reply" || n.reason === "quote"
                  || n.reason === "subscribed-post"
        var icon = Feed.notificationIcon(n.reason)
        return {
            text: Feed.notificationText(n.reason, name),
            snippet: own ? Feed.plain(n.record && n.record.text) : (texts[post] || ""),
            icon: icon.indexOf("image://") === 0 ? icon : Qt.resolvedUrl("../" + icon).toString(),
            avatar: n.author.avatar || "",
            authorDid: n.author.did,
            post: post,
            unread: !n.isRead,
            when: n.indexedAt
        }
    }

    Component.onCompleted: load(false)

    ListModel { id: entries }

    SilicaListView {
        id: list
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: navBar.top }
        clip: true
        model: entries

        header: PageHeader { title: qsTr("Notificaciones") }

        PullDownMenu {
            busy: loading
            MenuItem {
                text: qsTr("Actualizar")
                onClicked: load(false)
            }
        }

        delegate: ListItem {
            width: list.width
            contentHeight: Math.max(row.height, Theme.itemSizeMedium) + 2 * Theme.paddingMedium

            Rectangle {
                anchors.fill: parent
                visible: model.unread
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
            }

            HighlightImage {
                id: reasonIcon
                x: Theme.horizontalPageMargin
                y: Theme.paddingMedium
                width: Theme.iconSizeSmallPlus
                height: width
                sourceSize.width: width
                sourceSize.height: height
                source: model.icon
                color: Theme.highlightColor
                highlightColor: Theme.highlightColor
            }

            Column {
                id: row
                anchors { left: reasonIcon.right; leftMargin: Theme.paddingMedium
                          right: parent.right; rightMargin: Theme.horizontalPageMargin }
                y: Theme.paddingMedium
                spacing: Theme.paddingSmall

                Avatar {
                    width: Theme.iconSizeSmallPlus
                    source: model.avatar
                    MouseArea {
                        anchors.fill: parent
                        onClicked: app.openProfile(model.authorDid)
                    }
                }
                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: model.text
                    font.pixelSize: Theme.fontSizeSmall
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    visible: text.length > 0
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: model.snippet
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                }
                Label {
                    text: Feed.timeAgo(model.when)
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.secondaryColor
                }
            }

            onClicked: model.post ? app.openThread(model.post) : app.openProfile(model.authorDid)
        }

        onContentYChanged: {
            if (contentHeight > 0 && contentY + height > contentHeight - 2 * height)
                load(true)
        }

        ViewPlaceholder {
            enabled: entries.count === 0 && !loading
            text: error ? qsTr("No se han podido cargar las notificaciones") : qsTr("No hay notificaciones")
            hintText: Feed.noMarkup(error)
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: loading && entries.count === 0
    }

    NavBar {
        id: navBar
        anchors.bottom: parent.bottom
        current: page.navSection
    }
}
