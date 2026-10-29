// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;

/// Represents a slot allocated for a rasterized paragraph inside a [WebParagraphAtlas] page.
class AtlasParagraphSlot {
  AtlasParagraphSlot({
    required this.page,
    required this.sourceRect,
    required this.effectiveScaleX,
    required this.effectiveScaleY,
  });

  static const double _scaleEpsilon = 0.001;

  final AtlasPage page;
  final ui.Rect sourceRect;
  final double effectiveScaleX;
  final double effectiveScaleY;

  /// Checks whether two scale pairs match within [_scaleEpsilon].
  static bool matchesAtlasScale(double aX, double aY, double bX, double bY) {
    return (aX - bX).abs() < _scaleEpsilon && (aY - bY).abs() < _scaleEpsilon;
  }

  /// Whether this slot is on an active atlas page bound to [surface].
  bool isValidOnSurface(CkOffscreenSurface? surface) {
    if (surface == null || !page.isActive) {
      return false;
    }
    return identical(WebParagraphAtlas.instance.boundSurface, surface) &&
        WebParagraphAtlas.instance.boundGlContext == surface.glContextHandle;
  }

  /// Whether this slot is still valid on the currently bound atlas page and scale.
  bool isValidFor({
    required CkOffscreenSurface surface,
    required double effectiveScaleX,
    required double effectiveScaleY,
  }) {
    return isValidOnSurface(surface) &&
        matchesAtlasScale(
          this.effectiveScaleX,
          this.effectiveScaleY,
          effectiveScaleX,
          effectiveScaleY,
        );
  }
}

class _AtlasShelf {
  _AtlasShelf({required this.y, required this.height});

  final int y;
  final int height;
  int cursorX = 0;
}

/// A 2048x2048 GPU-backed atlas page shared across multiple [WebParagraph] instances.
class AtlasPage {
  AtlasPage({
    required this.offscreenCanvas,
    required this.context2D,
    required this.glTexture,
    required this.engineImage,
    required this.imageSource,
    required this.isZeroCopy,
  });

  final DomOffscreenCanvas offscreenCanvas;
  final DomCanvasRenderingContext2D context2D;
  final JSObject glTexture;
  final EngineImage engineImage;
  final AtlasPageImageSource imageSource;
  final bool isZeroCopy;

  int lastUsedTick = 0;
  bool activeSharedRead = false;
  bool isDisposed = false;
  bool isEvicted = false;

  /// Whether this page is currently active and capable of receiving new slots or hits.
  bool get isActive => !isDisposed && !isEvicted;

  final List<_AtlasShelf> _shelves = <_AtlasShelf>[];
  int _nextShelfY = 0;

  int _dirtyMinX = WebParagraphAtlas.pageSize;
  int _dirtyMinY = WebParagraphAtlas.pageSize;
  int _dirtyMaxX = 0;
  int _dirtyMaxY = 0;

  bool get hasDirtyRect => _dirtyMinX < _dirtyMaxX && _dirtyMinY < _dirtyMaxY;
  int get dirtyMinX => _dirtyMinX;
  int get dirtyMinY => _dirtyMinY;
  int get dirtyWidth => _dirtyMaxX - _dirtyMinX;
  int get dirtyHeight => _dirtyMaxY - _dirtyMinY;

  void markDirtyRect(int x, int y, int width, int height) {
    _dirtyMinX = math.min(_dirtyMinX, math.max(0, x));
    _dirtyMinY = math.min(_dirtyMinY, math.max(0, y));
    _dirtyMaxX = math.max(_dirtyMaxX, math.min(WebParagraphAtlas.pageSize, x + width));
    _dirtyMaxY = math.max(_dirtyMaxY, math.min(WebParagraphAtlas.pageSize, y + height));
  }

  void clearDirtyRect() {
    _dirtyMinX = WebParagraphAtlas.pageSize;
    _dirtyMinY = WebParagraphAtlas.pageSize;
    _dirtyMaxX = 0;
    _dirtyMaxY = 0;
  }

  (int slotX, int slotY)? tryAllocate(int width, int height) {
    if (!isActive) {
      return null;
    }
    final int paddedWidth = width + 2 * WebParagraphAtlas.gutter;
    final int paddedHeight = height + 2 * WebParagraphAtlas.gutter;
    if (paddedWidth > WebParagraphAtlas.pageSize || paddedHeight > WebParagraphAtlas.pageSize) {
      return null;
    }

    _AtlasShelf? bestShelf;
    for (final _AtlasShelf shelf in _shelves) {
      if (shelf.height >= paddedHeight &&
          shelf.height <= paddedHeight + WebParagraphAtlas.maxShelfSlack &&
          shelf.cursorX + paddedWidth <= WebParagraphAtlas.pageSize) {
        if (bestShelf == null || shelf.height < bestShelf.height) {
          bestShelf = shelf;
        }
      }
    }

    if (bestShelf == null) {
      if (_nextShelfY + paddedHeight > WebParagraphAtlas.pageSize) {
        return null;
      }
      bestShelf = _AtlasShelf(y: _nextShelfY, height: paddedHeight);
      _shelves.add(bestShelf);
      _nextShelfY += paddedHeight;
    }

    final int slotX = bestShelf.cursorX + WebParagraphAtlas.gutter;
    final int slotY = bestShelf.y + WebParagraphAtlas.gutter;
    bestShelf.cursorX += paddedWidth;
    return (slotX, slotY);
  }

  void dispose() {
    if (isDisposed) {
      return;
    }
    isDisposed = true;
    engineImage.dispose();
    offscreenCanvas.width = 0;
    offscreenCanvas.height = 0;
  }
}

/// Manages shelf-allocated 2048x2048 [DomOffscreenCanvas] pages bridged into CanvasKit's
/// WebGL context via zero-copy `ClientSharedImage` (`WebGLUnownedTexture`) when available,
/// with an automatic GPU-to-GPU sub-rect `texSubImage2D` fallback.
class WebParagraphAtlas {
  WebParagraphAtlas._();

  static final WebParagraphAtlas instance = WebParagraphAtlas._();

  static const int pageSize = 2048;
  static const int gutter = 1;
  static const int maxSlotDimension = pageSize - 2 * gutter;
  static const int maxPages = 4;
  static const int maxShelfSlack = 32;

  final List<AtlasPage> _pages = <AtlasPage>[];
  final List<AtlasPage> _retiredPages = <AtlasPage>[];
  CkOffscreenSurface? _boundSurface;
  int _boundGlContext = -1;
  int _tick = 0;
  int _flushDepth = 0;

  @visibleForTesting
  bool debugForceFallbackUpload = false;

  @visibleForTesting
  int debugSubImageUploadCount = 0;

  @visibleForTesting
  int get debugPageCount => _pages.length;

  @visibleForTesting
  int get debugRetiredPageCount => _retiredPages.length;

  CkOffscreenSurface? get boundSurface => _boundSurface;
  int get boundGlContext => _boundGlContext;

  /// Returns the shared [CkOffscreenSurface] if hardware-accelerated single-GL-context
  /// atlas rendering is active, or `null` when standalone image fallback must be used.
  CkOffscreenSurface? resolveTargetSurface() {
    if (CanvasKitRenderer.instance.isSoftware) {
      return null;
    }
    if (!browserSupportsOffscreenCanvas) {
      return null;
    }
    final Rasterizer currentRasterizer = CanvasKitRenderer.instance.rasterizer;
    if (currentRasterizer is! OffscreenCanvasRasterizer) {
      return null;
    }
    final OffscreenSurface offscreen = currentRasterizer.offscreenSurface;
    if (offscreen is! CkOffscreenSurface ||
        offscreen.isSoftware ||
        offscreen.skSurface == null ||
        offscreen.glContextHandle <= 0) {
      return null;
    }
    return offscreen;
  }

  /// Disposes all atlas pages and resets tracking state.
  void reset() {
    for (final AtlasPage page in _pages) {
      page.dispose();
    }
    _pages.clear();
    for (final AtlasPage page in _retiredPages) {
      page.dispose();
    }
    _retiredPages.clear();
    _boundSurface = null;
    _boundGlContext = -1;
  }

  void _ensureBoundToSurface(CkOffscreenSurface surface) {
    if (!identical(_boundSurface, surface) || _boundGlContext != surface.glContextHandle) {
      reset();
      _boundSurface = surface;
      _boundGlContext = surface.glContextHandle;
    }
  }

  void _onRetiredPageReleased(AtlasPage page) {
    if (page.isEvicted && !page.isDisposed) {
      _retiredPages.remove(page);
      page.dispose();
    }
  }

  /// Rasterizes a paragraph via [paintToCanvas2D] into a shelf-allocated atlas slot.
  AtlasParagraphSlot? rasterizeIntoSlot({
    required CkOffscreenSurface surface,
    required int width,
    required int height,
    required double effectiveScaleX,
    required double effectiveScaleY,
    required ParagraphCanvas2DPainter paintToCanvas2D,
  }) {
    if (width <= 0 || height <= 0 || width > maxSlotDimension || height > maxSlotDimension) {
      return null;
    }
    _ensureBoundToSurface(surface);

    AtlasPage? targetPage;
    (int, int)? coords;

    for (final AtlasPage page in _pages) {
      coords = page.tryAllocate(width, height);
      if (coords != null) {
        targetPage = page;
        break;
      }
    }

    if (targetPage == null || coords == null) {
      if (_pages.length < maxPages) {
        targetPage = _createPage(surface);
        if (targetPage == null) {
          return null;
        }
        _pages.add(targetPage);
      } else {
        final AtlasPage? newPage = _createPage(surface);
        if (newPage == null) {
          return null;
        }
        AtlasPage lruPage = _pages.first;
        for (var i = 1; i < _pages.length; i++) {
          if (_pages[i].lastUsedTick < lruPage.lastUsedTick) {
            lruPage = _pages[i];
          }
        }
        _pages.remove(lruPage);
        lruPage.isEvicted = true;
        if (lruPage.imageSource.refCount <= 1) {
          lruPage.dispose();
        } else {
          _retiredPages.add(lruPage);
        }
        _pages.add(newPage);
        targetPage = newPage;
      }
      coords = targetPage.tryAllocate(width, height);
      if (coords == null) {
        return null;
      }
    }

    final (int slotX, int slotY) = coords;
    final DomCanvasRenderingContext2D ctx = targetPage.context2D;

    // Clear the slot including its 1px gutter border so bilinear or clip edges never bleed.
    ctx.clearRect(slotX - gutter, slotY - gutter, width + 2 * gutter, height + 2 * gutter);
    ctx.save();
    try {
      ctx.beginPath();
      ctx.rect(slotX, slotY, width, height);
      ctx.clip();
      ctx.translate(slotX, slotY);
      ctx.scale(effectiveScaleX, effectiveScaleY);
      paintToCanvas2D(ctx);
    } finally {
      ctx.restore();
    }

    targetPage.markDirtyRect(
      slotX - gutter,
      slotY - gutter,
      width + 2 * gutter,
      height + 2 * gutter,
    );
    targetPage.lastUsedTick = ++_tick;

    return AtlasParagraphSlot(
      page: targetPage,
      sourceRect: ui.Rect.fromLTWH(
        slotX.toDouble(),
        slotY.toDouble(),
        width.toDouble(),
        height.toDouble(),
      ),
      effectiveScaleX: effectiveScaleX,
      effectiveScaleY: effectiveScaleY,
    );
  }

  /// Marks [slot] as used during the current frame for LRU page eviction ordering.
  void markSlotUsed(AtlasParagraphSlot slot) {
    slot.page.lastUsedTick = ++_tick;
  }

  /// Synchronizes all atlas pages on [surface] around a Skia GPU flush or snapshot.
  T withSurfaceFlush<T>(CkSurface surface, T Function() action) {
    if ((_pages.isEmpty && _retiredPages.isEmpty) ||
        _flushDepth > 0 ||
        !identical(surface, _boundSurface) ||
        surface is! CkOffscreenSurface ||
        surface.glContextHandle != _boundGlContext ||
        surface.skSurface == null) {
      return action();
    }

    _flushDepth++;
    _beginSurfaceRead(surface);
    try {
      return action();
    } finally {
      _endSurfaceRead(surface);
      _flushDepth--;
    }
  }

  void _beginSurfaceRead(CkOffscreenSurface surface) {
    final WebGLContext gl = surface.offscreenCanvas.getGlContext(webGLVersion);
    if (gl.isContextLost()) {
      return;
    }

    var mutatedGlBindings = false;
    void syncPage(AtlasPage page) {
      if (page.isZeroCopy) {
        page.activeSharedRead = gl.beginCanvasSharedImageReadUnsafe(page.glTexture);
        if (page.activeSharedRead) {
          page.clearDirtyRect();
        }
      } else if (page.hasDirtyRect) {
        gl.bindTexture(WebGLContext.texture2D, page.glTexture);
        gl.pixelStorei(WebGLContext.unpackPremultiplyAlphaWebgl, 1);
        if (webGLVersion >= 2) {
          gl.pixelStorei(WebGLContext.unpackSkipPixels, page.dirtyMinX);
          gl.pixelStorei(WebGLContext.unpackSkipRows, page.dirtyMinY);
          gl.texSubImage2DCanvasWebGL2(
            WebGLContext.texture2D,
            0,
            page.dirtyMinX,
            page.dirtyMinY,
            page.dirtyWidth,
            page.dirtyHeight,
            WebGLContext.rgba,
            WebGLContext.unsignedByte,
            page.offscreenCanvas,
          );
          gl.pixelStorei(WebGLContext.unpackSkipPixels, 0);
          gl.pixelStorei(WebGLContext.unpackSkipRows, 0);
        } else {
          gl.texSubImage2DCanvasWebGL1(
            WebGLContext.texture2D,
            0,
            0,
            0,
            WebGLContext.rgba,
            WebGLContext.unsignedByte,
            page.offscreenCanvas,
          );
        }
        gl.pixelStorei(WebGLContext.unpackPremultiplyAlphaWebgl, 0);
        gl.bindTexture(WebGLContext.texture2D, null);
        page.clearDirtyRect();
        mutatedGlBindings = true;
        assert(() {
          debugSubImageUploadCount++;
          return true;
        }());
      }
    }

    _pages.forEach(syncPage);
    _retiredPages.forEach(syncPage);

    if (mutatedGlBindings) {
      surface.skSurface!.resetContext();
    }
  }

  void _endSurfaceRead(CkOffscreenSurface surface) {
    final WebGLContext gl = surface.offscreenCanvas.getGlContext(webGLVersion);
    final bool contextLost = gl.isContextLost();
    void endPage(AtlasPage page) {
      if (page.activeSharedRead) {
        page.activeSharedRead = false;
        if (!contextLost) {
          gl.endCanvasSharedImageReadUnsafe(page.glTexture);
        }
      }
    }

    _pages.forEach(endPage);
    _retiredPages.forEach(endPage);
  }

  AtlasPage? _createPage(CkOffscreenSurface surface) {
    final DomOffscreenCanvas offscreen = createDomOffscreenCanvas(pageSize, pageSize);
    final DomCanvasRenderingContext2D ctx2d = offscreen.context2D;
    // Materialize the accelerated Canvas2DResourceProviderSharedImage before attaching.
    ctx2d.fillStyle = 'rgba(0, 0, 0, 0)';
    ctx2d.fillRect(0, 0, 1, 1);
    ctx2d.clearRect(0, 0, 1, 1);

    final WebGLContext gl = surface.offscreenCanvas.getGlContext(webGLVersion);
    if (gl.isContextLost()) {
      offscreen.width = 0;
      offscreen.height = 0;
      return null;
    }

    JSObject? glTexture;
    var isZeroCopy = false;
    if (!debugForceFallbackUpload && gl.supportsSharedImageAtlas) {
      glTexture = gl.attachCanvasSharedImageUnsafe(offscreen);
      if (glTexture != null) {
        isZeroCopy = true;
      }
    }

    if (glTexture == null) {
      glTexture = gl.createTexture();
      if (glTexture == null) {
        offscreen.width = 0;
        offscreen.height = 0;
        return null;
      }
      gl.bindTexture(WebGLContext.texture2D, glTexture);
      gl.texParameteri(WebGLContext.texture2D, WebGLContext.textureMinFilter, WebGLContext.linear);
      gl.texParameteri(WebGLContext.texture2D, WebGLContext.textureMagFilter, WebGLContext.linear);
      gl.texParameteri(WebGLContext.texture2D, WebGLContext.textureWrapS, WebGLContext.clampToEdge);
      gl.texParameteri(WebGLContext.texture2D, WebGLContext.textureWrapT, WebGLContext.clampToEdge);
      gl.texImage2DEmpty(
        WebGLContext.texture2D,
        0,
        WebGLContext.rgba,
        pageSize,
        pageSize,
        0,
        WebGLContext.rgba,
        WebGLContext.unsignedByte,
        null,
      );
      gl.bindTexture(WebGLContext.texture2D, null);
    }

    final SkSurface skSurface = surface.skSurface!;
    skSurface.resetContext();

    final imageInfo = SkImageInfo(
      alphaType: canvasKit.AlphaType.Premul,
      colorType: canvasKit.ColorType.RGBA_8888,
      colorSpace: SkColorSpaceSRGB,
      width: pageSize.toDouble(),
      height: pageSize.toDouble(),
    );
    final SkImage? skImage = skSurface.makeImageFromTexture(glTexture, imageInfo);
    if (skImage == null) {
      gl.deleteTexture(glTexture);
      offscreen.width = 0;
      offscreen.height = 0;
      return null;
    }

    late final AtlasPage page;
    final imageSource = AtlasPageImageSource(
      offscreen,
      pageSize,
      pageSize,
      onLastPictureReleased: () => _onRetiredPageReleased(page),
    );
    final engineImage = EngineImage(
      CkImageDelegate(skImage),
      pageSize,
      pageSize,
      imageSource: imageSource,
      notifyInstrumentation: false,
    );
    page = AtlasPage(
      offscreenCanvas: offscreen,
      context2D: ctx2d,
      glTexture: glTexture,
      engineImage: engineImage,
      imageSource: imageSource,
      isZeroCopy: isZeroCopy,
    );
    return page;
  }
}
