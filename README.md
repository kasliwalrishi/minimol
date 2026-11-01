# HiveNet

HiveNet is a privacy-first LAN image replication app built for a distributed
systems demo. An image is compressed and encrypted on its owner device, then
replicated to two independent devices on the same local network. There is no
cloud bucket, central database, or shared folder.

## What it demonstrates

- AES-256-GCM encryption before a replica leaves its owner.
- SHA-256 content addressing and checksum verification on every transfer.
- Capacity-, latency-, and reliability-aware selection of two distinct peers.
- Local-only peer discovery through manually configured LAN addresses.
- Replica failover: a verified image can be retrieved from another live copy.
- A live router view that visualizes packet movement across responsive peers.

## Repository layout

| Folder | Purpose |
| --- | --- |
| [`hivenet/`](hivenet) | Flutter application for Android, web, Windows, Linux, macOS, and iOS targets. |
| [`Distributed-File-Storage-System/`](Distributed-File-Storage-System) | Original Go distributed-file-storage prototype and protocol notes. |

## Run the Flutter app

```powershell
cd hivenet
flutter pub get
flutter run
```

To build an Android APK:

```powershell
cd hivenet
flutter build apk --debug
```

The artifact is written to
`hivenet/build/app/outputs/flutter-apk/app-debug.apk`.

## Demo flow

1. Install HiveNet on three devices connected to the same LAN.
2. On each device, add the other two devices using their ordinary LAN IPv4
   addresses.
3. Refresh until two peers are shown as **Live**.
4. On the Home screen, select **Encrypt & Upload Image**.
5. HiveNet compresses and encrypts the selected image locally, then stores
   checksum-verified replicas on two peers.
6. The gallery displays compact encrypted-object records rather than insecure
   image previews. The owner device can decrypt an owned image locally.

## Important constraints

- Two eligible, online peers are required for an upload to succeed.
- Peers receive ciphertext and an opaque content ID; they cannot preview an
  owner's image or recover its filename.
- The Android receiver uses TCP port `8765`; device and router firewalls must
  allow local-network access to that port.
- The web build is a client only. It cannot receive unsolicited LAN traffic or
  act as an Android storage replica.

## Verification

```powershell
cd hivenet
flutter analyze
flutter test
```

For the protocol, threat-model details, and multi-device resilience test, see
the [Flutter app README](hivenet/README.md).
