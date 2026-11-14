import QtQuick 2.0
import Sailfish.Silica 1.0
import Bluefish 1.0
import "../components"
import "../js/feed.js" as Feed

// Search: with an empty field it shows what is trending; while typing it lists people, and
// offers searching posts or the hashtag with that text.
Page {
    id: page

    // Main section this page belongs to, for the bottom bar.
    readonly property string navSection: "search"

    property bool loading
    property string error
    readonly property string q: field.text.trim()
    // "#tag" or a single word can be looked up as a hashtag.
    readonly property string tag: /^#?[^\s#]+$/.test(q) ? q.replace(/^#/, "") : ""

    function searchPeople() {
        var query = q
        if (query.replace(/^@/, "").length < 2) {
            loadTrends()
            return
        }
        loading = true
        error = ""
        Bsky.get("app.bsky.actor.searchActors", { q: query.replace(/^@/, ""), limit: 25 }, function(err, data) {
            if (query !== q)
                return
            loading = false
            results.clear()
            if (err) {
                error = err
                return
            }
            var actors = data.actors || []
            for (var i = 0; i < actors.length; i++)
                results.append({ section: qsTr("Personas"), kind: "person", did: actors[i].did,
                                 name: Feed.plain(actors[i].displayName) || actors[i].handle,
                                 detail: "@" + actors[i].handle, avatar: actors[i].avatar || "",
                                 link: "", topic: "" })
        })
    }

    // Trending topics (app.bsky.unspecced.getTrends, or the older getTrendingTopics).
    function loadTrends() {
        if (results.count > 0 && results.get(0).kind === "trend")
            return
        loading = true
        error = ""
        var show = function(items, err) {
            if (q.replace(/^@/, "").length >= 2)
                return
            loading = false
            results.clear()
            if (err)
                error = err
            for (var i = 0; i < items.length; i++) {
                var t = items[i]
                var detail = t.postCount ? qsTr("%1 posts").arg(Feed.count(t.postCount)) : (t.description || "")
                results.append({ section: qsTr("Tendencias"), kind: "trend", did: "",
                                 name: Feed.plain(t.displayName || t.topic), detail: detail,
                                 avatar: "", link: t.link || "", topic: t.topic || "" })
            }
        }
        Bsky.get("app.bsky.unspecced.getTrends", { limit: 15 }, function(err, data) {
            if (!err && data.trends)
                return show(data.trends, "")
            Bsky.get("app.bsky.unspecced.getTrendingTopics", { limit: 15 }, function(err2, data2) {
                show((data2 && data2.topics) || [], err2)
            })
        })
    }

    // A trend links to a feed ("/profile/<did>/feed/<rkey>"); without one, search its text.
    function openTrend(entry) {
        var m = /^\/profile\/([^\/]+)\/feed\/([^\/?#]+)/.exec(entry.link)
        if (m)
            pageStack.push(Qt.resolvedUrl("FeedPage.qml"),
                           { mode: "feed", feedName: entry.name,
                             feedUri: "at://" + m[1] + "/app.bsky.feed.generator/" + m[2] })
        else
            searchPosts(entry.topic || entry.name)
    }

    function searchPosts(text) {
        pageStack.push(Qt.resolvedUrl("FeedPage.qml"), { mode: "search", query: text })
    }

    Component.onCompleted: loadTrends()

    ListModel { id: results }

    Timer {
        id: typing
        interval: 300
        onTriggered: searchPeople()
    }

    SilicaListView {
        id: list
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: navBar.top }
        clip: true
        model: results

        header: Column {
            width: list.width
            PageHeader { title: qsTr("Buscar") }
            SearchField {
                width: parent.width
                placeholderText: qsTr("Personas, posts o #hashtags")
                inputMethodHints: Qt.ImhNoAutoUppercase
                focus: true
                onTextChanged: { field.text = text; typing.restart() }
                EnterKey.iconSource: "image://theme/icon-m-search"
                EnterKey.onClicked: if (q.length > 0) searchPosts(q)
            }
            BackgroundItem {
                width: parent.width
                visible: q.length > 0
                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 2 * x
                    truncationMode: TruncationMode.Fade
                    textFormat: Text.PlainText
                    text: qsTr("Posts con «%1»").arg(q)
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                onClicked: searchPosts(q)
            }
            BackgroundItem {
                width: parent.width
                visible: tag.length > 0
                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 2 * x
                    truncationMode: TruncationMode.Fade
                    textFormat: Text.PlainText
                    text: qsTr("Hashtag #%1").arg(tag)
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                onClicked: searchPosts("#" + tag)
            }
        }

        // Holds the query outside the header so the page and the timer can read it.
        Item { id: field; property string text }

        section.property: "section"
        section.delegate: SectionHeader { text: section }

        delegate: BackgroundItem {
            width: list.width
            height: Theme.itemSizeMedium
            Avatar {
                id: avatar
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                visible: model.kind === "person"
                source: model.avatar
            }
            Column {
                anchors { left: avatar.visible ? avatar.right : parent.left
                          leftMargin: avatar.visible ? Theme.paddingMedium : Theme.horizontalPageMargin
                          right: parent.right; rightMargin: Theme.horizontalPageMargin
                          verticalCenter: parent.verticalCenter }
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
                    text: model.detail
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                }
            }
            onClicked: model.kind === "person" ? app.openProfile(model.did) : openTrend(model)
        }

        footer: Label {
            x: Theme.horizontalPageMargin
            width: list.width - 2 * x
            visible: error.length > 0
            wrapMode: Text.Wrap
            text: error
            color: Theme.errorColor
        }

        ViewPlaceholder {
            enabled: results.count === 0 && !loading && !error && q.length >= 2
            text: qsTr("No hay personas con ese nombre")
        }

        VerticalScrollDecorator {}
    }

    NavBar {
        id: navBar
        anchors.bottom: parent.bottom
        current: page.navSection
    }
}
