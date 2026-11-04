# Device checklist

Verified in a Linux container on Flutter 3.41.9 with `flutter analyze` (0 errors,
1 warning = the pending D-6 import in `test/widget_test.dart`, 0 infos) and
`flutter test` (68 passing). No Android SDK there, so **nothing below has run on a
phone yet**, and the APK has not been built.

## 0. Build
- [ ] `flutter build apk --debug` succeeds. `share_plus` is pinned to `^11.1.0`
      because 12+ needs Kotlin 2.x; the project is on Kotlin 1.9.23 / AGP 8.3.2.
- [ ] After the build, `git checkout -- .metadata` (trap T-1).

## 1. Upgrade from the old build (install over it, do not uninstall)
- [ ] Old cards are still listed (DB copied from the cache dir, then the old copy
      deleted, F-1). Their text renders at scale 1 in the old colour.
- [ ] Old cards open in "Edit layout"; field positions look right.

## 2. Plan section 7 manual checklist
1. [ ] Fresh install → "No invitations yet" empty state.
2. [ ] New invitation from gallery (no permission prompt) and from camera
       (permission prompt; deny twice → "Open settings").
3. [ ] Two fields; resize one (pinch and the Size slider); recolour one; Save →
       lands on the guests screen.
4. [ ] Three guests incl. **one Gujarati name** and **two identical names** →
       Create all → 3 PDFs (`Name.pdf`, `Name (2).pdf`), Gujarati visible, size,
       position and colour match the editor (overlay a screenshot: F-4).
5. [ ] Kill the app mid-run → guests and their statuses are still there.
6. [ ] Settings → Clear cache → cards and images still there.
7. [ ] Repeat 4 on API 28 and 29 (PDFs are now app-private, D-4(c), so they
       should work there too).
8. [ ] Dark mode and 200 % font size on every screen; TalkBack walk-through.

## 3. New in this pass
- [ ] Share PDF (one guest, and "Share all" from the summary) opens the system
      share sheet; WhatsApp receives the PDF.
- [ ] Cancel during Create all stops after the current guest.
- [ ] "Retry failed" re-runs only the failed guests.
- [ ] Preview (layout and per guest) shows the real rendered card.
- [ ] Measure on the same 12 MP photo, old build vs new: time per guest and PDF
      size (P-1..P-3, P-2). **Unmeasured so far.**

## Known, not fixed
- **Camera photos rotated by EXIF (hypothesis):** Flutter shows JPEGs with their
  EXIF rotation applied, but the exporter decodes with `package:image`, which does
  not bake orientation in. A sideways photo may export rotated relative to the
  editor. Check with a portrait camera photo; fix is `img.bakeOrientation`.
- Storage permissions in the manifest are no longer needed (D-4(c)); trimming them
  is a Phase 7 task.
