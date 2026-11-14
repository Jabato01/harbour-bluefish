import QtQuick 2.0
import Sailfish.Silica 1.0
import Bluefish 1.0
import "../components"
import "../js/feed.js" as Feed

// One direct message conversation. New messages are fetched every few seconds while the page
// is open and the app is in the foreground.
Page {
    id: page

    property string convoId
    property string title
    property bool loading
    property bool sending
    property bool request     // a message request the user has not accepted yet
    property string error
    property string cursor
    signal updated()          // read state or messages changed; the list should reload

    function render(text, facets) { return Bsky.renderText(text, facets) }

    function loadConvo() {
        Bsky.get("chat.bsky.convo.getConvo", { convoId: convoId }, function(err, data) {
            if (!err && data.convo)
                request = data.convo.status === "request"
        })
    }

    // Newest messages; with `more`, older ones from the cursor.
    function load(more) {
        if (loading || (more && !cursor))
            return
        loading = true
        var params = { convoId: convoId, limit: more ? 50 : 30 }
        if (more)
            params.cursor = cursor
        Bsky.get("chat.bsky.convo.getMessages", params, function(err, data) {
            loading = false
            if (err) {
                error = err
                return
            }
            error = ""
            var list = data.messages || []   // newest first
            if (more) {
                for (var i = 0; i < list.length; i++)
                    messages.append(Feed.messageEntry(list[i], Bsky.did, render))
                cursor = data.cursor || ""
                return
            }
            // Refresh: add only messages newer than the newest one shown.
            var newest = messages.count > 0 ? messages.get(0).messageId : ""
            var fresh = []
            for (i = 0; i < list.length && list[i].id !== newest; i++)
                fresh.push(Feed.messageEntry(list[i], Bsky.did, render))
            if (messages.count === 0 || fresh.length === list.length) {
                messages.clear()
                for (i = 0; i < fresh.length; i++)
                    messages.append(fresh[i])
                cursor = data.cursor || ""
            } else {
                for (i = fresh.length - 1; i >= 0; i--)
                    messages.insert(0, fresh[i])
            }
            if (fresh.length > 0)
                markRead()
        })
    }

    function markRead() {
        Bsky.post("chat.bsky.convo.updateRead", { convoId: convoId }, function() { page.updated() })
    }

    function send() {
        var text = input.text.trim()
        if (!text || sending)
            return
        sending = true
        Bsky.post("chat.bsky.convo.sendMessage", { convoId: convoId, message: { text: text } },
                  function(err, data) {
            sending = false
            if (err) {
                error = err
                return
            }
            error = ""
            input.text = ""
            request = false
            messages.insert(0, Feed.messageEntry(data, Bsky.did, render))
            page.updated()
        })
    }

    Component.onCompleted: {
        loadConvo()
        load(false)
    }

    // While this conversation is on screen, its messages are not notified and its
    // notifications are cleared.
    onStatusChanged: {
        if (status === PageStatus.Active) {
            app.activeConvoId = convoId
            app.closeNotifications("convo:" + convoId)
        } else if (status === PageStatus.Inactive && app.activeConvoId === convoId) {
            app.activeConvoId = ""
        }
    }
    Component.onDestruction: if (app.activeConvoId === convoId) app.activeConvoId = ""

    Timer {
        interval: 5000
        repeat: true
        running: page.status === PageStatus.Active && Qt.application.active && !loading
        onTriggered: load(false)
    }

    ListModel { id: messages }

    SilicaListView {
        id: list
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: inputRow.top }
        clip: true
        model: messages
        verticalLayoutDirection: ListView.BottomToTop
        spacing: Theme.paddingSmall

        // With BottomToTop the footer is at the top of the screen.
        footer: PageHeader { title: Feed.noMarkup(page.title) }

        delegate: ListItem {
            id: bubble
            width: list.width
            contentHeight: box.height + Theme.paddingSmall
            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Copiar texto")
                    visible: model.text.length > 0
                    onClicked: Clipboard.text = model.text
                }
                MenuItem {
                    text: qsTr("Borrar para mí")
                    onClicked: {
                        var msgId = model.messageId
                        bubble.remorseDelete(function() {
                            Bsky.post("chat.bsky.convo.deleteMessageForSelf",
                                      { convoId: convoId, messageId: msgId }, function(err) {
                                if (err) { error = err; return }
                                for (var i = 0; i < messages.count; i++)
                                    if (messages.get(i).messageId === msgId) { messages.remove(i); break }
                            })
                        })
                    }
                }
            }

            Rectangle {
                id: box
                x: model.mine ? parent.width - width - Theme.horizontalPageMargin : Theme.horizontalPageMargin
                width: Math.min(parent.width * 0.8, Math.max(body.implicitWidth, time.implicitWidth) + 2 * Theme.paddingMedium)
                height: body.height + time.height + 2 * Theme.paddingSmall
                radius: Theme.paddingMedium
                color: model.mine ? Theme.rgba(Theme.highlightBackgroundColor, 0.35)
                                  : Theme.rgba(Theme.secondaryColor, 0.15)

                Label {
                    id: body
                    x: Theme.paddingMedium
                    y: Theme.paddingSmall
                    width: Math.min(implicitWidth, list.width * 0.8 - 2 * Theme.paddingMedium)
                    wrapMode: Text.Wrap
                    textFormat: Text.StyledText
                    text: model.html
                    linkColor: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    onLinkActivated: app.openLink(link)
                }
                Label {
                    id: time
                    anchors { right: parent.right; rightMargin: Theme.paddingMedium; top: body.bottom }
                    text: Feed.timeAgo(model.sentAt)
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.secondaryColor
                }
            }
            onClicked: {
                var p = body.mapFromItem(bubble, mouse.x, mouse.y)
                var link = body.linkAt(p.x, p.y)
                if (link)
                    app.openLink(link)
            }
        }

        onContentYChanged: {
            // BottomToTop: older messages are reached by scrolling up, towards the content end.
            if (contentHeight > height && atYBeginning)
                load(true)
        }

        ViewPlaceholder {
            enabled: messages.count === 0 && !loading
            text: error ? qsTr("No se han podido cargar los mensajes") : qsTr("Todavía no hay mensajes")
            hintText: Feed.noMarkup(error)
        }

        VerticalScrollDecorator {}
    }

    Column {
        id: inputRow
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }

        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: request
            text: qsTr("Aceptar solicitud")
            onClicked: Bsky.post("chat.bsky.convo.acceptConvo", { convoId: convoId }, function(err) {
                if (err) { error = err; return }
                request = false
                page.updated()
            })
        }

        Row {
            width: parent.width

            TextArea {
                id: input
                width: parent.width - sendButton.width
                placeholderText: request ? qsTr("Responde para aceptar la solicitud") : qsTr("Mensaje")
                label: error && messages.count > 0 ? Feed.noMarkup(error) : ""
                labelVisible: label.length > 0
            }
            IconButton {
                id: sendButton
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.paddingLarge
                icon.source: "image://theme/icon-m-send"
                enabled: input.text.trim().length > 0 && !sending
                onClicked: send()
            }
        }
    }
}
