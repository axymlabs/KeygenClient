# App Store marketing kit

Edit [content.json](content.json) for store copy, captions and the marketing video storyboard. The version and build always come from `pubspec.yaml`. All screenshots are rendered afresh from the current Flutter widgets and built-in fictional sample data. No production server is contacted.

## Generate locally

On macOS with Flutter, Xcode/Swift and FFmpeg installed:

```sh
flutter pub get
python3 tool/app_store/generate.py
```

Open `app-store/generated/<version>+<build>/index.html` to review the result. The ZIP beside that folder includes:

- 30 branded listing screenshots: five scenes, light/dark, for iPhone (1320×2868), iPad (2064×2752), and Mac (2560×1600).
- 30 unframed UI renders at the same sizes.
- Portrait (1080×1920) and landscape (1920×1080) H.264/AAC marketing videos, with poster frames and a release hero.
- English (UK) store metadata, release/review notes, icon, an offline HTML gallery, provenance manifest and SHA-256 checksums.

The clips are promotional cuts assembled from rendered app screens with transitions. They are **not device-recorded App Store Previews**. They are for GitHub release/website marketing; an Apple preview submission requires appropriate device-recorded footage. No App Store Connect publishing is configured.

Screenshot dimensions follow [Apple's specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications). See [Apple's preview guidance](https://developer.apple.com/app-store/app-previews/) for device-recording requirements.

## Release publishing

Repository: [axymlabs/KeygenClient](https://github.com/axymlabs/KeygenClient).

1. Update `pubspec.yaml` and `content.json` for the release and commit the changes.
2. Create a tag matching the marketing version (`v1.0.0`) or marketing version plus build (`v1.0.0+1`). Create/publish a GitHub Release for that tag.
3. The **App Store marketing assets** workflow checks out the tag, runs checks, regenerates the entire kit and attaches the ZIP, checksum, manifest, store copy, hero, videos and posters to that release.

Run the workflow manually with an existing release tag to regenerate its assets. Uploads replace matching generated filenames for that release. Other release assets are preserved. The workflow uses the repository's short-lived `GITHUB_TOKEN` with `contents: write`; no Apple credentials or long-lived GitHub secrets are needed.

To upload a locally generated kit to an existing release, check out its tag, regenerate, then run:

```sh
python3 tool/app_store/publish.py --tag v1.0.0
```

The publisher refuses assets whose source commit differs from the tag. The public privacy/support destinations in the metadata must contain the prepared Keygen Client content before an App Store submission.
