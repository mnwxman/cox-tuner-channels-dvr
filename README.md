[readme.md](https://github.com/user-attachments/files/24041451/readme.md)
# Cox Contour on Apple TV – Custom Tuner for Channels DVR

Version: 1.00  
Release date: 2025‑12‑07

## Overview

This tuner uses an Apple TV running the Cox Contour tvOS app together with an HDMI encoder, and exposes it to Channels DVR as a custom tuner. It assumes you have some prior Docker and Portainer experience for installation and management. If you are new to this, it is strongly recommended that you first install OliveTin for Channels and get comfortable using Portainer and Docker there, since OliveTin provides useful system‑level integrity scripts and is a good baseline for verifying that Channels can talk to containers correctly.

The tuner has been tested with an Apple TV 4K (2nd generation) running tvOS 18 and later tvOS 26, together with a LinkPi ENC1‑V3 HDMI encoder. Other HDMI encoders may work; there is no hard dependency on the LinkPi device.

All testing to date has been on an M4 Mac mini running macOS 15.6, using Portainer 2.27.6 and Docker Desktop for Mac 4.46.0 (204649).

## Architecture and Code Branch

This tuner uses the `AH4C:appleTV` code branch. That branch has support for:

- `pyatv` `atvremote` commands that emulate Apple TV remote keypresses.
- Direct `pyatv` commands to the Apple TV for station selection and navigation.

Familiarity with Docker and Portainer is recommended for installing and operating this tuner.

For `pyatv` reference information, see: https://pyatv.dev

## Script Overview

Like other AH4C implementations, this tuner is built around three scripts:

- `prebmitune.sh`
- `bmitune.sh`
- `stopbmitune.sh`

Each script has a specific role in the virtual tuning process.

### prebmitune.sh

General responsibilities:

- Wake the device (if needed).
- Confirm basic connectivity using the streaming device IP passed as the first argument.

Cox‑specific notes:

- The Apple TV is expected to remain **always on** for the lowest possible tune times.
- Because the device is kept awake, this script does not actively perform wake logic and is effectively a no‑op in normal operation.

### bmitune.sh

General responsibilities:

- Handle the virtual tuning process.
- Accept the channel ID as the first argument.
- Accept the streaming device IP address as the second argument.
- Optionally accept additional data separated by a tilde (`~`) so that the `.m3u` file serves as an authoritative data source.

Cox‑specific notes:

- The channel number is concatenated with the channel name in the M3U using a tilde (see example M3U provided in this project).
- The **channel number** defined in the M3U is what is actually used for tuning.
- Recommended M3U numbering:
  - Use a thousands boundary (between 1000 and 9000) for your virtual channel numbers.
  - The most significant digit is ignored in the tuning logic.
  - Match the lower three digits to the real Cox live channel number in your region.
  - Example: If TBS is channel 45 in your Cox guide, define it in your M3U as 1045, 2045, 3045, etc.
- In Channels DVR, configure the custom source to “Prefer channel number from M3U” so the guide uses these numbers.
- The Cox Contour app supports up to 999 stations; build your M3U to reflect the actual Cox Contour App live guide.
- A useful housekeeping step is to mark favorite channels in the Cox app and filter the live guide by favorites, then base your M3U on that filtered list. This is optional but can simplify M3U creation.
- The human‑readable channel name in the M3U is for readability only; tuning logic uses the numeric portion.

Implementation note:

- `bmitune.sh` is a hybrid Bash and Python script.
- Embedded Python code is needed to push the desired channel number into the Cox Contour Live Guide search screen as quickly and reliably as possible.

### stopbmitune.sh

General responsibilities:

- Stop streaming from the tuner.
- Perform any cleanup required to prepare the Apple TV and Cox app for the next tune.

Cox‑specific notes:

- The Cox Contour app has several UI quirks and design weaknesses.
- A number of trade‑offs were made between fault tolerance and real‑world responsiveness; the current design prioritizes speed and performance, with some limited fault handling.
- To avoid extremely slow tuning times, there is no support for Apple TV sleep mode:
  - The Apple TV must remain **ALWAYS ON**.
  - It must reside in a known, static idle state between tuning operations.
- The tuner assumes that when Channels DVR finishes using the tuner, `stopbmitune.sh`:
  - Returns the Cox Contour app to a specific search menu inside the “Live” subfolder of the main menu.
  - Leaves the app in that known idle state, ready for the next tune.
- The intent is for this Apple TV to be a **sandboxed tuner**:
  - Treat the device as dedicated to Channels DVR usage only.
  - Physical use of the Apple TV remote by other household members can disrupt the expected state.
  - If the app is not in the expected idle state when Channels DVR tunes, behavior is undefined.

During normal use, `stopbmitune.sh` will handle this housekeeping and includes some built‑in error correction when tuning live.

## Quirky Tuning Notes and Fault Tolerance

1. **Out‑of‑sync conditions**

   Occasionally the Cox Contour app and Channels DVR can drift out of sync, for example due to network congestion or someone interacting with the Apple TV directly.

   If you are watching live and see the wrong program material:

   - Close the channel in your Channels client.
   - Wait about 10 seconds.
   - Select the channel again in the client.

   In most cases, `stopbmitune.sh` will have corrected the tuner state and returned the app to the proper idle search screen. On the next selection, you should see the on‑screen navigation quickly step through the search screen and tune the requested channel. Rarely, you may need to repeat this process.

   To avoid these situations, keep the physical Apple TV remote out of circulation for this device.

2. **Unattended recording limitations**

   There is currently no advanced fault‑tolerance mechanism (such as OCR or a watchdog process) for unattended recordings. On rare occasions, you may get a full recording of:

   - The wrong live stream, or  
   - A static menu screen, or  
   - Another unintended UI state.

   These are treated as edge cases, usually corresponding to network issues or unexpected human interaction with the Apple TV. In general use, the tuner has proven to be very reliable unattended, but the above edge cases should be understood.

   Future versions may explore more sophisticated watchdog or OCR‑based approaches to improve unattended fault tolerance.

## Single‑Channel Limitation and Scheduling Tips

- This tuner can only service **one channel at a time**.
- If you schedule back‑to‑back recordings on different channels, you may need to adjust start and end times.

Practical guidance:

- In many setups you can start recordings “30 seconds early” and stop “On Time” for reliable results.  
- Verify these timing offsets in your own environment. You may need to tweak padding or reschedule overlapping recordings to avoid conflicts.

## Final Notes

Treat the Apple TV as a dedicated Cox Contour tuner for Channels DVR. Keep it always on, avoid using the physical remote for anything other than initial setup, and let the scripts maintain the correct idle state between tunes.

Good luck, and have fun with the Cox Contour Apple TV tuner for Channels DVR!
