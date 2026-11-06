# Windows: Microsoft Store package (removes the "Unknown publisher" warning)

The zip on GitHub is signed with our own certificate (when configured), so Windows
SmartScreen may still show "Unknown publisher". Apps installed from the Microsoft
Store are re-signed by Microsoft and show no warning.

There is currently **no automatic MSIX job** in CI. Building a Store package is a
manual step when you are ready to submit.

## One-time setup (needs a person, cannot be automated)

1. Register for free at <https://storedeveloper.microsoft.com> ("Get started for free") with a
   personal Microsoft account. Individual accounts need an ID + selfie check.
2. In Partner Center create a new app and reserve the name **Khmer Calendar**.
3. Open **Product > Product identity** and copy three values:

   | Partner Center field | Use when packaging |
   |---|---|
   | Package/Identity/Name (e.g. `12345Name.KhmerCalendar`) | Identity name |
   | Package/Identity/Publisher (e.g. `CN=XXXXXXXX-XXXX-...`) | Publisher |
   | Package/Properties/PublisherDisplayName | Publisher display name |

## Packaging

Use the official [`msix`](https://pub.dev/packages/msix) Flutter tool locally against a
Windows release build, with the identity values from Partner Center. Upload the
resulting unsigned `.msix` in Partner Center (**Packages** in a new submission).

## Notes

- Store version numbers must end in `.0` (e.g. app `1.0.3` → MSIX `1.0.3.0`).
  Raise the app version for every new submission.
- An unsigned `.msix` cannot be installed by double-clicking; it is only for the Store.
- Inside the Store package the app runs with the Store's package rules. Check anything that
  writes outside the app's own folders, for example the "start with Windows" feature
  (native autostart), before submitting.
