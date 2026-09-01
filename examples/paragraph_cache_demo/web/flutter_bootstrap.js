// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

{{flutter_js}}
{{flutter_build_config}}

const searchParams = new URLSearchParams(window.location.search);
let preferWebParagraph = true; // Default

if (searchParams.has('ck')) {
  preferWebParagraph = false;
} else if (searchParams.has('wp')) {
  preferWebParagraph = true;
}

_flutter.loader.load({
  config: {
    preferWebParagraph: preferWebParagraph,
    renderer: "canvaskit"
  },
});
