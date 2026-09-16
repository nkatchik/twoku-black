# Local QR encoder

Vendored from [Paramount's BrightScript port of Nayuki's QR generator](https://github.com/paramount-engineering/QR-Code-generator-brightscript),
commit `b5a48b96620e6603078053c8fe7500a23f152b5c`, under MIT (see LICENSE.txt and
source headers).

Local changes remove the Poster renderer and its activation-URL logging, and
replace QRMode/QREcc SceneGraph nodes with plain values. The encoder runs only in
the GetAuth task. `LoginQr.brs` renders its matrix to a temporary PNG at integer
module sizes, with at least four white modules around every edge. No QR service
receives the activation URL. Local fixes also correct array insertion at the end,
explicitly group the finder-corner conditions for BrightScript operator precedence,
and pass boolean colors to the mask penalty helper. Independent ZXing decoding
and frozen Nayuki qrcodegen 1.8.0 matrices verify the activation-link output. Keep this license in
the sideload package.
