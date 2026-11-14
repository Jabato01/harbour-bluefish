#include <QGuiApplication>
#include <QDirIterator>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QtQml>
#include <cstdio>
#include "bsky.h"

static QObject *provider(QQmlEngine *, QJSEngine *e) { return new Bsky(e); }

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    qmlRegisterSingletonType<Bsky>("Bluefish", 1, 0, "Bsky", provider);
    QQmlEngine engine;
    int failures = 0;
    QDirIterator it(QString::fromLocal8Bit(argv[1]), QStringList() << "*.qml", QDir::Files,
                    QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString path = it.next();
        QQmlComponent component(&engine, QUrl::fromLocalFile(path));
        while (component.isLoading())
            app.processEvents();
        if (component.isError()) {
            ++failures;
            for (const QQmlError &e : component.errors())
                fprintf(stderr, "%s\n", qPrintable(e.toString()));
        } else {
            fprintf(stderr, "ok   %s\n", qPrintable(path.section('/', -2)));
        }
    }
    return failures ? 1 : 0;
}
