# Diagnosis: why the Cosmo never sleeps on V19

This is the full investigation behind the one‑line fix in the README. Everything
was done over `adb` with USB debugging enabled — **no root**.

## 1. The phone never enters suspend

Reset the counters, unplug, lock the screen, leave it ~20–60 min, plug back in,
then read battery stats:

```bash
adb shell dumpsys batterystats --reset
# ... screen off, on battery, 20+ min ...
adb shell dumpsys batterystats | grep -iE "Time on battery:|screen off"
```

On V19, every run showed:

```
Time on battery: 51m 49s realtime, 51m 49s uptime (100.0%)
Time on battery screen off: 51m 36s realtime ... uptime 99.6%
```

`uptime == realtime` (100 %) is the smoking gun: during screen‑off the CPU
**never suspended**. A healthy phone shows uptime far below realtime because the
SoC sleeps between wakeups. Screen‑off discharge was ~30–60 mAh per test.

Repeated with **Wi‑Fi off**, **mobile data off**, and **airplane mode** — still
100 % uptime. So it is **not** a radio keeping the phone awake; whatever held the
wake lock did so regardless of connectivity (the modem `ttyC0`/`ccci_poll` locks
were only secondary).

## 2. Name the wake lock

```bash
adb shell dumpsys power | grep -iE "Wake Locks|PARTIAL_WAKE|Amoledison"
```

```
Wake Locks: size=1
  PARTIAL_WAKE_LOCK 'AmoledisonThread' (uid=1000 pid=1067)
Suspend Blockers:
  PowerManagerService.WakeLocks: ref count=1
Display Power: state=OFF
```

A single partial wake lock, **`AmoledisonThread`**, held by uid 1000 while the
screen is OFF. That alone keeps `PowerManagerService.WakeLocks` referenced, which
is what blocks suspend.

```bash
adb shell ps -p 1067 -o NAME           # system_server
# thread:                              AmoledisonService
```

It's a thread **inside `system_server`** — i.e. part of Planet's firmware (the
AMOLED cover‑display service), not an installed app. App‑level wake locks were all
sub‑millisecond, confirming the holder is system/firmware.

## 3. Red herrings ruled out

- **Reboot** — load average ~17 right after boot looked alarming, but that's ~18
  normal MediaTek kernel threads parked in `D` (uninterruptible) state; the CPU
  was ~95 % idle. Android load average is not a "busy" metric here. The wake lock
  returned after every reboot.
- **`settings put secure CoverDisplayStatus 0`** — gets overwritten back to `1`
  on boot; not the real control.
- **`dumpsys deviceidle force-idle`** — refused while charging and wouldn't
  release a system wake lock anyway.

There is **no clean no‑root way** to release this wake lock on V19.

## 4. Why V23 fixes it

V19 has no user setting to power‑manage the cover display, so the service holds
the lock forever. Firmware **V23** introduced **Cover Display Power Save**. With
it enabled, the same service now acquires/releases the lock periodically:

```bash
adb shell dumpsys power | grep -i amoledison   # no longer permanently held
adb shell dumpsys batterystats | grep "Time on battery:"
# uptime now < realtime  → the SoC is finally sleeping
```

In the first post‑upgrade screen‑off test, screen‑off discharge was ≈ 0 mAh and
uptime dropped below realtime for the first time. (Take an early post‑setup test
with a grain of salt — a freshly wiped device has a lot of first‑run background
sync; re‑test after it settles for a true number.)
