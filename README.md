# Tshijuka Document Seeker (Flutter)

## Project description

**Tshijuka Document Seeker** is the official Android app for **document seekers** on the **Tshijuka RDP** platform. It lets users sign in, create and manage document requests, attach evidence (photos, PDFs, and other allowed files), interact with pre-loss storage flows, and track progress. The app is built with **Flutter**, stores session data and offline queues in **Hive**, and talks to the same **HTTPS API** as the website (default: `tshijukardp.com`). It supports local features such as camera capture, location-aware context, push and local notifications, haptic and vibration feedback, and syncing queued work when the device is back online.

If you are using the full monorepo, the parent folder contains the PHP web app and database schema; this directory is the **Flutter mobile client** only.

## Links

- **YouTube presentation (15 minutes):** https://youtu.be/M53VJ5rM3dQ  
- **Source code:** https://github.com/NdalaTresorBuzangu/Document-seekerapp  
- **Live platform:** https://tshijukardp.com  

| Resource | URL |
|----------|-----|
| YouTube (15 min) | [Watch on YouTube](https://youtu.be/M53VJ5rM3dQ) |
| GitHub | [NdalaTresorBuzangu/Document-seekerapp](https://github.com/NdalaTresorBuzangu/Document-seekerapp) |
| Live site | [tshijukardp.com](https://tshijukardp.com) |

If you have the full **Tshijuka RDP** monorepo, the root `README.md` one level up has the complete overview and file reference table.

## Run

```bash
flutter pub get
flutter run
```

Optional API override:

```bash
flutter run --dart-define=API_BASE_URL=https://your-host/api
```
