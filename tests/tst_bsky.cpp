// Plain checks (QtTest is not installed in the SDK targets).
#include <QCoreApplication>
#include <QDebug>
#include <cstdio>
#include "bsky.h"

static int failures = 0;
#define QCOMPARE(a, b) do { const auto _a = (a); const auto _b = (b); if (!(_a == _b)) { \
    ++failures; qWarning().noquote() << "FAIL" << __func__ << __LINE__ << #a << "==" << #b; \
    qWarning() << "  actual:" << _a << "expected:" << _b; } } while (0)
#define QVERIFY(c) do { if (!(c)) { ++failures; qWarning() << "FAIL" << __func__ << __LINE__ << #c; } } while (0)

namespace {
QVariantMap feature(const QVariant &facet) { return facet.toMap()["features"].toList()[0].toMap(); }
int start(const QVariant &facet) { return facet.toMap()["index"].toMap()["byteStart"].toInt(); }
int end(const QVariant &facet) { return facet.toMap()["index"].toMap()["byteEnd"].toInt(); }

QVariantMap linkFacet(int s, int e, const QString &uri)
{
    QVariantMap f, index, feat;
    index["byteStart"] = s; index["byteEnd"] = e;
    feat["$type"] = "app.bsky.richtext.facet#link"; feat["uri"] = uri;
    f["index"] = index; f["features"] = QVariantList() << feat;
    return f;
}
}

class TestBsky
{
public:
    void mentionWithMultibyteBefore()
    {
        // "¡Hola " is 7 bytes in UTF-8 ("¡" takes 2).
        const QVariantList f = Bsky::detectFacets(QString::fromUtf8("¡Hola @alice.bsky.social!"));
        QCOMPARE(f.size(), 1);
        QCOMPARE(feature(f[0])["$type"].toString(), QString("app.bsky.richtext.facet#mention"));
        QCOMPARE(feature(f[0])["handle"].toString(), QString("alice.bsky.social"));
        QCOMPARE(start(f[0]), 7);
        QCOMPARE(end(f[0]), 7 + 18);
    }

    void emojiOffsets()
    {
        // The emoji is 4 bytes in UTF-8 and 2 UTF-16 units.
        const QString text = QString::fromUtf8("😀 https://example.com/a?b=1.");
        const QVariantList f = Bsky::detectFacets(text);
        QCOMPARE(f.size(), 1);
        QCOMPARE(feature(f[0])["uri"].toString(), QString("https://example.com/a?b=1"));
        QCOMPARE(start(f[0]), 5);
        QCOMPARE(end(f[0]), 5 + 25);
    }

    void notMentions()
    {
        QCOMPARE(Bsky::detectFacets("mail me at bob@example.com").size(), 0);
        QCOMPARE(Bsky::detectFacets("version @1.5").size(), 0);
        QCOMPARE(Bsky::detectFacets("just @someone").size(), 0);
    }

    void wwwAndParentheses()
    {
        const QVariantList f = Bsky::detectFacets("(see www.example.org/page)");
        QCOMPARE(f.size(), 1);
        QCOMPARE(feature(f[0])["uri"].toString(), QString("https://www.example.org/page"));
        QCOMPARE(end(f[0]) - start(f[0]), QString("www.example.org/page").size());

        const QVariantList w = Bsky::detectFacets("https://en.wikipedia.org/wiki/Foo_(bar)");
        QCOMPARE(feature(w[0])["uri"].toString(), QString("https://en.wikipedia.org/wiki/Foo_(bar)"));
    }

    void hashtags()
    {
        const QVariantList f = Bsky::detectFacets(QString::fromUtf8("Hoy #Sailfish, #2024 y #café."));
        QCOMPARE(f.size(), 2);
        QCOMPARE(feature(f[0])["tag"].toString(), QString("Sailfish"));
        QCOMPARE(feature(f[1])["tag"].toString(), QString::fromUtf8("café"));
        QCOMPARE(end(f[1]) - start(f[1]), 6);   // "#café": é is 2 bytes
    }

    void sortedByPosition()
    {
        const QVariantList f = Bsky::detectFacets("#tag https://a.io @b.c.d");
        QCOMPARE(f.size(), 3);
        QVERIFY(start(f[0]) < start(f[1]) && start(f[1]) < start(f[2]));
    }

    void renderEscapesAndLinks()
    {
        const QString text = QString::fromUtf8("<b>ñ</b> link\nnext");
        // "<b>ñ</b> " = 10 bytes, "link" = bytes 10..14
        const QString html = Bsky::renderHtml(text, QVariantList() << linkFacet(10, 14, "https://x.org/?a=1&b=\"2\""));
        QCOMPARE(html, QString::fromUtf8("&lt;b&gt;ñ&lt;/b&gt; <a href=\"https://x.org/?a=1&amp;b=%222%22\">link</a><br>next"));
    }

    void renderRejectsBadFacets()
    {
        const QString text = "hello world";
        QVariantList facets;
        facets << linkFacet(0, 5, "javascript:alert(1)")   // not http(s)
               << linkFacet(3, 50, "https://a.io")          // out of range
               << linkFacet(6, 11, "https://ok.io")
               << linkFacet(7, 9, "https://overlap.io");    // overlaps the previous one
        QCOMPARE(Bsky::renderHtml(text, facets), QString("hello <a href=\"https://ok.io\">world</a>"));
    }

    void pdsFromDidDoc()
    {
        QVariantMap service;
        service["id"] = "#atproto_pds";
        service["type"] = "AtprotoPersonalDataServer";
        service["serviceEndpoint"] = "https://morel.us-east.host.bsky.network/";
        QVariantMap doc;
        doc["service"] = QVariantList() << service;
        QCOMPARE(Bsky::pdsFromDidDoc(doc), QString("https://morel.us-east.host.bsky.network"));
        service["serviceEndpoint"] = "http://insecure.example";
        doc["service"] = QVariantList() << service;
        QCOMPARE(Bsky::pdsFromDidDoc(doc), QString());
    }
};

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    TestBsky t;
    t.mentionWithMultibyteBefore();
    t.emojiOffsets();
    t.notMentions();
    t.wwwAndParentheses();
    t.hashtags();
    t.sortedByPosition();
    t.renderEscapesAndLinks();
    t.renderRejectsBadFacets();
    t.pdsFromDidDoc();
    fprintf(stderr, failures ? "%d FAILED\n" : "All tests passed\n", failures);
    return failures ? 1 : 0;
}
