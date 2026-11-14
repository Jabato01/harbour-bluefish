import QtQuick 2.0
import Sailfish.Silica 1.0
import Celeste 1.0

ApplicationWindow {
    id: app

    initialPage: Bsky.loggedIn ? Qt.resolvedUrl("pages/FeedPage.qml")
                               : Qt.resolvedUrl("pages/LoginPage.qml")
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    Connections {
        target: Bsky
        onSessionExpired: pageStack.replaceAbove(null, Qt.resolvedUrl("pages/LoginPage.qml"),
                                                 { message: qsTr("La sesión ha caducado. Vuelve a iniciar sesión.") })
    }

    // Links in post text: web links open in the browser, mentions and hashtags inside the app.
    function openLink(link) {
        if (link.indexOf("bsky-mention:") === 0)
            pageStack.push(Qt.resolvedUrl("pages/FeedPage.qml"),
                           { mode: "author", actor: link.substring(13) })
        else if (link.indexOf("bsky-tag:") === 0)
            pageStack.push(Qt.resolvedUrl("pages/FeedPage.qml"),
                           { mode: "search", query: "#" + decodeURIComponent(link.substring(9)) })
        else if (/^https?:\/\//i.test(link))
            Qt.openUrlExternally(link)
    }

    function openProfile(did) {
        pageStack.push(Qt.resolvedUrl("pages/FeedPage.qml"), { mode: "author", actor: did })
    }

    function openThread(uri) {
        pageStack.push(Qt.resolvedUrl("pages/ThreadPage.qml"), { uri: uri })
    }

    function webUrl(post) {
        return "https://bsky.app/profile/" + post.authorHandle + "/post/" + post.uri.split("/").pop()
    }
}
