import QtQuick 2.0
import Sailfish.Silica 1.0
import Bluefish 1.0

Page {
    id: page

    property string message
    property bool busy
    property bool showGuide

    // Bluesky app passwords look like "abcd-efgh-ijkl-mnop". Anything else is most likely the
    // account password, which must never be typed into a third-party app: it is not sent.
    readonly property bool looksLikeAppPassword: /^[a-z0-9]{4}(-[a-z0-9]{4}){3}$/i.test(password.text.trim())

    function login() {
        if (!looksLikeAppPassword) {
            message = qsTr("Eso no parece una contraseña de aplicación (tienen la forma xxxx-xxxx-xxxx-xxxx). "
                           + "Por seguridad no se ha enviado. Nunca uses aquí la contraseña de tu cuenta.")
            return
        }
        busy = true
        message = ""
        Bsky.login(identifier.text, password.text.trim(), server.text, function(error) {
            busy = false
            if (error) {
                message = error
                return
            }
            password.text = ""
            pageStack.replace(Qt.resolvedUrl("FeedPage.qml"))
        })
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader { title: qsTr("Iniciar sesión en Bluesky") }

            // Warning, impossible to miss.
            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: warning.height + 2 * Theme.paddingMedium
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.errorColor, 0.15)
                border.color: Theme.errorColor
                border.width: 2

                Row {
                    id: warning
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    HighlightImage {
                        id: warningIcon
                        source: "image://theme/icon-m-warning"
                        color: Theme.errorColor
                    }
                    Label {
                        width: parent.width - warningIcon.width - parent.spacing
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primaryColor
                        textFormat: Text.StyledText
                        text: qsTr("<b>Usa ÚNICAMENTE una contraseña de aplicación.</b> Nunca escribas aquí "
                                   + "la contraseña de tu cuenta de Bluesky: con ella se puede hacer todo con "
                                   + "tu cuenta, incluido cambiar tu correo y tu contraseña. Una contraseña de "
                                   + "aplicación se puede revocar en cualquier momento.")
                    }
                }
            }

            BackgroundItem {
                width: parent.width
                onClicked: showGuide = !showGuide
                Label {
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 2 * x - guideArrow.width
                    text: qsTr("¿Cómo consigo una contraseña de aplicación?")
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                }
                HighlightImage {
                    id: guideArrow
                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                    source: showGuide ? "image://theme/icon-m-up" : "image://theme/icon-m-down"
                }
            }

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                spacing: Theme.paddingSmall
                visible: showGuide

                Repeater {
                    model: [
                        qsTr("Entra en Bluesky desde la web (bsky.app) o desde su app oficial, con tu usuario y "
                             + "la contraseña de tu cuenta. Hazlo allí, no aquí."),
                        qsTr("Ve a Ajustes → Privacidad y seguridad → Contraseñas de aplicación."),
                        qsTr("Pulsa «Añadir contraseña de aplicación» y ponle un nombre que la identifique, "
                             + "por ejemplo «Bluefish»."),
                        qsTr("Si quieres usar los mensajes privados, marca «Permitir el acceso a tus mensajes "
                             + "directos». Si no, déjalo sin marcar."),
                        qsTr("Pulsa «Siguiente». Aparecerá una contraseña con la forma xxxx-xxxx-xxxx-xxxx. "
                             + "Cópiala: solo se muestra una vez."),
                        qsTr("Pégala aquí abajo, en «Contraseña de aplicación», junto con tu usuario."),
                        qsTr("Si pierdes el teléfono o dejas de usar la app, bórrala en esa misma pantalla de "
                             + "Bluesky: la app perderá el acceso al momento.")
                    ]
                    delegate: Row {
                        width: parent.width
                        spacing: Theme.paddingSmall
                        Label {
                            id: stepNumber
                            text: (index + 1) + "."
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.highlightColor
                        }
                        Label {
                            width: parent.width - stepNumber.width - parent.spacing
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.secondaryHighlightColor
                            textFormat: Text.PlainText
                            text: modelData
                        }
                    }
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    preferredWidth: Theme.buttonWidthLarge
                    text: qsTr("Abrir la página en el navegador")
                    onClicked: Qt.openUrlExternally("https://bsky.app/settings/app-passwords")
                }
            }

            TextField {
                id: identifier
                width: parent.width
                label: qsTr("Usuario o correo")
                placeholderText: qsTr("usuario.bsky.social")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhUrlCharactersOnly
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: password.focus = true
            }

            PasswordField {
                id: password
                width: parent.width
                label: password.text.length > 0 && !looksLikeAppPassword
                       ? qsTr("No tiene la forma de una contraseña de aplicación")
                       : qsTr("Contraseña de aplicación (xxxx-xxxx-xxxx-xxxx)")
                placeholderText: qsTr("Contraseña de aplicación")
                errorHighlight: password.text.length > 0 && !looksLikeAppPassword
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: if (!busy) login()
            }

            TextField {
                id: server
                width: parent.width
                label: qsTr("Servidor (opcional, solo si no usas bsky.social)")
                placeholderText: qsTr("Servidor (opcional)")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhUrlCharactersOnly
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Entrar")
                enabled: !busy && identifier.text.length > 0 && password.text.length > 0
                onClicked: login()
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                size: BusyIndicatorSize.Medium
                running: busy
                visible: busy
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                visible: message.length > 0
                color: Theme.errorColor
                textFormat: Text.PlainText
                text: message
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("La sesión se guarda solo en este teléfono. La contraseña no se guarda.")
            }
        }
    }
}
