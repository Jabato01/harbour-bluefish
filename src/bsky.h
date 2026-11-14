#ifndef BSKY_H
#define BSKY_H

#include <QObject>
#include <QJSValue>
#include <QList>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QUrl>
#include <QVariantMap>
#include <functional>

class QJSEngine;
class QNetworkReply;

// Client for one Bluesky (AT Protocol) account: login with an app password, session storage and
// refresh, and XRPC calls. QML calls get()/post() with a callback(error, data); error is "" on
// success.
class Bsky : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool loggedIn READ loggedIn NOTIFY sessionChanged)
    Q_PROPERTY(QString did READ did NOTIFY sessionChanged)
    Q_PROPERTY(QString handle READ handle NOTIFY sessionChanged)
    Q_PROPERTY(QString pds READ pds NOTIFY sessionChanged)

public:
    typedef std::function<void(const QString &error, const QVariantMap &data)> Done;

    explicit Bsky(QJSEngine *engine, QObject *parent = nullptr);

    bool loggedIn() const { return !m_did.isEmpty() && !m_refreshJwt.isEmpty(); }
    QString did() const { return m_did; }
    QString handle() const { return m_handle; }
    QString pds() const { return m_pds; }

    Q_INVOKABLE void login(const QString &identifier, const QString &password,
                           const QString &server, const QJSValue &callback);
    Q_INVOKABLE void logout();

    Q_INVOKABLE void get(const QString &nsid, const QVariantMap &params, const QJSValue &callback);
    Q_INVOKABLE void post(const QString &nsid, const QVariantMap &body, const QJSValue &callback);

    // Creates an app.bsky.feed.post: detects links, mentions and hashtags, resolves the mentioned
    // handles and writes the record. reply and embed are optional (empty maps are left out).
    Q_INVOKABLE void createPost(const QString &text, const QVariantMap &reply,
                                const QVariantMap &embed, const QJSValue &callback);

    // Post text with its facets as Qt StyledText (escaped, links only for http/https, mentions
    // and tags as bsky-mention:/bsky-tag: links).
    Q_INVOKABLE QString renderText(const QString &text, const QVariantList &facets) const;
    Q_INVOKABLE int graphemeCount(const QString &text) const;
    Q_INVOKABLE QString now() const;

    // Pure helpers, public for the tests.
    static QVariantList detectFacets(const QString &text);
    static QString renderHtml(const QString &text, const QVariantList &facets);
    static QString pdsFromDidDoc(const QVariantMap &doc);

signals:
    void sessionChanged();
    void sessionExpired();

private:
    struct Call {
        QString method;   // "GET" or "POST"
        QString nsid;
        QVariantMap params;
        QByteArray body;
        Done done;
        bool retried = false;
    };

    void call(const QString &method, const QString &nsid, const QVariantMap &params,
              const QVariantMap &body, Done done);
    void send(const Call &call);
    void finishCall(QNetworkReply *reply, Call call);
    void refreshSession();
    Done toJs(const QJSValue &callback);
    void getUrl(const QUrl &url, Done done);
    void postUrl(const QUrl &url, const QVariantMap &body, const QString &bearer, Done done);
    void createSession(const QString &base, const QString &identifier, const QString &password,
                       Done done);
    void resolvePds(const QString &did, std::function<void(QString)> done);
    void resolveMentions(QVariantList facets, int index, std::function<void(QVariantList)> done);
    QUrl xrpcUrl(const QString &nsid, const QVariantMap &params) const;
    QNetworkRequest request(const QUrl &url, const QString &bearer) const;
    static QString errorText(int status, const QVariantMap &json, QNetworkReply *reply);

    void loadSession();
    void saveSession();
    void clearSession();
    QString sessionPath() const;

    QJSEngine *m_engine;
    QNetworkAccessManager m_net;
    QString m_did, m_handle, m_pds, m_accessJwt, m_refreshJwt;
    bool m_refreshing = false;
    QList<Call> m_waiting;
};

#endif
