import QtQuick 2.0
import Sailfish.Silica 1.0
import Bluefish 1.0
import "../components"
import "../js/feed.js" as Feed

// Direct message conversations (chat.bsky.convo.listConvos), newest first.
Page {
    id: page

    // Main section this page belongs to, for the bottom bar.
    readonly property string navSection: "messages"

    property bool loading
    property string error
    property string cursor

    function load(more) {
        if (loading || (more && !cursor))
            return
        loading = true
        error = ""
        var params = { limit: 30 }
        if (more)
            params.cursor = cursor
        Bsky.get("chat.bsky.convo.listConvos", params, function(err, data) {
            loading = false
            if (err) {
                error = err
                return
            }
            if (!more)
                convos.clear()
            var list = data.convos || []
            if (!more) {
                var unread = 0
                for (var j = 0; j < list.length; j++)
                    if (!list[j].muted)
                        unread += list[j].unreadCount || 0
                app.unreadMessages = unread
            }
            for (var i = 0; i < list.length; i++)
                convos.append(Feed.convoEntry(list[i], Bsky.did))
            cursor = data.cursor || ""
        })
    }

    function openChat(convoId, title) {
        var chat = pageStack.push(Qt.resolvedUrl("ChatPage.qml"), { convoId: convoId, title: title })
        chat.updated.connect(function() { load(false) })
    }

    Component.onCompleted: load(false)

    ListModel { id: convos }

    SilicaListView {
        id: list
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: navBar.top }
        clip: true
        model: convos

        header: PageHeader { title: qsTr("Mensajes") }

        PullDownMenu {
            busy: loading
            MenuItem {
                text: qsTr("Nuevo mensaje")
                onClicked: {
                    var picker = pageStack.push(Qt.resolvedUrl("NewMessagePage.qml"))
                    picker.chosen.connect(function(convoId, title) {
                        pageStack.pop(page, PageStackAction.Immediate)
                        openChat(convoId, title)
                    })
                }
            }
            MenuItem {
                text: qsTr("Actualizar")
                onClicked: load(false)
            }
        }

        delegate: ListItem {
            width: list.width
            contentHeight: Theme.itemSizeLarge
            Avatar {
                id: avatar
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                source: model.avatar
            }
            Column {
                anchors { left: avatar.right; leftMargin: Theme.paddingMedium
                          right: badge.left; rightMargin: Theme.paddingMedium
                          verticalCenter: parent.verticalCenter }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    textFormat: Text.PlainText
                    text: model.title + (model.request ? "  · " + qsTr("Solicitud") : "")
                    font.bold: model.unread > 0
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    textFormat: Text.PlainText
                    text: model.preview
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: model.unread > 0 ? Theme.highlightColor : Theme.secondaryColor
                }
            }
            Label {
                id: badge
                anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin
                          verticalCenter: parent.verticalCenter }
                text: model.unread > 0 ? model.unread : Feed.timeAgo(model.sentAt)
                font.pixelSize: Theme.fontSizeExtraSmall
                color: model.unread > 0 ? Theme.highlightColor : Theme.secondaryColor
            }
            onClicked: openChat(model.convoId, model.title)
        }

        onContentYChanged: {
            if (contentHeight > 0 && contentY + height > contentHeight - 2 * height)
                load(true)
        }

        ViewPlaceholder {
            enabled: convos.count === 0 && !loading
            text: error ? qsTr("No se han podido cargar los mensajes") : qsTr("No hay conversaciones")
            // Usual cause: an app password created without access to direct messages.
            hintText: error ? Feed.noMarkup(error) + "\n\n" + qsTr("Comprueba que la contraseña de aplicación tiene activado el acceso a mensajes directos.") : ""
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: loading && convos.count === 0
    }

    NavBar {
        id: navBar
        anchors.bottom: parent.bottom
        current: page.navSection
    }
}
