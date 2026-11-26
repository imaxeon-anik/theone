pragma Singleton
import QtQuick 2.6
// Test stand-in for Maliit's enum type (QML enums need Qt >= 5.10; the VM has 5.15).
QtObject {
    enum KeyEvent { KeyPress, KeyRelease, KeyClick }
    enum ContentType { FreeTextContentType, NumberContentType, PhoneNumberContentType, EmailContentType, UrlContentType, CustomContentType }
}
