# Unit tests (plain checks, no QtTest) for the C++ helpers. Built and run in the SDK (i486 target), not packaged.
QT += network qml
QT -= gui
CONFIG += console c++11
TARGET = tst_bsky
INCLUDEPATH += ../src
SOURCES += tst_bsky.cpp ../src/bsky.cpp
HEADERS += ../src/bsky.h
