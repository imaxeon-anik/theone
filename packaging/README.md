# Publishing theOne

theOne can't go in the Jolla Store (Harbour): store apps may only install files under
their own `harbour-` name, and a keyboard has to install into Maliit's plugin folders,
Settings and systemd. It is published in the two community repositories instead.

Both need your own account; nothing here is sent anywhere until you do it.

## OpenRepos (Storeman)

The menu names below may differ a little on the site.

1. Sign up at <https://openrepos.net> and log in.
2. Add a new application.
3. Fill in the form from the listing below. Upload `docs/icon.png` as the icon and the
   four pictures in `docs/` (`classic.png`, `sailfish.png`, `typing.png`, `emoji.png`)
   as screenshots.
4. Save, then on the application's page upload
   `theone-keyboard-<version>-1.aarch64.rpm` from the GitHub releases page.
5. For each new release, upload the new RPM to the same application page.

### Listing

- **Title:** theOne keyboard
- **Category:** Utilities (or System, if it is offered)
- **Tags:** keyboard, maliit, input method, swipe, emoji
- **Licence:** MIT (bundled: Inter font OFL 1.1, word list CC BY-SA 4.0, Noto Emoji Apache 2.0)
- **Source / homepage:** https://github.com/imaxeon-anik/theone

**Description:**

> theOne is an on-screen keyboard for Sailfish OS with a dark, iOS-inspired look.
>
> - Solid rounded keys and a magnified letter balloon while you type
> - Shift: tap for one capital, double-tap for caps lock; automatic capitals at sentence start
> - Double space types a full stop
> - Long-press a letter for accents; drag the space bar to move the cursor
> - English suggestions and autocorrect that learn your words; backspace undoes a correction
> - Optional swipe typing: slide across the letters to write a word
> - Number, symbol and colour emoji pages
> - Two styles: theOne Classic, or a see-through Sailfish style that follows your ambience
> - Standard or Wide key size
>
> After installing, turn it on in Settings → System → theOne keyboard. Turning it off,
> or uninstalling, gives you the Sailfish keyboard back.
>
> English only. No haptics, no voice input. Tested on a Sony Xperia 10 V with Sailfish OS 5.
>
> theOne is an independent project, not affiliated with or endorsed by Apple.

## SailfishOS:Chum

Chum builds theOne from this GitHub repository on the Sailfish OS build service (OBS).
The Chum metadata (title, icon, screenshots, links) is in `rpm/theone-keyboard.spec`.

1. Get an account at <https://build.sailfishos.org> (instructions on its front page).
2. In your home project, **Create Package**, name it `theone-keyboard`.
3. **Add File** and upload `packaging/_service` (it builds the tag `v0.6.1`).
4. In the home project, **Advanced → Meta**, add build targets inside `<project>`:

   ```xml
   <repository name="sailfish_latest_aarch64">
       <path project="sailfishos:latest" repository="latest_aarch64"/>
       <arch>aarch64</arch>
   </repository>
   <repository name="sailfish_latest_armv7hl">
       <path project="sailfishos:latest" repository="latest_armv7hl"/>
       <arch>armv8el</arch>
   </repository>
   <repository name="sailfish_latest_i486">
       <path project="sailfishos:latest" repository="latest_i486"/>
       <arch>i586</arch>
   </repository>
   ```

5. Wait for the builds to go green (click a target to see its log).
6. On the package, **Submit Package** with target project `sailfishos:chum:testing`.
   The Chum maintainers review it and later move it to `sailfishos:chum`.

For each new release: tag it (`vX.Y.Z`), change `revision` in the `_service` file in
`sailfishos:chum:testing` to the new tag, check that it builds, then **Submit Package**
to `sailfishos:chum` (leave the target package name empty).

Chum's rules: <https://github.com/sailfishos-chum/main> (Metadata.md, GettingStarted.md).
