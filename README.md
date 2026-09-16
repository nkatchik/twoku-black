![Splash](https://i.imgur.com/LXhqf4J.png)

![Overview](https://i.imgur.com/zcRYrNe.jpg)

# 🔮 Twoku (for Roku)
An Improvable™ Twitch app for Roku. Still buggy, so feel free to suggest improvements (and code and features). Unfortunately, the code is very disorganized and messy because the original developers knew nothing about Roku development when they started on this.

Also, the original devs have not been very active with this project recently. So if you can contribute, please do. There are still many desirable features that have not been added (just go on the Discord).

## Discord
If you have any questions or comments (or phishing links):

[![Discord](https://discordapp.com/api/guilds/721488568303878155/widget.png?style=banner2)](https://discord.gg/kV5SXkZ)

## Support
If you would like to support Twoku:

 [![Support with PayPal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=YRPQDG5UY26DS&currency_code=CAD&source=url)

## Contributing
If you have an idea (feature, etc.) that you would like to contribute (with code) to the project with, DM one of the developers on the Discord with your idea. Otherwise, if you just have an idea, post it in the ```#features``` channel on the Discord server. You can also just fork this repository as its up to date and implement the feature yourself.

## How to Install
### With Access Code
<em>As of February 23, 2022, the first two codes below no longer work because of Roku's shutdown of private channels. However, the third code below (Twoku Public) still works for us and many others. If that code does not work for you, try the manual developer install described below.</em>

~~Install with access code: TWOKU (https://my.roku.com/account/add?channel=TWOKU)~~

~~Beta version: TTWOKU (https://my.roku.com/account/add?channel=TTWOKU)~~

Twoku Public (should be available for users in Mexico and Brazil): C6ZVZD (https://my.roku.com/account/add?channel=C6ZVZD)

### Manual Developer Install
1. [Enable developer mode for Roku](https://blog.roku.com/developer/developer-setup-guide)
2. Log into your Roku from your browser using IP from previous step (http://192.168.x.x)
3. ZIP (into a ZIP file) all contents of this repo (you do not have to include README.md) (using 7-Zip, WinRAR, etc.). Do not include extra top level directories in the ZIP file, otherwise you may get the error: "```Install Failure: No manifest. Invalid package.```". Alternatively, you can download this ZIP file by clicking [here](https://drive.google.com/uc?export=download&id=1oMOxn41NAAq8CxULCr7VJ-WwFSdvdQ5-).
4. Upload previous ZIP file in Roku Development Application Installer (step 2)
5. Press Install
6. Twoku should now be installed on your Roku. You should see it at the end of your channel list

## Twitch login

Select **Login** in the header and scan the QR code with your phone. It opens
Twitch's activation page with the code already filled in. You can also open
[twitch.tv/activate](https://www.twitch.tv/activate) and enter the displayed code.
The QR image is generated locally on the Roku. Approve access;
the app returns to Home and loads your username and followed channels. **Back**
cancels the attempt; **OK** requests a new code after an error or expiration.
Once signed in, the account chip opens your account view with **Log out**.
Viewing the account keeps the current session; logging out clears saved
credentials and followed channels, then returns to Channels.

Login uses Twitch's official device-code flow, based on
[nkatchik/smarttv-twitch](https://github.com/nkatchik/smarttv-twitch/blob/main/src/core/twitch/auth.js).
It shares that project's registered public **Twellie** client, so Twitch's consent
page uses that application name. The requested permissions are followed-channel
access (`user:read:follows`) and IRC chat (`chat:read`, `chat:edit`). No password
or client secret is entered on the TV. Access and refresh tokens stay in the Roku
registry; validation and refresh go directly to Twitch. The retired Heroku login
service is no longer used.

The public login client ID is configured in `components/UrlFunctions.brs`.
User tokens use that client ID for Helix; anonymous Helix and GraphQL requests
retain their separate matching client IDs. Saved sessions are validated at launch
and during the five-minute followed-channel refresh. `GetUser` is the sole owner
of refresh-token rotation. Followed channels use Twitch's current
`streams/followed` and `channels/followed` endpoints.

## Navigation and playback

The interface follows [Twellie](https://github.com/nkatchik/smarttv-twitch): dark
backgrounds, white focus outlines, four-column grids, a compact account chip,
and the same bottom player controls and quality popup. Channels, Games,
Following, Search, and Login are in the header. The old Settings screen and
its button have been removed; followed channels live in the Following tab.
The Twellie TV mark comes from that project's `src/assets/logo.png`; its GPLv3
license is included as `images/twellie-logo-LICENSE.txt`.

Use **Up** from the first grid row to reach the tabs and **Down** to return.
**OK** on a live channel opens it immediately. ***** on a channel card opens
its channel page and past broadcasts, with the channel's follower count.
Following combines live channels and offline profiles in one scrolling list;
**Back** from a profile returns to the same followed channel. Games requests
285×380 covers to match the displayed cards. Pending requests use native Roku
spinners; errors and empty results retain text.

During playback, **OK** or an arrow reveals the controls. **Left/Right** moves
between Channel, Chat (live only), and Quality. ***** opens Quality directly;
**Up/Down** chooses a rendition, **OK** applies it, and **Back** dismisses it.
The selected quality and live-chat preference persist. Chat is read-only, as
in Twellie, and is disconnected while hidden.

**Auto** prefers the highest-resolution rendition matching the device's reported
video output and decoder capabilities, then the highest frame rate at that
resolution. This includes 60fps when supported. These are preferences, never
playback restrictions: if no rendition matches, Auto attempts the best available
quality and uses the normal bounded playback recovery. Missing metadata stays
unverified; it cannot mean that every stream is unsupported. Every video rendition
remains selectable, including saved manual preferences and qualities with codec,
resolution, or frame-rate hints outside the reported device capabilities.
Live/VOD Auto recommendations use playlist dimensions, frame rate, and AVC profile/level;
clips expose less metadata, so their width and AVC profile are explicitly estimated
from Twitch's reported rendition height and frame rate.

Network adaptation is separate: three successful video-segment downloads taking
longer than their playback duration trigger a lower-bitrate choice within 80% of
measured throughput on direct playback. Repaired fMP4 uses a local relay, so its
native download timings are excluded from this calculation; buffering and progress
watchdogs still apply. Auto can also try an untried lower quality after a native
error, prolonged buffering, or stalled playback. It stops retrying when eligible
qualities are exhausted. Failed live streams retain the player controls instead
of returning to the grid. Quality switches preserve VOD/clip
position and pause state. Left/Right on the progress bar or the rewind/fast-forward
keys seek by ten seconds. Play/Pause toggles recorded playback.

**Back** closes the quality popup, then the controls, then visible chat, then
returns to browsing. During a playback error or loading state it returns
immediately. Native decoder shutdown uses asynchronous stop on Roku versions
that provide it (OS 12.5+); older versions retain the platform's synchronous stop.
The UI keeps remote focus while the decoder loads or stops.

Live/VOD playlists and signed clip URLs are resolved directly from Twitch over
HTTPS, with bounded requests. Some current Twitch deliveries combine audio and
video in fragmented MP4 segments, which [Roku does not support for
CMAF](https://developer.roku.com/dev/docs/media). The app now includes an experimental
compatibility Task: it exposes separate audio/video HLS renditions through a
loopback HTTP listener, changing container metadata without transcoding. Both
views share downloaded original segments. Ordinary MPEG-TS and clips remain
direct; unsupported preparation also falls back to the original URL.

The Task has bounded caches and transfers, runs independently of the UI, and is
cancelled on exit or quality changes. No external server or configuration is
needed. See the [delivery investigation](docs/playback-compatibility.md) for the
implementation, media validation, and remaining native checks. Off-device tests
verify unchanged packets and decoded frames; sustained Roxton playback, audio/video
synchronization, and CPU usage still require device testing.

## Supported Features
* Live channels and games, ordered by viewers
* Search for live/offline channels and games
* Followed live and offline channels
* Category clips from the last seven days, with quality selection
* Read-only live chat
* VODs with seeking and quality selection (except subscriber-only)
* QR-based Twitch sign-in

## Notable Unsupported Features
* VOD chat and chat message entry
* Subscriber-only VODs
