import QtQuick 2.0
import Sailfish.Silica 1.0
import Bluefish 1.0
import "../components"
import "../js/feed.js" as Feed

// A list of posts: the home timeline, a custom feed, a list, someone's profile or a post search.
Page {
    id: page

    // Main section this page belongs to, for the bottom bar.
    readonly property string navSection: mode === "timeline" ? "home" : mode === "author" && actor === Bsky.did ? "profile" : ""

    property string mode: "timeline"   // "timeline", "feed", "list", "author" or "search"
    property string actor              // DID or handle, for "author"
    property string query              // for "search"
    property string feedUri            // feed generator or list AT URI, for "feed" and "list"
    property string feedName

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
        if (mode === "feed")
            return { nsid: "app.bsky.feed.getFeed", params: { feed: feedUri, limit: 30 } }
        if (mode === "list")
            return { nsid: "app.bsky.feed.getListFeed", params: { list: feedUri, limit: 30 } }
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

    readonly property bool otherProfile: mode === "author" && profile !== null && profile.did !== Bsky.did
    readonly property var viewer: (profile && profile.viewer) || {}
    property bool acting
    property string actionError

    // Runs a profile action (block, mute...) and reloads the profile and its posts afterwards.
    function profileAction(nsid, body) {
        acting = true
        actionError = ""
        Bsky.post(nsid, body, function(err) {
            acting = false
            if (err)
                actionError = err
            posts.clear()
            loadProfile()
            load(false)
        })
    }

    function toggleBlock() {
        if (viewer.blocking)
            profileAction("com.atproto.repo.deleteRecord",
                          { repo: Bsky.did, collection: "app.bsky.graph.block", rkey: Feed.rkey(viewer.blocking) })
        else
            profileAction("com.atproto.repo.createRecord", {
                              repo: Bsky.did, collection: "app.bsky.graph.block",
                              record: { "$type": "app.bsky.graph.block", subject: profile.did, createdAt: Bsky.now() }
                          })
    }

    function toggleMute() {
        profileAction(viewer.muted ? "app.bsky.graph.unmuteActor" : "app.bsky.graph.muteActor",
                      { actor: profile.did })
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
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: navBar.top }
        clip: true
        model: posts

        header: Column {
            width: list.width

            PageHeader {
                title: Feed.noMarkup(mode === "timeline" ? qsTr("Siguiendo")
                     : mode === "search" ? query
                     : mode === "feed" || mode === "list" ? feedName
                     : profile ? (profile.displayName || profile.handle) : "")
                description: mode === "timeline" ? "@" + Bsky.handle
                           : mode === "author" && profile ? "@" + profile.handle
                           : mode === "feed" ? qsTr("Feed")
                           : mode === "list" ? qsTr("Lista") : ""
            }

            Loader {
                width: parent.width
                active: mode === "author" && profile !== null
                sourceComponent: ProfileHeader {
                    profile: page.profile
                    actionError: page.actionError
                    onRefreshRequested: loadProfile()
                }
            }
        }

        PullDownMenu {
            busy: loading || acting
            MenuItem {
                text: viewer.blocking ? qsTr("Desbloquear") : qsTr("Bloquear")
                visible: otherProfile
                enabled: !acting
                onClicked: {
                    if (viewer.blocking)
                        toggleBlock()
                    else
                        Remorse.popupAction(page, qsTr("Bloqueando a @%1").arg(profile.handle), toggleBlock)
                }
            }
            MenuItem {
                text: viewer.muted ? qsTr("Dejar de silenciar") : qsTr("Silenciar")
                visible: otherProfile && !viewer.blocking
                enabled: !acting
                onClicked: toggleMute()
            }
            MenuItem {
                text: qsTr("Cerrar sesión")
                visible: mode === "timeline" || navSection === "profile"
                onClicked: Remorse.popupAction(page, qsTr("Cerrando sesión"), function() {
                    app.logout()
                })
            }
            MenuItem {
                text: qsTr("Enviar mensaje")
                visible: otherProfile && !viewer.blocking && !viewer.blockedBy
                         && !(profile.associated && profile.associated.chat
                              && profile.associated.chat.allowIncoming === "none")
                enabled: !acting
                onClicked: {
                    acting = true
                    actionError = ""
                    Bsky.get("chat.bsky.convo.getConvoForMembers", { members: [profile.did] }, function(err, data) {
                        acting = false
                        if (err) { actionError = err; return }
                        pageStack.push(Qt.resolvedUrl("ChatPage.qml"),
                                       { convoId: data.convo.id, title: profile.displayName || profile.handle })
                    })
                }
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
            hintText: Feed.noMarkup(error)
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: loading && posts.count === 0
    }

    NavBar {
        id: navBar
        anchors.bottom: parent.bottom
        current: page.navSection
    }
}
