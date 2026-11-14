.pragma library

// Turns Bluesky API views into flat objects the delegates can show. `render` is Bsky.renderText.

var MEDIA_LABELS = ["porn", "sexual", "nudity", "graphic-media", "gore"]

function labelValues(post) {
    var vals = []
    var lists = [post.labels || [], (post.author && post.author.labels) || []]
    for (var i = 0; i < lists.length; i++)
        for (var j = 0; j < lists[i].length; j++)
            if (lists[i][j].val && !lists[i][j].neg)
                vals.push(lists[i][j].val)
    return vals
}

function plain(text) {
    // Strings shown with PlainText still go through here so control characters can't do harm.
    return (text || "").replace(/[\u0000-\u0008\u000b-\u001f]/g, "")
}

function images(embed) {
    var out = []
    var list = (embed && embed.images) || []
    for (var i = 0; i < list.length; i++)
        out.push({ thumb: list[i].thumb || "", fullsize: list[i].fullsize || list[i].thumb || "",
                   alt: plain(list[i].alt),
                   ratio: list[i].aspectRatio && list[i].aspectRatio.height
                          ? list[i].aspectRatio.width / list[i].aspectRatio.height : 0 })
    return out
}

function external(embed) {
    if (!embed || !embed.external)
        return null
    var e = embed.external
    if (!/^https?:\/\//i.test(e.uri || ""))
        return null
    return { uri: e.uri, title: plain(e.title), description: plain(e.description),
             thumb: e.thumb || "", domain: (e.uri.match(/^https?:\/\/([^\/?#]+)/i) || ["", ""])[1] }
}

function video(embed) {
    if (!embed || embed.$type !== "app.bsky.embed.video#view")
        return null
    return { playlist: embed.playlist || "", thumb: embed.thumbnail || "", alt: plain(embed.alt) }
}

function quote(record, render) {
    if (!record)
        return null
    var t = record.$type
    if (t === "app.bsky.embed.record#viewNotFound")
        return { unavailable: qsTr("Post eliminado") }
    if (t === "app.bsky.embed.record#viewBlocked")
        return { unavailable: qsTr("Post bloqueado") }
    if (t === "app.bsky.embed.record#viewDetached")
        return { unavailable: qsTr("El autor ha quitado la cita") }
    if (t !== "app.bsky.embed.record#viewRecord")
        return null   // feeds, lists, starter packs: later
    var value = record.value || {}
    var media = (record.embeds && record.embeds[0]) || null
    return {
        uri: record.uri, cid: record.cid,
        authorDid: record.author.did,
        authorName: plain(record.author.displayName) || record.author.handle,
        authorHandle: record.author.handle,
        avatar: record.author.avatar || "",
        html: render(value.text || "", value.facets || []),
        createdAt: value.createdAt || record.indexedAt,
        images: images(media && media.media ? media.media : media)
    }
}

// postView (app.bsky.feed.defs#postView) -> object for PostItem.
function post(p, render) {
    var record = p.record || {}
    var embed = p.embed || null
    var media = embed
    var quoted = null
    if (embed && embed.$type === "app.bsky.embed.record#view") {
        quoted = quote(embed.record, render)
        media = null
    } else if (embed && embed.$type === "app.bsky.embed.recordWithMedia#view") {
        quoted = quote(embed.record && embed.record.record, render)
        media = embed.media
    }
    var labels = labelValues(p)
    var root = record.reply ? record.reply.root : { uri: p.uri, cid: p.cid }
    var warnMedia = false
    for (var i = 0; i < labels.length; i++)
        if (MEDIA_LABELS.indexOf(labels[i]) >= 0)
            warnMedia = true
    return {
        uri: p.uri, cid: p.cid,
        authorDid: p.author.did,
        authorName: plain(p.author.displayName) || p.author.handle,
        authorHandle: p.author.handle,
        avatar: p.author.avatar || "",
        verified: !!(p.author.verification && p.author.verification.verifiedStatus === "valid"),
        html: render(record.text || "", record.facets || []),
        text: plain(record.text),
        createdAt: record.createdAt || p.indexedAt,
        images: images(media),
        external: external(media),
        video: video(media),
        quote: quoted,
        hidden: labels.indexOf("!hide") >= 0 || labels.indexOf("!takedown") >= 0,
        warning: labels.indexOf("!warn") >= 0,
        warnMedia: warnMedia,
        isReply: !!record.reply,
        root: { uri: root.uri, cid: root.cid },
        replyDisabled: !!(p.viewer && p.viewer.replyDisabled)
    }
}

// Mutable fields go in their own ListModel roles so likes and reposts update in place.
function modelEntry(p, render, extra) {
    var e = {
        data: JSON.stringify(post(p, render)),
        likeUri: (p.viewer && p.viewer.like) || "",
        repostUri: (p.viewer && p.viewer.repost) || "",
        likeCount: p.likeCount || 0,
        repostCount: (p.repostCount || 0) + (p.quoteCount || 0),
        replyCount: p.replyCount || 0,
        context: "", depth: 0, focused: false, placeholder: ""
    }
    for (var k in extra)
        e[k] = extra[k]
    return e
}

// feedViewPost -> model entry, with "reposted by" / "reply to" context.
function feedEntry(item, render) {
    var context = ""
    if (item.reason && item.reason.$type === "app.bsky.feed.defs#reasonRepost")
        context = qsTr("↻ Republicado por %1").arg(plain(item.reason.by.displayName) || item.reason.by.handle)
    else if (item.reason && item.reason.$type === "app.bsky.feed.defs#reasonPin")
        context = qsTr("📌 Fijado")
    else if (item.reply && item.reply.parent && item.reply.parent.author)
        context = qsTr("↳ Respuesta a %1").arg(plain(item.reply.parent.author.displayName)
                                                || item.reply.parent.author.handle)
    var entry = modelEntry(item.post, render, { context: context })
    var p = JSON.parse(entry.data)
    return p.hidden ? null : entry
}

function placeholderFor(node) {
    if (!node)
        return ""
    if (node.$type === "app.bsky.feed.defs#notFoundPost")
        return qsTr("Post no encontrado")
    if (node.$type === "app.bsky.feed.defs#blockedPost")
        return qsTr("Post bloqueado")
    return ""
}

// getPostThread result -> model entries: parents, the post, then replies (indented, 3 levels).
function threadEntries(thread, render) {
    var out = []
    var parents = []
    var node = thread.parent
    while (node) {
        if (node.$type === "app.bsky.feed.defs#threadViewPost")
            parents.unshift(modelEntry(node.post, render, {}))
        else
            parents.unshift({ data: "{}", likeUri: "", repostUri: "", likeCount: 0, repostCount: 0,
                              replyCount: 0, context: "", depth: 0, focused: false,
                              placeholder: placeholderFor(node) })
        node = node.parent
    }
    out = out.concat(parents)
    if (thread.$type !== "app.bsky.feed.defs#threadViewPost") {
        out.push({ data: "{}", likeUri: "", repostUri: "", likeCount: 0, repostCount: 0,
                   replyCount: 0, context: "", depth: 0, focused: true,
                   placeholder: placeholderFor(thread) || qsTr("Post no disponible") })
        return out
    }
    out.push(modelEntry(thread.post, render, { focused: true }))
    function addReplies(n, depth) {
        var replies = n.replies || []
        for (var i = 0; i < replies.length; i++) {
            var r = replies[i]
            if (r.$type !== "app.bsky.feed.defs#threadViewPost")
                continue
            var e = modelEntry(r.post, render, { depth: depth })
            if (JSON.parse(e.data).hidden)
                continue
            out.push(e)
            if (depth < 3)
                addReplies(r, depth + 1)
        }
    }
    addReplies(thread, 1)
    return out
}

function timeAgo(iso) {
    // Records may carry microseconds or no fraction; keep at most milliseconds for the JS parser.
    var d = new Date((iso || "").replace(/(\.\d{3})\d+/, "$1"))
    if (isNaN(d.getTime()))
        return ""
    var s = Math.floor((Date.now() - d.getTime()) / 1000)
    if (s < 60) return qsTr("ahora")
    if (s < 3600) return qsTr("%1 min").arg(Math.floor(s / 60))
    if (s < 86400) return qsTr("%1 h").arg(Math.floor(s / 3600))
    if (s < 7 * 86400) return qsTr("%1 d").arg(Math.floor(s / 86400))
    return d.toLocaleDateString(Qt.locale(), "d MMM yyyy")
}

function count(n) {
    if (n >= 1000000) return (n / 1000000).toFixed(1).replace(/\.0$/, "") + " M"
    if (n >= 10000) return Math.floor(n / 1000) + " k"
    return "" + n
}

function rkey(uri) {
    return uri.split("/").pop()
}
