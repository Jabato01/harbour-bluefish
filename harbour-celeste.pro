TARGET = harbour-celeste

CONFIG += sailfishapp
QT += network

SOURCES += src/main.cpp \
    src/bsky.cpp

HEADERS += src/bsky.h

DISTFILES += \
    qml/harbour-celeste.qml \
    qml/cover/CoverPage.qml \
    qml/pages/*.qml \
    qml/components/*.qml \
    qml/js/*.js \
    rpm/harbour-celeste.spec \
    harbour-celeste.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172
