// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:ui/src/engine.dart';
import 'package:ui/ui_web/src/ui_web.dart' as ui_web;

/// This class is responsible for registering and loading fonts.
///
/// Once an asset manager has been set in the framework, call [loadAssetFonts] with it to register
/// fonts declared in the font manifest.
class WebFontCollection implements FlutterFontCollection {
  /// Reads the font manifest using the [ui_web.assetManager] and downloads all of the
  /// fonts declared within.
  @override
  Future<AssetFontsResult> loadAssetFonts(FontManifest manifest) async {
    final pendingFonts = <Future<(String, FontLoadError?)>>[];
    for (final FontFamily family in manifest.families) {
      for (final FontAsset fontAsset in family.fontAssets) {
        pendingFonts.add(() async {
          return (
            fontAsset.asset,
            await _loadFontAsset(family.name, fontAsset.asset, fontAsset.descriptors),
          );
        }());
      }
    }

    final loadedFonts = <String>[];
    final fontFailures = <String, FontLoadError>{};
    for (final (String asset, FontLoadError? error) in await Future.wait(pendingFonts)) {
      if (error == null) {
        loadedFonts.add(asset);
      } else {
        fontFailures[asset] = error;
      }
    }
    return AssetFontsResult(loadedFonts, fontFailures);
  }

  @override
  Future<bool> loadFontFromBytes(Uint8List list, {String? fontFamily}) async {
    if (fontFamily == null) {
      printWarning('Font family must be provided to WebFontCollection.');
      return false;
    }
    return _loadFontFaceBytes(fontFamily, list);
  }

  @override
  FontFallbackManager get fontFallbackManager => throw UnimplementedError(
    "fontFallbackManager is not supported in WebFontCollection as it uses the browser's native font fallback.",
  );

  @override
  set fontFallbackManager(FontFallbackManager? value) {
    throw UnimplementedError(
      "fontFallbackManager is not supported in WebFontCollection as it uses the browser's native font fallback.",
    );
  }

  @override
  FallbackFontRegistry? get fallbackFontRegistry => null;

  @override
  set fallbackFontRegistry(FallbackFontRegistry? value) {}

  /// Unregister all fonts that have been registered.
  @override
  void clear() {
    domDocument.fonts!.clear();
  }

  // Regular expression to detect a string with no punctuations.
  // For example font family 'Ahem!' does not fall into this category
  // so the family name will be wrapped in quotes.
  static final RegExp notPunctuation = RegExp(r'[a-z0-9\s]+', caseSensitive: false);
  // Regular expression to detect tokens starting with a digit.
  // For example font family 'Goudy Bookletter 1911' falls into this
  // category.
  static final RegExp startWithDigit = RegExp(r'\b\d');

  /// Registers assets to Flutter Web Engine.
  Future<FontLoadError?> _loadFontAsset(
    String family,
    String asset,
    Map<String, String> descriptors,
  ) async {
    final ByteData data;
    try {
      // Fetch the font binary upfront so OpenType fvar axes can be inspected
      // before constructing the browser FontFace.
      data = await ui_web.assetManager.load(asset);
    } on HttpFetchNoPayloadError {
      return FontNotFoundError(asset);
    } catch (e) {
      return FontDownloadError(asset, e);
    }

    try {
      final Uint8List list = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final Map<String, String> varDescriptors = _extractVariableDescriptors(list);
      // Populate descriptors from fvar axes if not explicitly specified in the manifest.
      if (varDescriptors.isNotEmpty) {
        descriptors = Map<String, String>.of(descriptors);
        varDescriptors.forEach((String key, String value) {
          if (!descriptors.containsKey(key)) {
            descriptors[key] = value;
          }
        });
      }

      // Right now, this is only used in Chrome which accepts unquoted font family names.
      // However, in the future, we should examine other browsers and see if they require
      // quoting for certain font family names.
      // Pass the URL and merged variable axis descriptors to FontFace.
      final DomFontFace fontFace = await _loadFontFace(family, asset, descriptors);
      domDocument.fonts!.add(fontFace);
    } on FontLoadError catch (error) {
      return error;
    } catch (e) {
      return FontInvalidDataError(asset);
    }
    return null;
  }

  Future<DomFontFace> _loadFontFace(
    String family,
    String asset,
    Map<String, String> descriptors,
  ) async {
    // Catch font parsing or download errors from createDomFontFace or fontFace.load.
    try {
      final DomFontFace fontFace = createDomFontFace(
        family,
        'url(${ui_web.assetManager.getAssetUrl(asset)})',
        descriptors,
      );
      return await fontFace.load();
    } catch (e) {
      printWarning('Error while loading font family "$family":\n$e');
      throw FontDownloadError(asset, e);
    }
  }

  // Loads a font from bytes, surfacing errors through the future.
  Future<bool> _loadFontFaceBytes(String family, Uint8List list) async {
    // Since these fonts are loaded by user code, surface the error
    // through the returned future.
    try {
      // Inspect variable font axes to allow arbitrary weights for in-memory fonts.
      Map<String, String>? descriptors;
      final Map<String, String> varDescriptors = _extractVariableDescriptors(list);
      if (varDescriptors.isNotEmpty) {
        descriptors = varDescriptors;
      }
      final DomFontFace fontFace = createDomFontFace(family, list, descriptors);
      if (fontFace.status == 'error') {
        // Font failed to load.
        return false;
      }
      domDocument.fonts!.add(fontFace);

      // There might be paragraph measurements for this new font before it is
      // loaded. They were measured using fallback fonts, so we should clear the
      // cache.
      // TODO(jlavrova): https://github.com/flutter/flutter/issues/168001
    } catch (e) {
      // Failures here will throw a DomException. Return false.
      printWarning('Failed to load font "$family" from bytes: $e');
      return false;
    }
    return true;
  }

  // Extracts variable font axis ranges from the OpenType fvar table.
  // Browser FontFace defaults to static weight 400 unless explicit ranges are provided.
  Map<String, String> _extractVariableDescriptors(Uint8List bytes) {
    final descriptors = <String, String>{};
    if (bytes.lengthInBytes < 12) {
      return descriptors;
    }

    final data = ByteData.sublistView(bytes);
    final int sfntVersion = data.getUint32(0);
    var fontOffset = 0;

    if (sfntVersion == 0x74746366) {
      // TrueType Collection ('ttcf') header.
      if (bytes.lengthInBytes < 16) {
        return descriptors;
      }
      final int numFonts = data.getUint32(8);
      if (numFonts > 0) {
        fontOffset = data.getUint32(12);
      } else {
        return descriptors;
      }
    }

    if (fontOffset + 12 > data.lengthInBytes) {
      return descriptors;
    }
    final int numTables = data.getUint16(fontOffset + 4);

    var fvarOffset = 0;
    for (var i = 0; i < numTables; i++) {
      final int tableOffset = fontOffset + 12 + i * 16;
      if (tableOffset + 16 > data.lengthInBytes) {
        return descriptors;
      }
      final int tag = data.getUint32(tableOffset);
      if (tag == 0x66766172) {
        // OpenType Font Variations ('fvar') table.
        fvarOffset = data.getUint32(tableOffset + 8);
        break;
      }
    }

    if (fvarOffset == 0 || fvarOffset + 16 > data.lengthInBytes) {
      return descriptors;
    }

    final int axesArrayOffset = data.getUint16(fvarOffset + 4);
    final int axisCount = data.getUint16(fvarOffset + 8);
    final int axisSize = data.getUint16(fvarOffset + 10);

    final int axesStart = fvarOffset + axesArrayOffset;
    if (axesStart + axisCount * axisSize > data.lengthInBytes) {
      return descriptors;
    }

    var hasWght = false;
    var hasItal = false;
    var hasSlnt = false;
    var hasWdth = false;

    for (var i = 0; i < axisCount; i++) {
      final int axisRecord = axesStart + i * axisSize;
      final int axisTag = data.getUint32(axisRecord);
      if (axisTag == 0x77676874) {
        hasWght = true;
      }
      if (axisTag == 0x6974616C) {
        hasItal = true;
      }
      if (axisTag == 0x736C6E74) {
        hasSlnt = true;
      }
      if (axisTag == 0x77647468) {
        hasWdth = true;
      }
    }

    if (hasWght) {
      descriptors['weight'] = '1 1000';
    }
    if (hasItal || hasSlnt) {
      descriptors['style'] = 'oblique -90deg 90deg';
    }
    if (hasWdth) {
      descriptors['stretch'] = '0% 2000%';
    }

    return descriptors;
  }

  @override
  void debugResetFallbackFonts() {}
}
