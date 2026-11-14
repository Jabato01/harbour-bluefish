import QtQuick 2.0
import Sailfish.Silica 1.0
import Bluefish 1.0

// New post, reply (replyTo) or quote (quoteOf). replyTo/quoteOf are objects from Feed.post().
Page {
    id: page

    property var replyTo: null
    property var quoteOf: null
    property string initialText
    property bool sending
    property string error

    readonly property int maxLength: 300
    readonly property int length: Bsky.graphemeCount(editor.text)
    readonly property bool canSend: !sending && editor.text.trim().length > 0 && length <= maxLength

    signal posted()

    function send() {
        sending = true
        error = ""
        var reply = replyTo ? { root: replyTo.root, parent: { uri: replyTo.uri, cid: replyTo.cid } } : {}
        var embed = quoteOf ? { "$type": "app.bsky.embed.record", record: { uri: quoteOf.uri, cid: quoteOf.cid } } : {}
        Bsky.createPost(editor.text, reply, embed, function(err) {
            sending = false
            if (err) {
                error = err
                return
            }
            posted()
            pageStack.pop()
        })
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            busy: sending
            MenuItem {
                text: replyTo ? qsTr("Responder") : qsTr("Publicar")
                enabled: canSend
                onClicked: send()
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: replyTo ? qsTr("Responder") : quoteOf ? qsTr("Citar") : qsTr("Nuevo post")
                // The name is shown as given: replace angle brackets so it can't carry markup.
                description: replyTo ? qsTr("a %1").arg(String(replyTo.authorName || "").replace(/</g, "\u2039").replace(/>/g, "\u203a")) : ""
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !!(replyTo || quoteOf)
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: replyTo ? replyTo.text : quoteOf ? quoteOf.authorName + ": " + quoteOf.text : ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            TextArea {
                id: editor
                width: parent.width
                focus: true
                text: initialText
                placeholderText: replyTo ? qsTr("Escribe tu respuesta") : qsTr("¿Qué está pasando?")
                label: qsTr("%1 de %2").arg(length).arg(maxLength)
                color: length > maxLength ? Theme.errorColor : Theme.primaryColor
                Component.onCompleted: cursorPosition = text.length
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: replyTo ? qsTr("Responder") : qsTr("Publicar")
                enabled: canSend
                onClicked: send()
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                size: BusyIndicatorSize.Small
                running: sending
                visible: sending
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: error.length > 0
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: error
                color: Theme.errorColor
            }
        }
    }
}
