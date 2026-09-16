# Startup regression checks

Install the off-device tools outside the channel package, then run:

```sh
npm install --prefix /tmp/twoku-validation --no-audit --no-fund brs@0.45.0 brighterscript@0.73.5
python3 tests/run.py --brs /tmp/twoku-validation/node_modules/.bin/brs
/tmp/twoku-validation/node_modules/.bin/bsc --no-project --create-package false --copy-to-staging false
```

The six suites execute production BrightScript functions. Transport, task fields,
and SceneGraph nodes use deterministic doubles; the runner substitutes platform
primitives that the off-device interpreter does not implement. These checks cover
finite request waits, failed async starts, invalid token/JSON responses, a maximum
of one authentication retry, anonymous startup, parent focus routing, empty grids,
partial content rows, and failed or exhausted pagination. They do not validate
Roku scheduling, rendering, remote input delivery, or playback.

At baseline commit `61afe43`, BrighterScript 0.73.5 reports 21 existing errors in
`OfflineChannelList.xml` and `components/web_socket_client/`. The startup patch
must not add diagnostics. Do not interpret that unchanged baseline as a clean
whole-project compile.

## Device acceptance

1. Sideload the updated ZIP and launch with no saved login. Confirm the header
   responds immediately and content appears. Press Down to enter the grid.
2. Launch while internet access is unavailable. The app should show a connection
   error after the request deadline (10 seconds per request); the header and Home
   button should remain responsive. Restore connectivity, select Live Channels
   or Categories, and confirm retry succeeds.
3. Switch tabs while loading; try an empty result and a category with fewer than
   seven entries. Confirm rows render and the header remains reachable.
4. Return from Search/Options to Home and confirm focus reaches the header or grid.
5. Check a saved login and confirm an expired user token cannot cause an endless
   browse request retry.

Capture a launch log from the device's developer console with
`nc DEVICE_IP 8085` before launching. The new request diagnostics include HTTP
status/failure reasons and avoid printing authentication tokens. Hardware checks
remain pending until performed on the affected device.
