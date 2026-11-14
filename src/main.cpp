#include <QGuiApplication>
#include <QQuickView>
#include <QtQml>
#include <sailfishapp.h>

#include "bsky.h"

static QObject *bskyProvider(QQmlEngine *, QJSEngine *scriptEngine)
{
    return new Bsky(scriptEngine);
}

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    // Must match OrganizationName/ApplicationName in the .desktop file: Sailjail only lets the
    // app write to ~/.local/share/org.jabato/bluefish.
    app->setOrganizationName(QStringLiteral("org.jabato"));
    app->setApplicationName(QStringLiteral("bluefish"));

    qmlRegisterSingletonType<Bsky>("Bluefish", 1, 0, "Bsky", bskyProvider);

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->setSource(SailfishApp::pathToMainQml());
    view->show();
    return app->exec();
}
