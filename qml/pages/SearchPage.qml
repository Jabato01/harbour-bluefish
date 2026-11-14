import QtQuick 2.0
import Sailfish.Silica 1.0
import Celeste 1.0
import "../components"
import "../js/feed.js" as Feed

// Search people as you type; Enter searches posts.
Page {
    id: page

    property bool loading

    function searchPeople(q) {
        if (q.trim().length < 2) {
            people.clear()
            return
        }
        loading = true
        Bsky.get("app.bsky.actor.searchActorsTypeahead", { q: q, limit: 15 }, function(err, data) {
            loading = false
            if (err || q !== field.text)
                return
            people.clear()
            var actors = data.actors || []
            for (var i = 0; i < actors.length; i++)
                people.append({ did: actors[i].did, handle: actors[i].handle,
                                name: Feed.plain(actors[i].displayName) || actors[i].handle,
                                avatar: actors[i].avatar || "" })
        })
    }

    ListModel { id: people }

    Timer {
        id: typing
        interval: 300
        onTriggered: searchPeople(field.text)
    }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: people

        header: Column {
            width: list.width
            PageHeader { title: qsTr("Buscar") }
            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Personas o posts")
                inputMethodHints: Qt.ImhNoAutoUppercase
                focus: true
                onTextChanged: { field.text = text; typing.restart() }
                EnterKey.iconSource: "image://theme/icon-m-search"
                EnterKey.onClicked: if (text.trim().length > 0)
                    pageStack.push(Qt.resolvedUrl("FeedPage.qml"), { mode: "search", query: text.trim() })
            }
            BackgroundItem {
                width: parent.width
                visible: field.text.trim().length > 0
                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 2 * x
                    truncationMode: TruncationMode.Fade
                    text: qsTr("Buscar posts con «%1»").arg(field.text.trim())
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                onClicked: pageStack.push(Qt.resolvedUrl("FeedPage.qml"), { mode: "search", query: field.text.trim() })
            }
        }

        // Holds the query outside the header so delegates and the timer can read it.
        Item { id: field; property string text }

        delegate: BackgroundItem {
            width: list.width
            height: Theme.itemSizeMedium
            Avatar {
                id: avatar
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                source: model.avatar
            }
            Column {
                anchors { left: avatar.right; leftMargin: Theme.paddingMedium; right: parent.right
                          rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    text: model.name
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    text: "@" + model.handle
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                }
            }
            onClicked: app.openProfile(model.did)
        }

        VerticalScrollDecorator {}
    }
}
