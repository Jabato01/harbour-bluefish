import QtQuick 2.0
import Sailfish.Silica 1.0
import Celeste 1.0
import "../components"
import "../js/feed.js" as Feed

Page {
    id: page

    property string uri
    property bool loading
    property string error

    function render(text, facets) { return Bsky.renderText(text, facets) }

    function load() {
        loading = true
        error = ""
        Bsky.get("app.bsky.feed.getPostThread", { uri: uri, depth: 6, parentHeight: 80 }, function(err, data) {
            loading = false
            if (err) {
                error = err
                return
            }
            posts.clear()
            var entries = Feed.threadEntries(data.thread, render)
            var focus = 0
            for (var i = 0; i < entries.length; i++) {
                if (entries[i].focused)
                    focus = i
                posts.append(entries[i])
            }
            list.positionViewAtIndex(focus, ListView.Beginning)
        })
    }

    function compose(props) {
        var p = pageStack.push(Qt.resolvedUrl("ComposePage.qml"), props)
        p.posted.connect(load)
    }

    Component.onCompleted: load()

    ListModel { id: posts }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: posts
        header: PageHeader { title: qsTr("Hilo") }

        PullDownMenu {
            busy: loading
            MenuItem {
                text: qsTr("Actualizar")
                onClicked: load()
            }
        }

        delegate: PostItem {
            width: list.width
            onReplyRequested: compose({ replyTo: post })
            onQuoteRequested: compose({ quoteOf: post })
        }

        ViewPlaceholder {
            enabled: posts.count === 0 && !loading
            text: qsTr("No se ha podido cargar el hilo")
            hintText: error
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: loading && posts.count === 0
    }
}
