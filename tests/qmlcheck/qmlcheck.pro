# Compiles every QML file without showing it, to catch syntax and type errors in the SDK.
QT += qml quick
CONFIG += c++11
TARGET = qmlcheck
INCLUDEPATH += ../../src
SOURCES += qmlcheck.cpp ../../src/bsky.cpp
HEADERS += ../../src/bsky.h
