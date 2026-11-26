Name: theone-keyboard
Version: 0.5.2
Release: 1
Summary: theOne, an iOS-style on-screen keyboard for Sailfish OS
License: MIT and OFL-1.1 and CC-BY-SA-4.0
Source0: %{name}-%{version}.tar.bz2
Requires: maliit-framework-wayland
Requires: nemo-qml-plugin-configuration-qt5
Requires: sailfishsilica-qt5
Requires: dconf
Requires: nemo-qml-plugin-dbus-qt5
Requires: jolla-settings

%description
theOne is a Maliit keyboard plugin for Sailfish OS with a dark, iOS-style look:
solid rounded keys, a magnified letter balloon while typing, iOS-style shift and
caps lock, double-space for a full stop, long-press accents, space-bar cursor
moving, English word suggestions and autocorrect that learn your words, and number,
symbol and emoji pages. Optional Sailfish style: see-through glass keys in
your ambience's colours and font. No haptics, no voice input, no swipe.
Turn it on or off and pick the style in Settings -> theOne keyboard,
or with `theone-keyboard on|off` (as your normal user). Includes the Inter font (SIL Open Font License 1.1) and an English word list
from FrequencyWords (CC BY-SA 4.0).

%prep
%setup -q -n %{name}-%{version}

%build

%install
install -D -m 644 plugin/theone.qml %{buildroot}%{_libdir}/maliit/plugins/theone.qml
D=%{buildroot}%{_datadir}/maliit/plugins/org/theone/keyboard
mkdir -p $D/fonts
install -m 644 qml/org/theone/keyboard/qmldir qml/org/theone/keyboard/*.qml qml/org/theone/keyboard/*.js $D/
install -m 644 qml/org/theone/keyboard/fonts/* $D/fonts/
mkdir -p $D/emoji
install -m 644 qml/org/theone/keyboard/emoji/* $D/emoji/
install -D -m 755 scripts/theone-keyboard %{buildroot}%{_bindir}/theone-keyboard
install -D -m 644 settings/theone-keyboard.json %{buildroot}%{_datadir}/jolla-settings/entries/theone-keyboard.json
install -D -m 644 settings/theone-keyboard.qml %{buildroot}%{_datadir}/jolla-settings/pages/theone-keyboard/theone-keyboard.qml
sed -i 's/@VERSION@/%{version}/' %{buildroot}%{_datadir}/jolla-settings/pages/theone-keyboard/theone-keyboard.qml
install -D -m 644 settings/theone-keyboard@.service %{buildroot}%{_userunitdir}/theone-keyboard@.service

%preun
# On uninstall (not upgrade), give every user the stock keyboard back.
if [ $1 = 0 ]; then
    for conf in /home/*/.config/maliit.org/server.conf; do
        [ -f "$conf" ] || continue
        grep -q 'theone.qml' "$conf" || continue
        if [ -f "$conf.before-theone" ]; then
            mv -f "$conf.before-theone" "$conf"
        else
            rm -f "$conf"
        fi
    done
    killall maliit-server 2>/dev/null || true
fi

%post
# Reload the keyboard on upgrade so new QML is picked up.
if [ $1 -gt 1 ]; then
    killall maliit-server 2>/dev/null || true
fi

%files
%defattr(-,root,root,-)
%{_libdir}/maliit/plugins/theone.qml
%{_datadir}/maliit/plugins/org/theone
%{_bindir}/theone-keyboard
%{_datadir}/jolla-settings/entries/theone-keyboard.json
%{_datadir}/jolla-settings/pages/theone-keyboard
%{_userunitdir}/theone-keyboard@.service
