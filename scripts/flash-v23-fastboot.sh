#!/usr/bin/env bash
#
# Flash Cosmo Communicator V23 firmware via fastboot.
# Mirrors Planet's Cosmo_Installer_V23_auto.sh (which dd's each image on-device).
#
# Usage:
#   ./flash-v23-fastboot.sh <dir-with-v23-images>
# e.g.
#   unzip cosmo-android-v23.zip -d v23
#   ./flash-v23-fastboot.sh v23/cosmo-customos-installer/v23
#
# Requirements: bootloader ALREADY UNLOCKED, device in fastboot mode.
# WARNING: overwrites firmware partitions. Bootloader (lk) is flashed LAST so a
# failure earlier still leaves a bootable bootloader.

set -u
IMG="${1:?usage: flash-v23-fastboot.sh <dir-with-v23-images>}"
FASTBOOT="${FASTBOOT:-fastboot}"

# partition  image            (order mirrors Planet's installer; lk/lk2 last)
MAP=(
  "logo:logo-verified.bin"
  "cam_vpu1:cam_vpu1-verified.img"
  "cam_vpu2:cam_vpu2-verified.img"
  "cam_vpu3:cam_vpu3-verified.img"
  "dtbo:dtbo-verified.img"
  "md1dsp:md1dsp-verified.img"
  "md1img:md1img-verified.img"
  "scp1:scp-verified.img"
  "scp2:scp-verified.img"
  "spmfw:spmfw-verified.img"
  "sspm_1:sspm-verified.img"
  "sspm_2:sspm-verified.img"
  "tee1:tee-verified.img"
  "tee2:tee-verified.img"
  "vendor:vendor.img"
  "recovery:recovery-verified.img"
  "boot:boot-verified.img"
  "system:system.img"
  "lk:lk-verified.img"
  "lk2:lk-verified.img"
)

echo "fastboot device:"; "$FASTBOOT" devices || { echo "no fastboot device"; exit 1; }
echo

for entry in "${MAP[@]}"; do
  part="${entry%%:*}"; img="${entry#*:}"
  if [[ ! -f "$IMG/$img" ]]; then echo "MISSING: $IMG/$img — STOPPING"; exit 1; fi
  echo ">>> flashing $part  <=  $img"
  if ! "$FASTBOOT" flash "$part" "$IMG/$img"; then
    echo "!!! FAILED on $part — STOPPING (do not reboot; ask for help)"; exit 1
  fi
done

echo
echo "All partitions flashed OK. Reboot with:  $FASTBOOT reboot"
echo "First boot is slow. Then: Settings > Cosmo Settings > Cover Display Power Save > ON"
