import QtQuick 2.0
import Sailfish.Silica 1.0
import Bluefish 1.0
import "../js/feed.js" as Feed

// One post in a list. Expects the ListModel roles built by Feed.modelEntry().
ListItem {
    id: item

    readonly property var post: JSON.parse(model.data)
    readonly property bool isPlaceholder: model.placeholder.length > 0
    readonly property real indent: Math.min(model.depth, 3) * Theme.paddingLarge
    property bool showWarned

    signal replyRequested(var post)
    signal quoteRequested(var post)

    contentHeight: isPlaceholder ? placeholderLabel.height + 2 * Theme.paddingMedium
                                 : column.height + 2 * Theme.paddingMedium
    enabled: !isPlaceholder
    menu: isPlaceholder ? null : contextMenu
    onClicked: {
        if (!openLinkAt(bodyLabel, item, mouse) && !model.focused)
            app.openThread(post.uri)
    }

    // The list item takes the tap before the text gets it, so links (mentions, hashtags, web
    // links) are looked up under the finger here. Returns true if a link was opened.
    function openLinkAt(label, source, mouse) {
        if (!label.visible || !label.text)
            return false
        var p = label.mapFromItem(source, mouse.x, mouse.y)
        if (p.x < 0 || p.y < 0 || p.x > label.width || p.y > label.height)
            return false
        var link = label.linkAt(p.x, p.y)
        if (!link)
            return false
        app.openLink(link)
        return true
    }

    function toggleLike() {
        if (model.likeUri === "pending")
            return
        if (model.likeUri) {
            var old = model.likeUri
            model.likeUri = ""
            model.likeCount = Math.max(0, model.likeCount - 1)
            Bsky.post("com.atproto.repo.deleteRecord",
                      { repo: Bsky.did, collection: "app.bsky.feed.like", rkey: Feed.rkey(old) },
                      function(error) { if (error) { model.likeUri = old; model.likeCount++ } })
        } else {
            model.likeUri = "pending"
            model.likeCount++
            Bsky.post("com.atproto.repo.createRecord", {
                          repo: Bsky.did, collection: "app.bsky.feed.like",
                          record: { "$type": "app.bsky.feed.like", subject: { uri: post.uri, cid: post.cid },
                                    createdAt: Bsky.now() }
                      }, function(error, data) {
                          if (error) { model.likeUri = ""; model.likeCount--; return }
                          model.likeUri = data.uri
                      })
        }
    }

    function toggleRepost() {
        if (model.repostUri === "pending")
            return
        if (model.repostUri) {
            var old = model.repostUri
            model.repostUri = ""
            model.repostCount = Math.max(0, model.repostCount - 1)
            Bsky.post("com.atproto.repo.deleteRecord",
                      { repo: Bsky.did, collection: "app.bsky.feed.repost", rkey: Feed.rkey(old) },
                      function(error) { if (error) { model.repostUri = old; model.repostCount++ } })
        } else {
            model.repostUri = "pending"
            model.repostCount++
            Bsky.post("com.atproto.repo.createRecord", {
                          repo: Bsky.did, collection: "app.bsky.feed.repost",
                          record: { "$type": "app.bsky.feed.repost", subject: { uri: post.uri, cid: post.cid },
                                    createdAt: Bsky.now() }
                      }, function(error, data) {
                          if (error) { model.repostUri = ""; model.repostCount--; return }
                          model.repostUri = data.uri
                      })
        }
    }

    Label {
        id: placeholderLabel
        visible: isPlaceholder
        x: Theme.horizontalPageMargin + indent
        y: Theme.paddingMedium
        width: parent.width - x - Theme.horizontalPageMargin
        text: model.placeholder
        color: Theme.secondaryColor
        font.italic: true
    }

    Column {
        id: column
        visible: !isPlaceholder
        x: Theme.horizontalPageMargin + indent
        y: Theme.paddingMedium
        width: parent.width - x - Theme.horizontalPageMargin
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            visible: model.context.length > 0
            textFormat: Text.PlainText
            text: model.context
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
        }

        Item {
            width: parent.width
            height: Math.max(avatar.height, author.height)

            Avatar {
                id: avatar
                source: post.avatar || ""
                MouseArea {
                    anchors.fill: parent
                    onClicked: app.openProfile(post.authorDid)
                }
            }

            Column {
                id: author
                anchors { left: avatar.right; leftMargin: Theme.paddingMedium; right: parent.right }

                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    textFormat: Text.PlainText
                    text: (post.authorName || "") + (post.verified ? " ✓" : "")
                    font.pixelSize: Theme.fontSizeSmall
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    text: "@" + (post.authorHandle || "") + " · " + Feed.timeAgo(post.createdAt)
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                }
            }
        }

        BackgroundItem {
            width: parent.width
            height: warnLabel.height + 2 * Theme.paddingSmall
            visible: post.warning && !showWarned
            onClicked: showWarned = true
            Label {
                id: warnLabel
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.paddingMedium
                wrapMode: Text.Wrap
                text: qsTr("⚠ Aviso de contenido. Toca para verlo.")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Column {
            width: parent.width
            spacing: Theme.paddingSmall
            visible: !post.warning || showWarned

            Label {
                id: bodyLabel
                width: parent.width
                visible: text.length > 0
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                text: post.html || ""
                linkColor: Theme.highlightColor
                font.pixelSize: model.focused ? Theme.fontSizeMedium : Theme.fontSizeSmall
                onLinkActivated: app.openLink(link)
            }

            ImageGrid {
                images: post.images || []
                sensitive: !!post.warnMedia
            }

            BackgroundItem {
                id: videoItem
                width: parent.width
                height: post.video ? width * 9 / 16 : 0
                visible: !!post.video
                onClicked: Qt.openUrlExternally(app.webUrl(post))
                Image {
                    anchors.fill: parent
                    source: post.video ? post.video.thumb : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: width
                    asynchronous: true
                    clip: true
                    opacity: post.warnMedia ? 0.05 : 1
                }
                Icon {
                    anchors.centerIn: parent
                    source: "image://theme/icon-l-play"
                }
            }

            BackgroundItem {
                width: parent.width
                height: post.external ? externalColumn.height + 2 * Theme.paddingSmall : 0
                visible: !!post.external
                onClicked: Qt.openUrlExternally(post.external.uri)
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: Theme.rgba(Theme.secondaryColor, 0.4)
                    radius: Theme.paddingSmall
                }
                Column {
                    id: externalColumn
                    x: Theme.paddingSmall
                    y: Theme.paddingSmall
                    width: parent.width - 2 * x
                    spacing: Theme.paddingSmall
                    Image {
                        width: parent.width
                        height: source != "" ? width / 1.91 : 0
                        source: post.external && !post.warnMedia ? post.external.thumb : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: width
                        asynchronous: true
                        clip: true
                    }
                    Label {
                        width: parent.width
                        textFormat: Text.PlainText
                    text: post.external ? post.external.title : ""
                        visible: text.length > 0
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Label {
                        width: parent.width
                        textFormat: Text.PlainText
                    text: post.external ? post.external.domain : ""
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }
                }
            }

            BackgroundItem {
                id: quoteItem
                width: parent.width
                height: post.quote ? quoteColumn.height + 2 * Theme.paddingMedium : 0
                visible: !!post.quote
                enabled: !!(post.quote && post.quote.uri)
                onClicked: if (!item.openLinkAt(quoteLabel, quoteItem, mouse)) app.openThread(post.quote.uri)
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: Theme.rgba(Theme.secondaryColor, 0.4)
                    radius: Theme.paddingSmall
                }
                Column {
                    id: quoteColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * x
                    spacing: Theme.paddingSmall
                    Label {
                        width: parent.width
                        visible: !!(post.quote && post.quote.unavailable)
                        text: post.quote && post.quote.unavailable ? post.quote.unavailable : ""
                        color: Theme.secondaryColor
                        font.italic: true
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Label {
                        width: parent.width
                        visible: !!(post.quote && post.quote.uri)
                        truncationMode: TruncationMode.Fade
                        textFormat: Text.PlainText
                        text: post.quote && post.quote.uri
                              ? post.quote.authorName + "  @" + post.quote.authorHandle : ""
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryHighlightColor
                    }
                    Label {
                        id: quoteLabel
                        width: parent.width
                        visible: text.length > 0
                        wrapMode: Text.Wrap
                        maximumLineCount: 8
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        text: post.quote && post.quote.html ? post.quote.html : ""
                        linkColor: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        onLinkActivated: app.openLink(link)
                    }
                    ImageGrid {
                        images: post.quote && post.quote.images ? post.quote.images : []
                        sensitive: !!post.warnMedia
                    }
                }
            }
        }

        Row {
            id: actions
            x: -Theme.paddingMedium
            spacing: Theme.paddingLarge

            ActionButton {
                iconSource: "image://theme/icon-m-message-reply"
                count: model.replyCount
                enabled: !post.replyDisabled
                onClicked: item.replyRequested(post)
            }
            ActionButton {
                iconSource: "image://theme/icon-m-repeat"
                count: model.repostCount
                active: model.repostUri.length > 0
                onClicked: toggleRepost()
            }
            ActionButton {
                iconSource: model.likeUri ? "image://theme/icon-m-like" : "image://theme/icon-m-outline-like"
                count: model.likeCount
                active: model.likeUri.length > 0
                onClicked: toggleLike()
            }
        }
    }

    Component {
        id: contextMenu
        ContextMenu {
            MenuItem {
                text: model.repostUri ? qsTr("Deshacer republicación") : qsTr("Republicar")
                onClicked: toggleRepost()
            }
            MenuItem {
                text: qsTr("Citar")
                onClicked: item.quoteRequested(post)
            }
            MenuItem {
                text: qsTr("Ver perfil de %1").arg(post.authorName)
                onClicked: app.openProfile(post.authorDid)
            }
            MenuItem {
                text: qsTr("Copiar enlace")
                onClicked: Clipboard.text = app.webUrl(post)
            }
            MenuItem {
                text: qsTr("Copiar texto")
                visible: (post.text || "").length > 0
                onClicked: Clipboard.text = post.text
            }
            MenuItem {
                text: qsTr("Abrir en el navegador")
                onClicked: Qt.openUrlExternally(app.webUrl(post))
            }
        }
    }
}
