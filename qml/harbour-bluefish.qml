import QtQuick 2.0
import QtQuick.LocalStorage 2.0
import Sailfish.Silica 1.0
import Nemo.Notifications 1.0
import Nemo.DBus 2.0
import Nemo.KeepAlive 1.2
import Bluefish 1.0
import "js/feed.js" as Feed

ApplicationWindow {
    id: app

    // Must match OrganizationName.ApplicationName in the .desktop file (Sailjail lets the app
    // own only that name) and the D-Bus service file that starts the app from a notification.
    readonly property string dbusName: "org.jabato.bluefish"
    readonly property string dbusPath: "/org/jabato/bluefish"

    property string myAvatar
    property int unreadNotifications
    property int unreadMessages
    property string activeConvoId     // conversation open on screen: no notifications for it
    property bool polling
    property string pendingTarget     // notification target waiting for the page stack

    initialPage: Bsky.loggedIn ? Qt.resolvedUrl("pages/FeedPage.qml")
                               : Qt.resolvedUrl("pages/LoginPage.qml")
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    Connections {
        target: Bsky
        onSessionExpired: pageStack.replaceAbove(null, Qt.resolvedUrl("pages/LoginPage.qml"),
                                                 { message: qsTr("La sesión ha caducado. Vuelve a iniciar sesión.") })
        onSessionChanged: if (Bsky.loggedIn) loadMe()
    }

    Connections {
        target: pageStack
        onBusyChanged: if (!pageStack.busy && pendingTarget) openTarget(pendingTarget)
    }

    Component.onCompleted: if (Bsky.loggedIn) loadMe()

    // Without D-Bus activation (Harbour build) a notification left behind could not open the
    // app once it is closed, so they go away with it.
    readonly property bool canStartFromNotification: typeof notificationsStartApp === "undefined" || notificationsStartApp
    Component.onDestruction: if (!app.canStartFromNotification) closeNotifications("")

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

    function openChat(convoId, title) {
        pageStack.push(Qt.resolvedUrl("pages/ChatPage.qml"), { convoId: convoId, title: title })
    }

    function webUrl(post) {
        return "https://bsky.app/profile/" + post.authorHandle + "/post/" + post.uri.split("/").pop()
    }

    // Bottom bar: each section replaces the whole page stack.
    function showSection(section) {
        if (pageStack.busy)
            return
        var current = pageStack.currentPage
        if (pageStack.depth === 1 && current && current.navSection === section)
            return
        var pages = {
            home: ["pages/FeedPage.qml", {}],
            feeds: ["pages/FeedsPage.qml", {}],
            messages: ["pages/ConversationsPage.qml", {}],
            search: ["pages/SearchPage.qml", {}],
            notifications: ["pages/NotificationsPage.qml", {}],
            profile: ["pages/FeedPage.qml", { mode: "author", actor: Bsky.did }]
        }
        var p = pages[section]
        if (p)
            pageStack.replaceAbove(null, Qt.resolvedUrl(p[0]), p[1], PageStackAction.Immediate)
    }

    function logout() {
        Bsky.logout()
        myAvatar = ""
        unreadNotifications = 0
        unreadMessages = 0
        closeNotifications("")
        pageStack.replaceAbove(null, Qt.resolvedUrl("pages/LoginPage.qml"))
    }

    function loadMe() {
        Bsky.get("app.bsky.actor.getProfile", { actor: Bsky.did }, function(err, data) {
            if (!err)
                myAvatar = data.avatar || ""
        })
    }

    // ---- Opening the app from a notification ----------------------------------------------

    // Targets: "post:<at-uri>", "convo:<id>|<title>", "profile:<did>" or "notifications".
    // Any program on the session bus can call this, so anything else is ignored.
    function validTarget(target) {
        return /^post:at:\/\/did:[a-z]+:[A-Za-z0-9._:%-]+\/app\.bsky\.feed\.post\/[A-Za-z0-9._:~-]+$/.test(target)
            || /^convo:[A-Za-z0-9_-]{1,128}(\|[^\n]{0,200})?$/.test(target)
            || /^profile:did:[a-z]+:[A-Za-z0-9._:%-]+$/.test(target)
            || target === "notifications"
    }

    function openTarget(target) {
        target = String(target || "")
        if (!validTarget(target))
            return
        app.activate()
        if (pageStack.busy) {
            pendingTarget = target
            return
        }
        pendingTarget = ""
        if (!Bsky.loggedIn)
            return
        if (target.indexOf("post:") === 0) {
            openThread(target.substring(5))
        } else if (target.indexOf("convo:") === 0) {
            var rest = target.substring(6)
            var bar = rest.indexOf("|")
            openChat(bar < 0 ? rest : rest.substring(0, bar), bar < 0 ? "" : rest.substring(bar + 1))
        } else if (target.indexOf("profile:") === 0) {
            openProfile(target.substring(8))
        } else if (target === "notifications") {
            showSection("notifications")
        }
    }

    DBusAdaptor {
        service: app.dbusName
        iface: app.dbusName
        path: app.dbusPath
        xml: '<interface name="org.jabato.bluefish">' +
             '  <method name="openTarget"><arg name="target" type="s" direction="in"/></method>' +
             '</interface>'

        function openTarget(target) {
            app.openTarget(target)
        }
    }

    // ---- Native notifications --------------------------------------------------------------

    // Lists and closes this app's notifications.
    Notification {
        id: notifier
        appName: "Bluefish"
    }

    Component {
        id: notificationComponent
        Notification {
            appName: "Bluefish"
            appIcon: "harbour-bluefish"
            urgency: Notification.Normal
        }
    }

    function iconFile(name) {
        return Qt.resolvedUrl("icons/notify-" + name + ".svg").toString().replace(/^file:\/\//, "")
    }

    function parseDate(iso) {
        var d = new Date((iso || "").replace(/(\.\d{3})\d+/, "$1"))
        return isNaN(d.getTime()) ? new Date() : d
    }

    // With the app on screen the notification only pops up; otherwise it also stays in the
    // Events view until tapped, which opens `target`. Texts come from other people, and the
    // system shows them outside the app's sandbox: they go without markup. `privateBody` keeps
    // the body out of the pop-up, which can show over the lock screen.
    function notify(target, icon, summary, body, when, privateBody) {
        summary = Feed.noMarkup(summary)
        body = Feed.noMarkup(body).substring(0, 300)
        var n = notificationComponent.createObject(app, {
            summary: summary,
            body: body,
            previewSummary: summary,
            previewBody: privateBody ? "" : body,
            icon: iconFile(icon),
            timestamp: parseDate(when),
            isTransient: Qt.application.active,
            remoteActions: [{
                name: "default",
                service: dbusName,
                path: dbusPath,
                iface: dbusName,
                method: "openTarget",
                arguments: [target]
            }]
        })
        n.publish()
    }

    // Closes the notifications whose target starts with `prefix` ("" closes all).
    function closeNotifications(prefix) {
        var list = notifier.notifications()
        for (var i = 0; i < list.length; i++) {
            var actions = list[i].remoteActions || []
            var args = actions.length > 0 ? actions[0].arguments : null
            var target = args && args.length > 0 ? String(args[0]) : ""
            if (target.indexOf(prefix) === 0)
                list[i].close()
        }
    }

    // ---- Polling ---------------------------------------------------------------------------

    // Small key/value store for what has already been notified, per account.
    function db() {
        return LocalStorage.openDatabaseSync("bluefish", "1.0", "Bluefish", 100000)
    }

    function getState(key) {
        var value = ""
        db().transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY, value TEXT)")
            var r = tx.executeSql("SELECT value FROM state WHERE key = ?", [key])
            if (r.rows.length > 0)
                value = r.rows.item(0).value
        })
        return value
    }

    function setState(key, value) {
        db().transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY, value TEXT)")
            tx.executeSql("INSERT OR REPLACE INTO state (key, value) VALUES (?, ?)", [key, value])
        })
    }

    // Checks notifications and messages; `done` is called when both requests have finished.
    function poll(done) {
        if (!Bsky.loggedIn || polling) {
            if (done)
                done()
            return
        }
        polling = true
        var pending = 2
        var finish = function() {
            if (--pending === 0) {
                polling = false
                if (done)
                    done()
            }
        }
        pollNotifications(finish)
        pollMessages(finish)
    }

    // Mentions, likes and reposts not yet read nor notified. The first run only records where
    // things stand, so old activity is not announced.
    function pollNotifications(finish) {
        Bsky.get("app.bsky.notification.listNotifications", { limit: 40 }, function(err, data) {
            if (err)
                return finish()
            var items = data.notifications || []
            var unread = 0
            for (var i = 0; i < items.length; i++)
                if (!items[i].isRead)
                    unread++
            unreadNotifications = unread

            var key = "notified:" + Bsky.did
            var last = getState(key)
            var newest = items.length > 0 ? items[0].indexedAt : ""
            if (!last) {
                setState(key, newest || new Date().toISOString())
                return finish()
            }
            if (newest > last)
                setState(key, newest)

            var fresh = items.filter(function(n) {
                return !n.isRead && n.indexedAt > last
                       && (n.reason === "mention" || n.reason === "like" || n.reason === "repost")
            })
            if (fresh.length === 0)
                return finish()

            var show = function(texts) {
                var shown = fresh.slice(0, 5).reverse()   // oldest first
                for (var j = 0; j < shown.length; j++) {
                    var n = shown[j]
                    var name = Feed.plain(n.author.displayName) || n.author.handle
                    var post = Feed.notificationPost(n)
                    var body = n.reason === "mention" ? Feed.plain(n.record && n.record.text) : (texts[post] || "")
                    var icon = n.reason === "mention" ? "at" : n.reason === "like" ? "heart" : "repost"
                    notify("post:" + post, icon, Feed.notificationText(n.reason, name), body, n.indexedAt)
                }
                if (fresh.length > shown.length)
                    notify("notifications", "bell",
                           qsTr("%1 notificaciones más").arg(fresh.length - shown.length), "", newest)
                finish()
            }

            // Likes and reposts carry only the post's URI: fetch the texts in one call.
            var uris = []
            for (i = 0; i < fresh.length && i < 5; i++) {
                var u = Feed.notificationPost(fresh[i])
                if (fresh[i].reason !== "mention" && u && uris.indexOf(u) < 0)
                    uris.push(u)
            }
            if (uris.length === 0)
                return show({})
            Bsky.get("app.bsky.feed.getPosts", { uris: uris }, function(err2, data2) {
                var texts = {}
                var posts = (data2 && data2.posts) || []
                for (var k = 0; k < posts.length; k++)
                    texts[posts[k].uri] = Feed.plain(posts[k].record && posts[k].record.text)
                show(texts)
            })
        })
    }

    // New direct messages from others in conversations that are not muted.
    function pollMessages(finish) {
        Bsky.get("chat.bsky.convo.listConvos", { limit: 30 }, function(err, data) {
            if (err)   // usually an app password without access to direct messages
                return finish()
            var convos = data.convos || []
            var key = "dm:" + Bsky.did
            var raw = getState(key)
            var first = !raw
            var seen = first ? {} : JSON.parse(raw)
            var unread = 0
            for (var i = 0; i < convos.length; i++) {
                var c = convos[i]
                if (!c.muted)
                    unread += c.unreadCount || 0
                var m = c.lastMessage
                if (!m || !m.id)
                    continue
                var isNew = seen[c.id] !== m.id
                seen[c.id] = m.id
                if (first || !isNew || c.muted || !c.unreadCount
                        || m.$type !== "chat.bsky.convo.defs#messageView"
                        || (m.sender && m.sender.did === Bsky.did)
                        || (c.id === activeConvoId && Qt.application.active))
                    continue
                var sender = null
                for (var j = 0; j < (c.members || []).length; j++)
                    if (m.sender && c.members[j].did === m.sender.did)
                        sender = c.members[j]
                var name = sender ? (Feed.plain(sender.displayName) || sender.handle) : qsTr("Alguien")
                notify("convo:" + c.id + "|" + Feed.convoEntry(c, Bsky.did).title.replace(/\n/g, " ").substring(0, 100), "mail",
                       qsTr("%1 te ha escrito un mensaje privado").arg(name), m.text, m.sentAt, true)
            }
            setState(key, JSON.stringify(seen))
            unreadMessages = unread
            finish()
        })
    }

    // Every 30 s while the app is on screen (and right away when it comes back)...
    Timer {
        interval: 30000
        repeat: true
        triggeredOnStart: true
        running: Bsky.loggedIn && Qt.application.active
        onTriggered: poll()
    }

    // ...and every 2.5 min in the background, waking the device just for the check.
    BackgroundJob {
        id: backgroundJob
        enabled: Bsky.loggedIn && !Qt.application.active
        frequency: BackgroundJob.TwoAndHalfMinutes
        onTriggered: poll(function() { backgroundJob.finished() })
    }
}
