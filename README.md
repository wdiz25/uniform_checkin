# Uniform Check-In

A Flutter kiosk app built for a locally owned Domino's store. Employees use it at the start of a shift to record that they're in uniform. Managers can access these photos to review uniform compliance over the past two weeks. The process has been shown to be a strong motivator to wear the correct uniform. It runs on a wall-mounted Android tablet.

<p align="center">
  <img src="docs/Home_Screen.png" alt="Home screen with Begin Check-In button" width="250">
  <img src="docs/Verification_Screen.png" alt="Photo review screen with Discard and Submit buttons" width="250">
  <img src="docs/Procssing_Screen.png" alt="Upload in progress screen" width="250">
</p>

## How It Works

1. An employee taps **Begin Check-In** on the home screen.
2. A countdown asks them to step back behind a line on the floor, and then the app takes a photo with the tablet's front camera.
3. At the same moment, it grabs a frame from the store's security camera over RTSP, which provides a higher-resolution full-body view.
4. The employee reviews the photo and taps **Submit** or **Discard**.
5. Both images are base64-encoded and POSTed to a Google Apps Script web app, which stores them for managers to review through an AppSheet interface.

If the security camera can't be reached, the front-camera photo is uploaded in its place, so a check-in still goes through.

## Tech Details

- **Flutter / Dart**
- [`camera`](https://pub.dev/packages/camera): front-camera preview and capture
- [`media_kit`](https://pub.dev/packages/media_kit): plays the RTSP security camera stream and takes a screenshot of it
- [`http`](https://pub.dev/packages/http): uploads the images to the Apps Script endpoint, handling Google's 302 redirect
- Kiosk-friendly setup: portrait orientation is locked, the app runs in immersive full-screen mode, and the back button is blocked while an upload is in progress

## Setup

### 1. Configuration

The endpoint and credentials aren't hard-coded. They're supplied at build time. Copy the example file (secrets.example.json) and fill in your values.

| Key          | Description                                                  |
| ------------ | ------------------------------------------------------------ |
| `SCRIPT_URL` | Deployment URL of the Google Apps Script web app             |
| `SECRET_KEY` | Shared key that the script checks before accepting an upload |
| `CAM_STREAM` | RTSP URL of the security camera, including credentials       |

### 2. Fonts

The app uses licensed brand fonts, so they aren't included in this repo. To build it, either place your own `.otf` files in `fonts/` with the names listed in `pubspec.yaml`, or remove the `fonts:` section from `pubspec.yaml` to use the default font.

### 3. Run

```sh
flutter pub get
flutter run --dart-define-from-file=secrets.json
```

## Upload Endpoint

The Apps Script backend isn't part of this repo. The app sends it this request:

```json
POST SCRIPT_URL
{
  "filename": "2026-01-01T09_00_00",
  "mimeType": "image/jpeg",
  "image": "<base64 front-camera photo>",
  "cam": "<base64 security-camera frame>",
  "secretKey": "<SECRET_KEY>"
}
```

It expects `{"status": "success"}` in response. Any other response is shown to the user as an error, along with its `message` field.


## Future Considerations
I am planning to migrate the backend and manager-view for this app to Node.js and React by the end of 2026.

## Legal Notice

This is an independent project built for a single franchise location. It is not affiliated with, endorsed by, or sponsored by Domino's Pizza, Inc. or its subsidiaries. Domino's, the Domino's logo, and related marks are trademarks of their respective owners and are used here only to show the app as it was deployed. The Domino's Sans fonts are proprietary and are not included in this repository.

© 2026 William Disman. All rights reserved.