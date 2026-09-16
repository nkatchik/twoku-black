# Regression checks

Install the off-device tools outside the channel package, then run:

```sh
npm install --prefix /tmp/twoku-validation --no-audit --no-fund brs@0.45.0 brighterscript@0.73.5
python3 tests/run.py --brs /tmp/twoku-validation/node_modules/.bin/brs
/tmp/twoku-validation/node_modules/.bin/bsc --no-project --create-package false --copy-to-staging false
```

The thirteen suites execute production BrightScript functions. Transport, task fields,
and SceneGraph nodes use deterministic doubles; the runner substitutes platform
primitives that the off-device interpreter does not implement. These checks cover
finite request waits, failed async starts, invalid token/JSON responses, a maximum
of one authentication retry, anonymous startup, parent focus routing, empty grids,
partial content rows, and failed or exhausted pagination. Focus doubles enforce
one active target and walk the parent chain. Navigation checks cover the route to
Login, moving between header and grid, and restoring focus after screen display.
Signed-out sidebar checks cover its placeholder, Login action, empty-list arrows,
and returning to the header when Following has no content. They do not validate
Roku scheduling, rendering, remote input delivery, or playback.

Login suites cover device grant validation, approval polling, slow-down, expiry,
cancellation during polling and validation, late task results, retry, validated
identity/scopes/client ID, form encoding, saved-session restoration, refresh-token
rotation, network failures, and superseded sessions. Follow suites cover modern
endpoints, authenticated user IDs, encoded pagination, repeated cursors, duplicate
streams, sorting, profile batches, empty lists, and failed requests. Home tests
check replacement of followed rows and preserving focus and browse pagination.
The transport tests also verify that user/app tokens use their own client IDs and
that protected requests never fall back to anonymous credentials. External emote
requests carry no Twitch authentication headers.

Live endpoint checks on 2026-09-16 confirmed that Twitch accepts the public client
from `smarttv-twitch` for device-code requests with the requested scopes (HTTP
200, a 30-minute code, five-second polling interval). A deliberately invalid
refresh token returns HTTP 400 `Invalid refresh token`, without requiring a
client secret. These checks did not approve an account or verify a real token
exchange, refresh, or personalized channel response.

At baseline commit `61afe43`, BrighterScript 0.73.5 reports 21 existing errors in
`OfflineChannelList.xml` and `components/web_socket_client/`. The startup patch
must not add diagnostics. Do not interpret that unchanged baseline as a clean
whole-project compile.

## Device acceptance

On Roxton, the user confirmed that `e98d79c` loads content and exits to Roku Home
instantly, but remote navigation remained broken. The user subsequently confirmed that the focus and sidebar build (`2310fc8`)
restored remote navigation. Their login photo showed an HTML error document in
the code label; the retired Heroku register endpoint returned HTTP 404, "No such
app". Login changes still require approval and follow-list verification on Roxton.

1. Sideload the updated ZIP and launch with no saved login. Confirm the header
   responds immediately and content appears. Press Down to enter the grid.
2. Launch while internet access is unavailable. The app should show a connection
   error after the request deadline (10 seconds per request); the header and Home
   button should remain responsive. Restore connectivity, select Live Channels
   or Categories, and confirm retry succeeds.
3. Switch tabs while loading; try an empty result and a category with fewer than
   seven entries. Confirm rows render and the header remains reachable.
4. Return from Search/Options to Home and confirm focus reaches the header or grid.
5. Select Login, enter the code at `www.twitch.tv/activate`, and approve Twellie.
   Confirm Home shows your username, the left rail lists your live followed
   channels, and Following shows live/offline follows. An account with no live
   followed channels should retain usable header focus.
6. Press Back while awaiting approval, then reopen Login. Confirm the cancelled
   attempt cannot complete the new one and a fresh code appears. Let a code expire
   and press OK to retry. Try login with the network disconnected: an error must
   replace the waiting state, never HTML in the code label.
7. Relaunch after successful login and confirm the account restores. Verify a
   real expired session refreshes and browsing remains responsive. Confirm
   returning to Home during a login request does not pause remote input.

Capture a launch log from the device's developer console with
`nc DEVICE_IP 8085` before launching. The new request diagnostics include HTTP
status/failure reasons and avoid printing authentication tokens. Hardware checks
remain pending until performed on the affected device.
