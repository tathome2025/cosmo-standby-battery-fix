# Cosmo Communicator — Standby Battery Drain Fix (V19 → V23)

If your **Planet Cosmo Communicator** drains battery in standby almost as fast as
when you're actively using it, this repo explains **why** and gives a complete,
no‑Windows way to fix it.

> **TL;DR** — On firmware **V19** the cover‑display ("CoDi") service holds a
> wake lock 24/7, so the SoC **never enters suspend**. Upgrading to **V23** (which
> adds *Cover Display Power Save*) and turning that setting on releases the wake
> lock and lets the phone sleep. Drain in a screen‑off test dropped from
> ~30–60 mAh per ~20 min to ≈ 0.

---

## Symptoms

- Standby power use ≈ active use.
- Phone feels warm / battery % keeps falling overnight with the lid closed.

## Root cause (how it was diagnosed)

All checks below use `adb` (USB debugging on). Full write‑up in
[`docs/diagnosis.md`](docs/diagnosis.md).

The decisive signal across four controlled screen‑off‑on‑battery tests:

```
Time on battery: ... realtime  ==  ... uptime  (100.0%)
```

`uptime == realtime` means the CPU **never suspended for a single second** — screen
off behaves exactly like screen on. It made no difference whether Wi‑Fi, mobile
data, or airplane mode was on.

The blocker is a single user‑space wake lock, visible with:

```bash
adb shell dumpsys power | grep -iE "Wake Locks|Amoledison"
# Wake Locks: size=1
#   PARTIAL_WAKE_LOCK 'AmoledisonThread' (uid=1000 pid=<system_server>)
```

`Amoledison` is the **AMOLED cover‑display service** baked into the Cosmo
firmware (runs inside `system_server`). On V19 it holds the lock permanently,
which keeps `PowerManagerService.WakeLocks` referenced 24/7 → no suspend.
A reboot doesn't help; it isn't a third‑party app.

## The fix

1. Be on firmware **V23 or newer** (V23 added **Cover Display Power Save**; V19 lacks it).
2. **Settings → Cosmo Settings → Cover Display Power Save → ON.**

After that, the wake lock is acquired/released periodically instead of held
forever, and the device suspends normally.

Verify:

```bash
adb shell dumpsys power | grep -i amoledison   # should NOT be permanently held
# run a screen-off, on-battery test, then:
adb shell dumpsys batterystats | grep -i "Time on battery:"   # uptime should be < realtime now
```

---

## Upgrading V19 → V23 without Windows

Planet's **FOTA/OTA servers are dead** (the company shut down), so in‑phone
"Wireless Update" hangs on *Checking for updates*. The **static firmware
download is still alive**, though, and you can flash it with `fastboot` from
macOS or Linux (no SP Flash Tool, no Windows).

### What you need

- A Cosmo Communicator on V19 (older may work, untested here).
- `adb` + `fastboot` (Android platform‑tools) on a Mac/Linux box.
- The V23 firmware zip — see **[Releases](../../releases)** of this repo
  (mirror) or the official source below.
- ⚠️ **Unlocking the bootloader ERASES ALL DATA.** Back up first.
- ⚠️ This leaves your **bootloader unlocked** (a warning screen on every boot).

### Firmware download

| Source | URL |
|--------|-----|
| Official (Planet, still live but slow) | `https://support.planetcom.co.uk/download/cosmo-android-v23.zip` |
| Mirror (this repo, resilient) | GitHub **Releases → `cosmo-android-v23.zip`** |

```
sha256  e4ed420db1389f0a87353a1d65cc2e292d4667494a8108fe09287c6e37da6912
size    1364891084 bytes (~1.36 GB)
```

The zip contains `cosmo-customos-installer/v23/*.img` (the per‑partition images)
plus Planet's own installer scripts.

### Why fastboot instead of the SD‑card installer

Planet's documented method is: copy `cosmo-customos-installer/` to an SD card,
boot recovery, pick *"Install a custom OS"*. **That requires a recovery that
supports the installer menu.** On a stock **V19** recovery you only get the
AOSP *"No command"* screen and the menu never appears — so we flash the same
images directly with `fastboot` instead. (The commands below mirror exactly what
Planet's `Cosmo_Installer_V23_auto.sh` does via `dd`.)

### Steps

1. **Enable OEM unlocking** on the phone: Settings → Developer options → *OEM
   unlocking* → ON. (Enable Developer options first: tap *Build number* 7×.)
2. **Enter the bootloader:**
   ```bash
   adb reboot bootloader
   fastboot devices            # should list your device
   fastboot getvar unlocked    # "unlocked: no" before unlocking
   ```
3. **Unlock (this wipes the phone):**
   ```bash
   fastboot flashing unlock     # then confirm ON THE PHONE SCREEN (Vol keys + Power)
   fastboot getvar unlocked     # "unlocked: yes"
   ```
4. **Flash V23.** Unzip the firmware, then run [`scripts/flash-v23-fastboot.sh`](scripts/flash-v23-fastboot.sh):
   ```bash
   unzip cosmo-android-v23.zip -d v23
   ./scripts/flash-v23-fastboot.sh v23/cosmo-customos-installer/v23
   ```
   It flashes every partition (logo, cam_vpu1‑3, dtbo, md1dsp, md1img, scp1/2,
   spmfw, sspm_1/2, tee1/2, vendor, recovery, boot, system) and `lk/lk2` last.
   `system` (~3 GB) takes a few minutes — **do not interrupt.**
5. **Reboot:**
   ```bash
   fastboot reboot
   ```
   First boot is slow (a few minutes). You'll go through fresh setup (the unlock
   wiped data).
6. **Enable the battery fix:** Settings → Cosmo Settings → **Cover Display Power
   Save → ON** (see above).

### Optional follow‑ups

- **V23 → V25** (2021 security patches, keyboard "no delay on open"): a local OTA
  exists at [`planet-community/cosmo-v25-android-fw-ota`](https://github.com/planet-community/cosmo-v25-android-fw-ota)
  (install from local storage; requires being on V23).
- **Root**: bootloader is already unlocked — `fastboot flash boot <magisk-patched-boot>`.
- **Re‑lock**: generally *not* recommended after flashing; can brick.

---

## Apps tuned for the Cosmo

Once you're on V23 and the battery behaves, here's software built *specifically*
for the Cosmo's landscape clamshell and physical QWERTY:

- **[PalmVellum](https://github.com/palmvellum/palmvellum)** — a local-first,
  Palm‑inspired organizer (Date Book, Address, To Do, Memo, Note Pad, Expense,
  Mail; works fully offline, with optional cloud sync + AI). It ships a dedicated
  **Cosmo edition** as a separate build flavor (`cosmo`), installable *alongside*
  the standard portrait build:
  - **Landscape‑locked** UI sized for the 2160×1080 main display.
  - A **left icon rail** (with a home button) instead of the bottom button bar.
  - **Two‑pane master/detail** layouts — Date Book (calendar + day), Address,
    To Do, Memo, Mail, Expense — that actually use the wide screen.
  - **Inline title‑bar filters/search** to save vertical height.

  **Download** the Cosmo APK from
  [PalmVellum Releases → `android-v0.1.0`](https://github.com/palmvellum/palmvellum/releases/tag/android-v0.1.0)
  (grab `PalmOrganizers-0.1.0-cosmo.apk`), or build from source — from
  `packages/android-native/`, run `./gradlew :app:assembleCosmoDebug`.
  UI spec: [`docs/cosmo-ui-spec.md`](https://github.com/palmvellum/palmvellum/blob/main/docs/cosmo-ui-spec.md).

  > ⚠️ Not on the Play Store — a sideload (debug‑signed) APK, not Play‑reviewed.
  > Allow "Install unknown apps", then install. No warranty; use at your own risk.

- **[CosmoHID — Bluetooth keyboard relay](https://github.com/tathome2025/cosmo-bluetooth-keyboard)**
  — turns the Cosmo into a real **Bluetooth keyboard** for another device (e.g. an
  OPPO Find N2): its physical keys send live HID keystrokes to the host, fully
  offline, no app on the host and no root. Build it from source with
  `./gradlew :app:assembleDebug`.

*Got another Cosmo‑tuned app? PRs to this list welcome.*

---

## Credits / sources

- Diagnosis & write‑up: community effort, 2026.
- Firmware: © Planet Computers (company defunct). Mirrored here for preservation
  because the official FOTA is gone; official static download was still live at
  time of writing. Planet firmware files are also mirrored by the
  [`planet-community`](https://github.com/planet-community) project.
- Planet wiki (archived):
  [Cosmo Android Firmware Manual Installation](https://support.planetcom.co.uk/index.php/Cosmo_Android_Firmware_Manual_Installation),
  [Latest Cosmo Firmware](https://support.planetcom.co.uk/index.php/Latest_Cosmo_Firmware).

**No warranty.** Flashing and bootloader unlocking are at your own risk and will
wipe your device. If something goes wrong, the Cosmo is a MediaTek device and can
usually be recovered in BROM mode (e.g. `mtkclient`).
