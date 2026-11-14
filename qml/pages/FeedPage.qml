import QtQuick 2.0
import Sailfish.Silica 1.0
import Celeste 1.0
import "../components"
import "../js/feed.js" as Feed

// A list of posts: the home timeline, someone's profile or a post search.
Page {
    id: page

    property string mode: "timeline"   // "timeline", "author" or "search"
    property string actor              // DID or handle, for "author"
    property string query              // for "search"

    property string cursor
    property bool loading
    property bool reachedEnd
    property string error
    property var profile: null

    function render(text, facets) { return Bsky.renderText(text, facets) }

    function request() {
        if (mode === "author")
            return { nsid: "app.bsky.feed.getAuthorFeed",
                     params: { actor: actor, limit: 30, includePins: true, filter: "posts_and_author_threads" } }
        if (mode === "search")
            return { nsid: "app.bsky.feed.searchPosts", params: { q: query, limit: 25, sort: "latest" } }
        return { nsid: "app.bsky.feed.getTimeline", params: { limit: 30 } }
    }

    function load(more) {
        if (loading || (more && (reachedEnd || !cursor)))
            return
        loading = true
        error = ""
        var r = request()
        if (more)
            r.params.cursor = cursor
        Bsky.get(r.nsid, r.params, function(err, data) {
            loading = false
            if (err) {
                error = err
                return
            }
            if (!more)
                posts.clear()
            var items = data.feed || data.posts || []
            for (var i = 0; i < items.length; i++) {
                var entry = mode === "search" ? Feed.modelEntry(items[i], render, {})
                                              : Feed.feedEntry(items[i], render)
                if (entry && !(mode === "search" && JSON.parse(entry.data).hidden))
                    posts.append(entry)
            }
            cursor = data.cursor || ""
            reachedEnd = !data.cursor || items.length === 0
        })
    }

    function loadProfile() {
        Bsky.get("app.bsky.actor.getProfile", { actor: actor }, function(err, data) {
            if (!err)
                profile = data
        })
    }

    function compose(props) {
        var dialog = pageStack.push(Qt.resolvedUrl("ComposePage.qml"), props || {})
        dialog.posted.connect(function() { if (mode === "timeline") load(false) })
    }

    Component.onCompleted: {
        load(false)
        if (mode === "author")
            loadProfile()
    }

    ListModel { id: posts }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: posts

        header: Column {
            width: list.width

            PageHeader {
                title: mode === "timeline" ? qsTr("Siguiendo")
                     : mode === "search" ? query
                     : profile ? (profile.displayName || profile.handle) : ""
                description: mode === "timeline" ? "@" + Bsky.handle
                           : mode === "author" && profile ? "@" + profile.handle : ""
            }

            Loader {
                width: parent.width
                active: mode === "author" && profile !== null
                sourceComponent: ProfileHeader {
                    profile: page.profile
                    onRefreshRequested: loadProfile()
                }
            }
        }

        PullDownMenu {
            busy: loading
            MenuItem {
                text: qsTr("Cerrar sesión")
                visible: mode === "timeline"
                onClicked: Remorse.popupAction(page, qsTr("Cerrando sesión"), function() {
                    Bsky.logout()
                    pageStack.replace(Qt.resolvedUrl("LoginPage.qml"))
                })
            }
            MenuItem {
                text: qsTr("Mi perfil")
                visible: mode === "timeline"
                onClicked: app.openProfile(Bsky.did)
            }
            MenuItem {
                text: qsTr("Buscar")
                visible: mode === "timeline"
                onClicked: pageStack.push(Qt.resolvedUrl("SearchPage.qml"))
            }
            MenuItem {
                text: qsTr("Actualizar")
                onClicked: load(false)
            }
            MenuItem {
                text: mode === "author" && profile && profile.did !== Bsky.did
                      ? qsTr("Mencionar") : qsTr("Nuevo post")
                visible: mode !== "search"
                onClicked: compose(mode === "author" && profile && profile.did !== Bsky.did
                                   ? { initialText: "@" + profile.handle + " " } : {})
            }
        }

        delegate: PostItem {
            width: list.width
            onReplyRequested: compose({ replyTo: post })
            onQuoteRequested: compose({ quoteOf: post })
        }

        footer: Item {
            width: list.width
            height: loading && posts.count > 0 ? Theme.itemSizeLarge : Theme.paddingLarge
            BusyIndicator {
                anchors.centerIn: parent
                size: BusyIndicatorSize.Small
                running: loading && posts.count > 0
            }
        }

        onContentYChanged: {
            if (contentHeight > 0 && contentY + height > contentHeight - 3 * height)
                load(true)
        }

        ViewPlaceholder {
            enabled: posts.count === 0 && !loading
            text: error ? qsTr("No se ha podido cargar") : qsTr("No hay posts")
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
