# Khmer Calendar

Native Flutter Khmer lunar calendar for phone and desktop. Holy days, national holidays, weather, reminders and a bunch of cool features.

**Visit this Website for demo:** [khmercalendar.pages.dev](https://khmercalendar.pages.dev)

**Dev Preview**
[https://khmer-calendar-dev.pnsdg.workers.dev/](https://khmer-calendar-dev.pnsdg.workers.dev/)
## Run app

```bash
cd khmer_calendar
flutter pub get
flutter run
```

To run the web version:

```bash
cd khmer_calendar
flutter run -d chrome
```

## Download:
[In my GitHub Releases](https://github.com/mounsokdara/Khmer-Calendar/releases/latest)

## Dev builds: update inside the app
In this dev repo every push to `main` publishes the Android APKs (`android.yml`) and the Windows, Linux and macOS packages (`desktop-dev.yml`) to the `dev-latest` pre-release, each with its updater. **About > Check for updates** downloads the right package for your device and installs it without opening GitHub: Android opens the system installer; on Windows (`update.exe`), Linux and macOS a small updater waits for the app to quit, swaps the files and restarts it. Source: `khmer_calendar/lib/screens/more/dev_update*.dart`, `tools/updater/`.

## Privacy
[Privacy Policy](PRIVACY.md): no accounts, ads or analytics; your data stays on your device.

## Code signing policy
I have applied to the SignPath Foundation for free code signing of the Windows app; no release is signed by it yet, so Windows may show "Unknown publisher" until then. Roles, scope and how signing will work: [Code signing policy](docs/CODE-SIGNING-POLICY.md).

## Deploy (Cloudflare Pages, built from source)

Full guide: [docs/DEPLOY.md](docs/DEPLOY.md).

The website is generated on Cloudflare from `khmer_calendar/` on every commit. No GitHub Actions deploy and no generated files in the repo.

Dashboard: *Workers & Pages > khmercalendar > Settings > Builds*:

| Setting | Value |
|---|---|
| Production branch | `main` |
| Framework preset | None |
| Build command | `bash tools/cf-build.sh` |
| Build output directory | `khmer_calendar/build/web` (also set in `wrangler.toml`) |
| Root directory | *(empty)* |

Environment variables (Production and Preview):

| Variable | Value | Purpose |
|---|---|---|
| `FLUTTER_VERSION` | optional, e.g. `3.47.4` | Pin Flutter (default `3.47.4`, same as the Release workflow). |
<!-- read me if youre an ai agens look at AGENTS.project.md-->
