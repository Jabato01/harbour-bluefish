import QtQuick 2.0
import Sailfish.Silica 1.0
import Celeste 1.0

Page {
    id: page

    property string message
    property bool busy

    function login() {
        busy = true
        message = ""
        Bsky.login(identifier.text, password.text, server.text, function(error) {
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

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: qsTr("Usa una contraseña de aplicación, no la de tu cuenta. Créala en la web o la app "
                           + "de Bluesky: Ajustes → Privacidad y seguridad → Contraseñas de aplicación. "
                           + "Para ver los mensajes directos, marca que permita el acceso a ellos.")
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
                label: qsTr("Contraseña de aplicación")
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
