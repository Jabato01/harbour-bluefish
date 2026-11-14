import QtQuick 2.0
import Sailfish.Silica 1.0
import Bluefish 1.0
import "../components"
import "../js/feed.js" as Feed

// Picks someone to write to and opens (or creates) the conversation with them.
Page {
    id: page

    signal chosen(string convoId, string title)

    property bool loading
    property string error
    property string query

    function search() {
        var q = query.trim().replace(/^@/, "")
        if (q.length < 2) {
            people.clear()
            return
        }
        loading = true
        Bsky.get("app.bsky.actor.searchActorsTypeahead", { q: q, limit: 20 }, function(err, data) {
            loading = false
            if (err || q !== query.trim().replace(/^@/, ""))
                return
            people.clear()
            var actors = data.actors || []
            for (var i = 0; i < actors.length; i++) {
                var chat = actors[i].associated && actors[i].associated.chat
                people.append({ did: actors[i].did, handle: actors[i].handle,
                                name: Feed.plain(actors[i].displayName) || actors[i].handle,
                                avatar: actors[i].avatar || "",
                                closed: !!(chat && chat.allowIncoming === "none") })
            }
        })
    }

    function start(did, name) {
        loading = true
        error = ""
        Bsky.get("chat.bsky.convo.getConvoForMembers", { members: [did] }, function(err, data) {
            loading = false
            if (err) {
                error = err
                return
            }
            chosen(data.convo.id, name)
        })
    }

    ListModel { id: people }

    Timer {
        id: typing
        interval: 300
        onTriggered: search()
    }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: people

        header: Column {
            width: list.width
            PageHeader { title: qsTr("Nuevo mensaje") }
            SearchField {
                width: parent.width
                placeholderText: qsTr("¿A quién?")
                inputMethodHints: Qt.ImhNoAutoUppercase
                focus: true
                onTextChanged: { query = text; typing.restart() }
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

        delegate: BackgroundItem {
            width: list.width
            height: Theme.itemSizeMedium
            enabled: !model.closed && !loading
            Avatar {
                id: avatar
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                source: model.avatar
                opacity: model.closed ? Theme.opacityLow : 1
            }
            Column {
                anchors { left: avatar.right; leftMargin: Theme.paddingMedium; right: parent.right
                          rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    textFormat: Text.PlainText
                    text: model.name
                    color: model.closed ? Theme.secondaryColor
                                        : highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    textFormat: Text.PlainText
                    text: "@" + model.handle + (model.closed ? "  · " + qsTr("no acepta mensajes") : "")
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                }
            }
            onClicked: start(model.did, model.name)
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: loading && people.count === 0
    }
}
