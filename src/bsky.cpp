#include "bsky.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJSEngine>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTextBoundaryFinder>
#include <algorithm>

namespace {

const char *DEFAULT_SERVICE = "https://bsky.social";
const char *PUBLIC_APPVIEW = "https://public.api.bsky.app";
const char *APPVIEW_PROXY = "did:web:api.bsky.app#bsky_appview";
const char *CHAT_PROXY = "did:web:api.bsky.chat#bsky_chat";
const char *USER_AGENT = "harbour-bluefish/0.1 (Sailfish OS)";

const QString MENTION = QStringLiteral("app.bsky.richtext.facet#mention");
const QString LINK = QStringLiteral("app.bsky.richtext.facet#link");
const QString TAG = QStringLiteral("app.bsky.richtext.facet#tag");

int utf8Length(const QString &text, int end)
{
    return text.left(end).toUtf8().size();
}

QVariantMap facet(const QString &text, int start, int end, const QVariantMap &feature)
{
    QVariantMap index;
    index.insert(QStringLiteral("byteStart"), utf8Length(text, start));
    index.insert(QStringLiteral("byteEnd"), utf8Length(text, end));
    QVariantMap f;
    f.insert(QStringLiteral("index"), index);
    f.insert(QStringLiteral("features"), QVariantList() << feature);
    return f;
}

QString escapeSegment(const QString &text)
{
    return text.toHtmlEscaped().replace(QLatin1Char('\n'), QStringLiteral("<br>"));
}

QString encode(const QVariant &value)
{
    return QString::fromLatin1(QUrl::toPercentEncoding(value.toString()));
}

} // namespace

Bsky::Bsky(QJSEngine *engine, QObject *parent)
    : QObject(parent)
    , m_engine(engine)
{
    loadSession();
}

// ---------------------------------------------------------------------------------------------
// Session

QString Bsky::sessionPath() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
            + QStringLiteral("/session.json");
}

void Bsky::loadSession()
{
    QFile file(sessionPath());
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QVariantMap s = QJsonDocument::fromJson(file.readAll()).object().toVariantMap();
    m_did = s.value(QStringLiteral("did")).toString();
    m_handle = s.value(QStringLiteral("handle")).toString();
    m_pds = s.value(QStringLiteral("pds")).toString();
    m_accessJwt = s.value(QStringLiteral("accessJwt")).toString();
    m_refreshJwt = s.value(QStringLiteral("refreshJwt")).toString();
}

void Bsky::saveSession()
{
    QDir().mkpath(QFileInfo(sessionPath()).absolutePath());
    QFile file(sessionPath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return;
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    QJsonObject s;
    s.insert(QStringLiteral("did"), m_did);
    s.insert(QStringLiteral("handle"), m_handle);
    s.insert(QStringLiteral("pds"), m_pds);
    s.insert(QStringLiteral("accessJwt"), m_accessJwt);
    s.insert(QStringLiteral("refreshJwt"), m_refreshJwt);
    file.write(QJsonDocument(s).toJson(QJsonDocument::Compact));
}

void Bsky::clearSession()
{
    m_did.clear();
    m_handle.clear();
    m_pds.clear();
    m_accessJwt.clear();
    m_refreshJwt.clear();
    QFile::remove(sessionPath());
    emit sessionChanged();
}

void Bsky::login(const QString &identifier, const QString &password, const QString &server,
                 const QJSValue &callback)
{
    Done done = toJs(callback);
    QString id = identifier.trimmed();
    if (id.startsWith(QLatin1Char('@')))
        id = id.mid(1);
    if (id.isEmpty() || password.isEmpty()) {
        done(tr("Escribe tu usuario y la contraseña de aplicación"), QVariantMap());
        return;
    }
    // Only app passwords ("abcd-efgh-ijkl-mnop") are sent. The account password gives full
    // control of the account and must never reach a third-party app's requests.
    static const QRegularExpression appPassword(QStringLiteral("^[a-z0-9]{4}(-[a-z0-9]{4}){3}$"),
                                                QRegularExpression::CaseInsensitiveOption);
    if (!appPassword.match(password).hasMatch()) {
        done(tr("Eso no parece una contraseña de aplicación (xxxx-xxxx-xxxx-xxxx). No se ha enviado."),
             QVariantMap());
        return;
    }

    QString base = server.trimmed();
    if (!base.isEmpty()) {
        // The password and the session tokens must never travel unencrypted.
        if (base.startsWith(QLatin1String("http://"), Qt::CaseInsensitive)) {
            done(tr("El servidor tiene que usar https://"), QVariantMap());
            return;
        }
        if (!base.startsWith(QLatin1String("https://"), Qt::CaseInsensitive))
            base.prepend(QLatin1String("https://"));
        const QUrl parsed(base);
        if (!parsed.isValid() || parsed.host().isEmpty() || !parsed.userInfo().isEmpty()) {
            done(tr("La dirección del servidor no es válida"), QVariantMap());
            return;
        }
        while (base.endsWith(QLatin1Char('/')))
            base.chop(1);
        createSession(base, id, password, done);
        return;
    }
    // An e-mail address can only be used on the bsky.social entryway.
    if (id.contains(QLatin1Char('@'))) {
        createSession(QString::fromLatin1(DEFAULT_SERVICE), id, password, done);
        return;
    }
    if (!id.contains(QLatin1Char('.')))
        id += QLatin1String(".bsky.social");

    // handle -> DID -> the account's own PDS. Falls back to bsky.social if resolution fails.
    QUrl url(QString::fromLatin1(PUBLIC_APPVIEW)
             + QStringLiteral("/xrpc/com.atproto.identity.resolveHandle?handle=") + encode(id));
    getUrl(url, [this, id, password, done](const QString &error, const QVariantMap &data) {
        const QString did = data.value(QStringLiteral("did")).toString();
        if (!error.isEmpty() || did.isEmpty()) {
            createSession(QString::fromLatin1(DEFAULT_SERVICE), id, password, done);
            return;
        }
        resolvePds(did, [this, id, password, done](const QString &pds) {
            createSession(pds.isEmpty() ? QString::fromLatin1(DEFAULT_SERVICE) : pds,
                          id, password, done);
        });
    });
}

void Bsky::createSession(const QString &base, const QString &identifier, const QString &password,
                         Done done)
{
    QVariantMap body;
    body.insert(QStringLiteral("identifier"), identifier);
    body.insert(QStringLiteral("password"), password);
    postUrl(QUrl(base + QStringLiteral("/xrpc/com.atproto.server.createSession")), body, QString(),
            [this, base, done](const QString &error, const QVariantMap &data) {
        if (!error.isEmpty()) {
            done(error, data);
            return;
        }
        if (data.contains(QStringLiteral("active")) && !data.value(QStringLiteral("active")).toBool()) {
            const QString status = data.value(QStringLiteral("status")).toString();
            done(status == QLatin1String("takendown") ? tr("Esta cuenta ha sido suspendida")
                 : status == QLatin1String("suspended") ? tr("Esta cuenta está suspendida temporalmente")
                 : tr("Esta cuenta está desactivada"), QVariantMap());
            return;
        }
        const QString pds = pdsFromDidDoc(data.value(QStringLiteral("didDoc")).toMap());
        m_pds = pds.isEmpty() ? base : pds;
        m_did = data.value(QStringLiteral("did")).toString();
        m_handle = data.value(QStringLiteral("handle")).toString();
        m_accessJwt = data.value(QStringLiteral("accessJwt")).toString();
        m_refreshJwt = data.value(QStringLiteral("refreshJwt")).toString();
        saveSession();
        emit sessionChanged();
        done(QString(), QVariantMap());
    });
}

void Bsky::logout()
{
    if (!m_refreshJwt.isEmpty() && !m_pds.isEmpty()) {
        // Best effort: revoke the session on the server.
        postUrl(QUrl(m_pds + QStringLiteral("/xrpc/com.atproto.server.deleteSession")),
                QVariantMap(), m_refreshJwt, [](const QString &, const QVariantMap &) {});
    }
    clearSession();
}

void Bsky::resolvePds(const QString &did, std::function<void(QString)> done)
{
    QUrl url;
    if (did.startsWith(QLatin1String("did:plc:"))) {
        url = QUrl(QStringLiteral("https://plc.directory/") + did);
    } else if (did.startsWith(QLatin1String("did:web:"))) {
        const QString host = QUrl::fromPercentEncoding(did.mid(8).toUtf8());
        url = QUrl(QStringLiteral("https://") + host + QStringLiteral("/.well-known/did.json"));
    } else {
        done(QString());
        return;
    }
    getUrl(url, [done](const QString &error, const QVariantMap &doc) {
        done(error.isEmpty() ? pdsFromDidDoc(doc) : QString());
    });
}

QString Bsky::pdsFromDidDoc(const QVariantMap &doc)
{
    const QVariantList services = doc.value(QStringLiteral("service")).toList();
    for (const QVariant &v : services) {
        const QVariantMap s = v.toMap();
        if (s.value(QStringLiteral("id")).toString().endsWith(QLatin1String("#atproto_pds"))
                && s.value(QStringLiteral("type")).toString() == QLatin1String("AtprotoPersonalDataServer")) {
            QString endpoint = s.value(QStringLiteral("serviceEndpoint")).toString();
            while (endpoint.endsWith(QLatin1Char('/')))
                endpoint.chop(1);
            if (endpoint.startsWith(QLatin1String("https://")))
                return endpoint;
        }
    }
    return QString();
}

// ---------------------------------------------------------------------------------------------
// XRPC

Bsky::Done Bsky::toJs(const QJSValue &callback)
{
    QJSEngine *engine = m_engine;
    return [engine, callback](const QString &error, const QVariantMap &data) {
        if (!callback.isCallable())
            return;
        QJSValue cb(callback);
        cb.call(QJSValueList() << QJSValue(error) << engine->toScriptValue(QVariant(data)));
    };
}

void Bsky::get(const QString &nsid, const QVariantMap &params, const QJSValue &callback)
{
    call(QStringLiteral("GET"), nsid, params, QVariantMap(), toJs(callback));
}

void Bsky::post(const QString &nsid, const QVariantMap &body, const QJSValue &callback)
{
    call(QStringLiteral("POST"), nsid, QVariantMap(), body, toJs(callback));
}

void Bsky::call(const QString &method, const QString &nsid, const QVariantMap &params,
                const QVariantMap &body, Done done)
{
    if (!loggedIn()) {
        done(tr("No has iniciado sesión"), QVariantMap());
        return;
    }
    Call c;
    c.method = method;
    c.nsid = nsid;
    c.params = params;
    if (method == QLatin1String("POST"))
        c.body = QJsonDocument(QJsonObject::fromVariantMap(body)).toJson(QJsonDocument::Compact);
    c.done = done;
    if (m_refreshing)
        m_waiting.append(c);
    else
        send(c);
}

QUrl Bsky::xrpcUrl(const QString &nsid, const QVariantMap &params) const
{
    QStringList query;
    for (auto it = params.constBegin(); it != params.constEnd(); ++it) {
        const QVariant &value = it.value();
        if (value.type() == QVariant::List || value.type() == QVariant::StringList) {
            for (const QVariant &item : value.toList())
                query << it.key() + QLatin1Char('=') + encode(item);
        } else if (!value.isNull() && !value.toString().isEmpty()) {
            query << it.key() + QLatin1Char('=') + encode(value);
        }
    }
    QString url = m_pds + QStringLiteral("/xrpc/") + nsid;
    if (!query.isEmpty())
        url += QLatin1Char('?') + query.join(QLatin1Char('&'));
    return QUrl(url);
}

QNetworkRequest Bsky::request(const QUrl &url, const QString &bearer) const
{
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QByteArray(USER_AGENT));
    // No redirects: a redirect could carry the session token or the password to another host.
    // Only the unauthenticated GET lookups in getUrl() follow them.
    if (!bearer.isEmpty())
        req.setRawHeader("Authorization", "Bearer " + bearer.toUtf8());
    return req;
}

void Bsky::send(const Call &c)
{
    QNetworkRequest req = request(xrpcUrl(c.nsid, c.params), m_accessJwt);
    if (c.nsid.startsWith(QLatin1String("app.bsky.")))
        req.setRawHeader("atproto-proxy", APPVIEW_PROXY);
    else if (c.nsid.startsWith(QLatin1String("chat.bsky.")))
        req.setRawHeader("atproto-proxy", CHAT_PROXY);

    QNetworkReply *reply;
    if (c.method == QLatin1String("POST")) {
        req.setHeader(QNetworkRequest::ContentTypeHeader, QByteArray("application/json"));
        reply = m_net.post(req, c.body);
    } else {
        reply = m_net.get(req);
    }
    connect(reply, &QNetworkReply::finished, this, [this, reply, c]() { finishCall(reply, c); });
}

void Bsky::finishCall(QNetworkReply *reply, Call c)
{
    reply->deleteLater();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QVariantMap json = QJsonDocument::fromJson(reply->readAll()).object().toVariantMap();

    if (status >= 200 && status < 300) {
        c.done(QString(), json);
        return;
    }
    const QString error = json.value(QStringLiteral("error")).toString();
    if ((status == 400 || status == 401) && error == QLatin1String("ExpiredToken") && !c.retried) {
        c.retried = true;
        m_waiting.append(c);
        refreshSession();
        return;
    }
    c.done(errorText(status, json, reply), json);
}

void Bsky::refreshSession()
{
    if (m_refreshing)
        return;
    m_refreshing = true;
    postUrl(QUrl(m_pds + QStringLiteral("/xrpc/com.atproto.server.refreshSession")), QVariantMap(),
            m_refreshJwt, [this](const QString &error, const QVariantMap &data) {
        m_refreshing = false;
        QList<Call> waiting = m_waiting;
        m_waiting.clear();
        const QString access = data.value(QStringLiteral("accessJwt")).toString();
        if (error.isEmpty() && !access.isEmpty()) {
            m_accessJwt = access;
            m_refreshJwt = data.value(QStringLiteral("refreshJwt")).toString();
            if (!data.value(QStringLiteral("handle")).toString().isEmpty())
                m_handle = data.value(QStringLiteral("handle")).toString();
            const QString pds = pdsFromDidDoc(data.value(QStringLiteral("didDoc")).toMap());
            if (!pds.isEmpty())
                m_pds = pds;
            saveSession();
            emit sessionChanged();
            for (const Call &c : waiting)
                send(c);
            return;
        }
        const QString code = data.value(QStringLiteral("error")).toString();
        const bool expired = code == QLatin1String("ExpiredToken") || code == QLatin1String("InvalidToken")
                || code == QLatin1String("AuthenticationRequired");
        if (expired) {
            clearSession();
            emit sessionExpired();
        }
        const QString message = expired ? tr("La sesión ha caducado. Vuelve a iniciar sesión.") : error;
        for (const Call &c : waiting)
            c.done(message, QVariantMap());
    });
}

void Bsky::getUrl(const QUrl &url, Done done)
{
    // Public handle and DID document lookups: no credentials, and Qt refuses https -> http.
    QNetworkRequest req = request(url, QString());
    req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    QNetworkReply *reply = m_net.get(req);
    connect(reply, &QNetworkReply::finished, this, [reply, done]() {
        reply->deleteLater();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QVariantMap json = QJsonDocument::fromJson(reply->readAll()).object().toVariantMap();
        if (status >= 200 && status < 300)
            done(QString(), json);
        else
            done(errorText(status, json, reply), json);
    });
}

void Bsky::postUrl(const QUrl &url, const QVariantMap &body, const QString &bearer, Done done)
{
    QNetworkRequest req = request(url, bearer);
    QByteArray data;
    if (!body.isEmpty()) {
        req.setHeader(QNetworkRequest::ContentTypeHeader, QByteArray("application/json"));
        data = QJsonDocument(QJsonObject::fromVariantMap(body)).toJson(QJsonDocument::Compact);
    }
    QNetworkReply *reply = m_net.post(req, data);
    connect(reply, &QNetworkReply::finished, this, [reply, done]() {
        reply->deleteLater();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QVariantMap json = QJsonDocument::fromJson(reply->readAll()).object().toVariantMap();
        if (status >= 200 && status < 300)
            done(QString(), json);
        else
            done(errorText(status, json, reply), json);
    });
}

QString Bsky::errorText(int status, const QVariantMap &json, QNetworkReply *reply)
{
    const QString code = json.value(QStringLiteral("error")).toString();
    const QString message = json.value(QStringLiteral("message")).toString();
    if (status == 0)
        return tr("Sin conexión: %1").arg(reply->errorString());
    if (code == QLatin1String("AuthFactorTokenRequired"))
        return tr("Tu cuenta pide un código por correo. Usa una contraseña de aplicación.");
    if (code == QLatin1String("AuthenticationRequired") && status == 401
            && reply->url().path().endsWith(QLatin1String("createSession")))
        return tr("Usuario o contraseña incorrectos");
    if (status == 429)
        return tr("Demasiadas peticiones. Espera un poco y vuelve a intentarlo.");
    if (!message.isEmpty())
        return message;
    if (!code.isEmpty())
        return code;
    return tr("Error %1 del servidor").arg(status);
}

// ---------------------------------------------------------------------------------------------
// Posting

void Bsky::createPost(const QString &text, const QVariantMap &reply, const QVariantMap &embed,
                      const QJSValue &callback)
{
    Done done = toJs(callback);
    resolveMentions(detectFacets(text), 0, [this, text, reply, embed, done](const QVariantList &facets) {
        QVariantMap record;
        record.insert(QStringLiteral("$type"), QStringLiteral("app.bsky.feed.post"));
        record.insert(QStringLiteral("text"), text);
        record.insert(QStringLiteral("createdAt"), now());
        const QString lang = QLocale::system().name().section(QLatin1Char('_'), 0, 0);
        if (!lang.isEmpty() && lang != QLatin1String("C"))
            record.insert(QStringLiteral("langs"), QVariantList() << lang);
        if (!facets.isEmpty())
            record.insert(QStringLiteral("facets"), facets);
        if (!reply.isEmpty())
            record.insert(QStringLiteral("reply"), reply);
        if (!embed.isEmpty())
            record.insert(QStringLiteral("embed"), embed);

        QVariantMap body;
        body.insert(QStringLiteral("repo"), m_did);
        body.insert(QStringLiteral("collection"), QStringLiteral("app.bsky.feed.post"));
        body.insert(QStringLiteral("record"), record);
        call(QStringLiteral("POST"), QStringLiteral("com.atproto.repo.createRecord"), QVariantMap(),
             body, done);
    });
}

// Mentions come out of detectFacets() with a "handle"; this swaps it for the DID, dropping
// mentions of handles that don't exist.
void Bsky::resolveMentions(QVariantList facets, int index, std::function<void(QVariantList)> done)
{
    while (index < facets.size()) {
        const QVariantMap feature = facets.at(index).toMap().value(QStringLiteral("features"))
                .toList().value(0).toMap();
        if (feature.value(QStringLiteral("$type")).toString() == MENTION)
            break;
        ++index;
    }
    if (index >= facets.size()) {
        done(facets);
        return;
    }
    QVariantMap f = facets.at(index).toMap();
    QVariantMap feature = f.value(QStringLiteral("features")).toList().value(0).toMap();
    const QString handle = feature.take(QStringLiteral("handle")).toString();
    QVariantMap params;
    params.insert(QStringLiteral("handle"), handle);
    call(QStringLiteral("GET"), QStringLiteral("com.atproto.identity.resolveHandle"), params,
         QVariantMap(), [this, facets, index, f, feature, done](const QString &error,
                                                              const QVariantMap &data) mutable {
        const QString did = data.value(QStringLiteral("did")).toString();
        if (error.isEmpty() && !did.isEmpty()) {
            feature.insert(QStringLiteral("did"), did);
            f.insert(QStringLiteral("features"), QVariantList() << feature);
            facets[index] = f;
            resolveMentions(facets, index + 1, done);
        } else {
            facets.removeAt(index);
            resolveMentions(facets, index, done);
        }
    });
}

QVariantList Bsky::detectFacets(const QString &text)
{
    QVariantList result;

    static const QRegularExpression mentionRe(QStringLiteral(
        "(^|\\s|\\()(@)([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+)"));
    auto it = mentionRe.globalMatch(text);
    while (it.hasNext()) {
        const QRegularExpressionMatch m = it.next();
        QString handle = m.captured(3).toLower();
        // A TLD made of digits only is not a handle (e.g. "@1.5").
        if (QRegularExpression(QStringLiteral("^[0-9]+$")).match(handle.section(QLatin1Char('.'), -1)).hasMatch())
            continue;
        QVariantMap feature;
        feature.insert(QStringLiteral("$type"), MENTION);
        feature.insert(QStringLiteral("did"), QString());
        feature.insert(QStringLiteral("handle"), handle);
        result << facet(text, m.capturedStart(2), m.capturedEnd(3), feature);
    }

    static const QRegularExpression urlRe(QStringLiteral(
        "(^|\\s|\\()((https?://|www\\.)[^\\s<>\"]+)"), QRegularExpression::CaseInsensitiveOption);
    it = urlRe.globalMatch(text);
    while (it.hasNext()) {
        const QRegularExpressionMatch m = it.next();
        QString url = m.captured(2);
        int end = m.capturedEnd(2);
        for (;;) {
            const QChar last = url.isEmpty() ? QChar() : url.at(url.size() - 1);
            const bool unbalanced = last == QLatin1Char(')') && url.count(QLatin1Char('(')) < url.count(QLatin1Char(')'));
            if (QStringLiteral(".,;:!?\"'").contains(last) || unbalanced) {
                url.chop(1);
                --end;
            } else {
                break;
            }
        }
        QString uri = url.startsWith(QLatin1String("www."), Qt::CaseInsensitive)
                ? QStringLiteral("https://") + url : url;
        const QUrl parsed(uri);
        if (!parsed.isValid() || !parsed.host().contains(QLatin1Char('.')))
            continue;
        QVariantMap feature;
        feature.insert(QStringLiteral("$type"), LINK);
        feature.insert(QStringLiteral("uri"), uri);
        result << facet(text, m.capturedStart(2), end, feature);
    }

    static const QRegularExpression tagRe(QStringLiteral("(^|\\s)([#\\x{FF03}])([^\\s#\\x{FF03}]+)"));
    it = tagRe.globalMatch(text);
    while (it.hasNext()) {
        const QRegularExpressionMatch m = it.next();
        QString tag = m.captured(3);
        int end = m.capturedEnd(3);
        while (!tag.isEmpty() && QStringLiteral(".,;:!?)\"'").contains(tag.at(tag.size() - 1))) {
            tag.chop(1);
            --end;
        }
        if (tag.isEmpty() || tag.size() > 64
                || QRegularExpression(QStringLiteral("^[0-9]+$")).match(tag).hasMatch())
            continue;
        QVariantMap feature;
        feature.insert(QStringLiteral("$type"), TAG);
        feature.insert(QStringLiteral("tag"), tag);
        result << facet(text, m.capturedStart(2), end, feature);
    }

    std::sort(result.begin(), result.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("index")).toMap().value(QStringLiteral("byteStart")).toInt()
             < b.toMap().value(QStringLiteral("index")).toMap().value(QStringLiteral("byteStart")).toInt();
    });
    return result;
}

// ---------------------------------------------------------------------------------------------
// Rendering

QString Bsky::renderText(const QString &text, const QVariantList &facets) const
{
    return renderHtml(text, facets);
}

QString Bsky::renderHtml(const QString &text, const QVariantList &facets)
{
    struct Span { int start; int end; QString href; };
    QList<Span> spans;
    for (const QVariant &v : facets) {
        const QVariantMap f = v.toMap();
        const QVariantMap index = f.value(QStringLiteral("index")).toMap();
        const QVariantMap feature = f.value(QStringLiteral("features")).toList().value(0).toMap();
        const QString type = feature.value(QStringLiteral("$type")).toString();
        Span s;
        s.start = index.value(QStringLiteral("byteStart")).toInt();
        s.end = index.value(QStringLiteral("byteEnd")).toInt();
        if (type == LINK) {
            const QString uri = feature.value(QStringLiteral("uri")).toString();
            if (!uri.startsWith(QLatin1String("https://"), Qt::CaseInsensitive)
                    && !uri.startsWith(QLatin1String("http://"), Qt::CaseInsensitive))
                continue;
            s.href = QString::fromLatin1(QUrl(uri).toEncoded());
        } else if (type == MENTION) {
            s.href = QStringLiteral("bsky-mention:") + feature.value(QStringLiteral("did")).toString();
        } else if (type == TAG) {
            s.href = QStringLiteral("bsky-tag:") + encode(feature.value(QStringLiteral("tag")));
        } else {
            continue;
        }
        spans << s;
    }
    std::sort(spans.begin(), spans.end(), [](const Span &a, const Span &b) { return a.start < b.start; });

    const QByteArray bytes = text.toUtf8();
    QString html;
    int pos = 0;
    for (const Span &s : spans) {
        if (s.start < pos || s.end <= s.start || s.end > bytes.size())
            continue;   // overlapping or out of range: leave as plain text
        html += escapeSegment(QString::fromUtf8(bytes.mid(pos, s.start - pos)));
        html += QStringLiteral("<a href=\"") + s.href.toHtmlEscaped() + QStringLiteral("\">")
                + escapeSegment(QString::fromUtf8(bytes.mid(s.start, s.end - s.start)))
                + QStringLiteral("</a>");
        pos = s.end;
    }
    html += escapeSegment(QString::fromUtf8(bytes.mid(pos)));
    return html;
}

int Bsky::graphemeCount(const QString &text) const
{
    QTextBoundaryFinder finder(QTextBoundaryFinder::Grapheme, text);
    int count = 0;
    while (finder.toNextBoundary() != -1)
        ++count;
    return count;
}

QString Bsky::now() const
{
    return QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyy-MM-dd'T'HH:mm:ss.zzz'Z'"));
}
