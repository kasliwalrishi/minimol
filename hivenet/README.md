# HiveNet Android MVP

HiveNet is a direct LAN image replica app. Every install has its own randomly
generated node ID and private app storage. It does not use cloud storage,
shared folders, Firebase, or a central database.

## Privacy model

Before a replica leaves its owner, HiveNet compresses the selected image and
encrypts those bytes with a unique AES-256-GCM key and nonce. The key and the
per-object deletion capability remain in `flutter_secure_storage` (Android
Keystore-backed where available) on the owner device. Peers receive opaque
ciphertext, an opaque SHA-256 ciphertext ID, and only the byte count required
to operate storage; they cannot preview an image or recover its filename.

Each peer stores a hash of an unguessable deletion capability, never the
capability itself. The owner must present it for `DELETE /v1/files/<id>`.
This is authenticated deletion, not a guarantee of physical-media erasure:
flash wear levelling, backups, and a malicious modified peer are outside the
control of an application-level delete request. An interrupted/offline deletion
must be retried by the owner before it can be considered complete.

## Protocol and storage

The Android foreground service listens on TCP port `8765` even when the Flutter
activity is no longer visible. It exposes a small HTTP protocol:

- `GET /v1/info` returns node ID and free bytes.
- `GET /v1/files` returns locally stored image metadata.
- `PUT /v1/files/<sha256>` streams a JPEG replica. The recipient writes a
  temporary file, computes SHA-256 during the write, atomically moves it into
  its own app-private filesystem only on a matching checksum, and acknowledges
  with the verified hash.
- `GET /v1/files/<sha256>` retrieves the local JPEG.

The Flutter client decodes a chosen image, limits its longest edge to 1920 px,
encodes JPEG quality 78, and uses the resulting SHA-256 as its content ID. The
dashboard displays original/compressed sizes and the reduction percentage.

## Replica router and distributed gallery

The client probes each configured peer's `/v1/info` endpoint; `freeBytes` is
the Android filesystem's actual `usableSpace`. The router ranks only online
peers that have room for the compressed upload, using free capacity (45%),
probe latency (25%), and persisted verified-transfer reliability (30%). It
selects two distinct node IDs. If a top-ranked transfer fails, it tries the
next eligible distinct peer, but reports success only after two checksum-verified
`201` acknowledgements.

The **Distributed gallery** merges `/v1/files` metadata from all responsive
peers and shows the content hash, compression details, and replica locations.
Opening an image retrieves by its hash, validates SHA-256 before rendering, and
tries each currently available replica. This metadata is discovered from peers;
there is no cloud index or central database. Each receiving Android device owns
its JPEG and JSON metadata in `filesDir/hivenet/files`.

## Chrome mode and its browser boundary

Build with `flutter build web` or run with `flutter run -d chrome`. Chrome uses
IndexedDB for its own compressed uploads and the same SHA-256 transfer protocol
to two Android peers. Android receivers now send the required CORS and OPTIONS
preflight headers, so a page served by Chrome can inspect peers, replicate an
image, and retrieve images from them.

A browser cannot bind a TCP listening port, accept unsolicited LAN connections,
perform UDP multicast discovery, or become an Android storage replica. It is a
client node only: configure Android peer IPs manually, and use two Android
devices as the replica targets. Browser-local images remain in that browser's
IndexedDB and are not available for another device to fetch. Chrome can also
apply Private Network Access restrictions to requests from a public HTTPS page
to a LAN address; the Android receiver answers its CORS/PNA preflight, but a
corporate browser policy, HTTPS mixed-content rule, or router firewall can
still block that traffic. Run the app from a local HTTP development server or
serve it in a deployment that permits those LAN requests. This is a browser
sandbox limitation, not a cloud fallback.

## Build

From PowerShell:

```powershell
cd \hivenet
flutter pub get
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
```

The APK is `build\app\outputs\flutter-apk\app-debug.apk`.

Install it on each physical phone and BlueStacks (enable ADB / developer mode):

```powershell
adb devices
adb -s <device-id> install -r build\app\outputs\flutter-apk\app-debug.apk
```

## Three-device check and resilience test

1. Put all three devices on the same LAN. BlueStacks must use an adapter that
   can reach the phones; do not use its `10.0.2.2` host alias as a peer address.
2. Open HiveNet once on each device and allow its foreground-service
   notification if Android asks. The dashboard identifies the receiver port.
3. Find each device's ordinary Wi-Fi/LAN IPv4 address in its Wi-Fi details.
   On every device, tap the link-plus icon and add the other two addresses.
   Tap refresh until both are green.
4. On device A, tap **Upload image**. HiveNet will not claim success unless B
   and C have both saved and checksum-verified their copies.
5. On B and C, pull to refresh. Each will list the image in **Local gallery**;
   tap it to retrieve it from its own app-private storage. On A, refresh and
   check the **Distributed gallery**: the row must show two peer locations.
6. Turn off Wi-Fi (or force-stop HiveNet) on B. Refresh A, then open the same
   distributed-gallery image. It must load from C. Turn off C too and verify
   that the app reports **No available verified replica**, rather than showing
   an unverified image.

`flutter test` covers deterministic resize/compression hashing and distinct,
capacity-aware router selection. The three-device check covers real receiver
storage, two-peer acknowledgements, hash retrieval, telemetry, and failover;
it must be run on actual LAN devices because a unit test cannot emulate Android
foreground services and independent filesystems.

Files are app-private at `filesDir/hivenet/files` on each device. This is
intentional: uninstalling an app removes only that node's own replicas.


