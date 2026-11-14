TARGET = harbour-bluefish

CONFIG += sailfishapp
QT += network

SOURCES += src/main.cpp \
    src/bsky.cpp

HEADERS += src/bsky.h

DISTFILES += \
    qml/harbour-bluefish.qml \
    qml/cover/CoverPage.qml \
    qml/pages/*.qml \
    qml/components/*.qml \
    qml/js/*.js \
    rpm/harbour-bluefish.spec \
    harbour-bluefish.desktop \
    org.jabato.bluefish.service

# Lets a tap on a notification start the app (D-Bus activation) and open what it was about.
# The Harbour store does not allow it: "CONFIG+=harbour" leaves it out (see the .spec file).
harbour {
    DEFINES += BLUEFISH_HARBOUR
} else {
    dbus.files = org.jabato.bluefish.service
    dbus.path = /usr/share/dbus-1/services
    INSTALLS += dbus
}

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172
