import QtQuick 2.0
import Sailfish.Silica 1.0
import Bluefish 1.0
import "../components"
import "../js/feed.js" as Feed

// The feeds to choose from: "Siguiendo", Discover, the feeds and lists saved in the account
// preferences (app.bsky.actor.getPreferences) and the lists the user has made.
Page {
    id: page

    // Main section this page belongs to, for the bottom bar.
    readonly property string navSection: "feeds"

    // Bluesky's "Discover" feed generator.
    readonly property string discoverUri: "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"

    property bool loading
    property string error
    property int pending   // requests still running

    function done() {
        if (--pending === 0)
            loading = false
    }

    function add(section, kind, uri, name, description, avatar) {
        for (var i = 0; i < feeds.count; i++)
            if (feeds.get(i).uri === uri && uri)
                return
        // Answers arrive in any order: feeds go before the lists, at the end of their section.
        var at = feeds.count
        if (section === qsTr("Feeds"))
            for (i = 0; i < feeds.count; i++)
                if (feeds.get(i).section !== section) { at = i; break }
        feeds.insert(at, { section: section, kind: kind, uri: uri, name: name,
                           description: description || "", avatar: avatar || "" })
    }

    // Saved feeds, from savedFeedsPrefV2 (current) or savedFeedsPref (older accounts), pinned first.
    function savedFrom(prefs) {
        var saved = []
        for (var i = 0; i < prefs.length; i++) {
            var p = prefs[i]
            if (p.$type === "app.bsky.actor.defs#savedFeedsPrefV2") {
                for (var j = 0; j < (p.items || []).length; j++)
                    saved.push(p.items[j])
                return saved.filter(function(s) { return s.pinned })
                            .concat(saved.filter(function(s) { return !s.pinned }))
            }
        }
        for (i = 0; i < prefs.length; i++) {
            p = prefs[i]
            if (p.$type === "app.bsky.actor.defs#savedFeedsPref") {
                var seen = {}
                var uris = (p.pinned || []).concat(p.saved || [])
                for (j = 0; j < uris.length; j++) {
                    if (seen[uris[j]])
                        continue
                    seen[uris[j]] = true
                    saved.push({ type: uris[j].indexOf("/app.bsky.graph.list/") >= 0 ? "list" : "feed",
                                 value: uris[j] })
                }
            }
        }
        return saved
    }

    function load() {
        feeds.clear()
        error = ""
        loading = true
        pending = 1
        add(qsTr("Feeds"), "timeline", "", qsTr("Siguiendo"), qsTr("Las cuentas que sigues"), "")

        Bsky.get("app.bsky.actor.getPreferences", {}, function(err, data) {
            if (err) {
                error = err
                add(qsTr("Feeds"), "feed", discoverUri, "Discover", "", "")
                done()
                return
            }
            var saved = savedFrom(data.preferences || [])
            var feedUris = [], listUris = []
            for (var i = 0; i < saved.length; i++) {
                if (saved[i].type === "feed")
                    feedUris.push(saved[i].value)
                else if (saved[i].type === "list")
                    listUris.push(saved[i].value)
            }
            if (feedUris.indexOf(discoverUri) < 0)
                feedUris.unshift(discoverUri)
            loadFeeds(feedUris)
            loadLists(listUris)
            done()
        })
    }

    function loadFeeds(uris) {
        pending++
        Bsky.get("app.bsky.feed.getFeedGenerators", { feeds: uris }, function(err, data) {
            var views = (data && data.feeds) || []
            var byUri = {}
            for (var i = 0; i < views.length; i++)
                byUri[views[i].uri] = views[i]
            // Keep the user's order; feeds that no longer exist are left out.
            for (i = 0; i < uris.length; i++) {
                var v = byUri[uris[i]]
                if (v)
                    add(qsTr("Feeds"), "feed", v.uri, Feed.plain(v.displayName),
                        qsTr("de @%1").arg(v.creator.handle), v.avatar)
                else if (uris[i] === discoverUri)
                    add(qsTr("Feeds"), "feed", discoverUri, "Discover", "", "")
            }
            if (err && !error)
                error = err
            done()
        })
    }

    // Saved lists one by one (there is no batch call), then the user's own lists.
    function loadLists(uris) {
        pending++
        var next = function(i) {
            if (i >= uris.length) {
                loadMyLists()
                done()
                return
            }
            Bsky.get("app.bsky.graph.getList", { list: uris[i], limit: 1 }, function(err, data) {
                if (!err && data.list)
                    addList(qsTr("Listas"), data.list)
                next(i + 1)
            })
        }
        next(0)
    }

    function loadMyLists() {
        pending++
        Bsky.get("app.bsky.graph.getLists", { actor: Bsky.did, limit: 100 }, function(err, data) {
            var lists = (data && data.lists) || []
            for (var i = 0; i < lists.length; i++)
                addList(qsTr("Listas"), lists[i])
            done()
        })
    }

    function addList(section, list) {
        // Moderation lists have no feed to read.
        if (list.purpose === "app.bsky.graph.defs#modlist")
            return
        add(section, "list", list.uri, Feed.plain(list.name),
            list.creator && list.creator.did !== Bsky.did ? qsTr("de @%1").arg(list.creator.handle)
                                                           : qsTr("Lista tuya"), list.avatar)
    }

    function open(entry) {
        if (entry.kind === "timeline")
            pageStack.navigateBack()
        else
            pageStack.push(Qt.resolvedUrl("FeedPage.qml"),
                           { mode: entry.kind, feedUri: entry.uri, feedName: entry.name })
    }

    Component.onCompleted: load()

    ListModel { id: feeds }

    SilicaListView {
        id: list
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: navBar.top }
        clip: true
        model: feeds

        header: PageHeader { title: qsTr("Feeds y listas") }

        PullDownMenu {
            busy: loading
            MenuItem {
                text: qsTr("Actualizar")
                onClicked: load()
            }
        }

        section.property: "section"
        section.delegate: SectionHeader { text: section }

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
                    textFormat: Text.PlainText
                    text: model.name
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    visible: text.length > 0
                    truncationMode: TruncationMode.Fade
                    textFormat: Text.PlainText
                    text: model.description
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                }
            }
            onClicked: open(model)
        }

        footer: Label {
            x: Theme.horizontalPageMargin
            width: list.width - 2 * x
            visible: error.length > 0
            wrapMode: Text.Wrap
            text: error
            color: Theme.errorColor
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: loading && feeds.count <= 1
    }

    NavBar {
        id: navBar
        anchors.bottom: parent.bottom
        current: page.navSection
    }
}
