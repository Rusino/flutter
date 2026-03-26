// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

mixin ReferenceCounted {
  int _refCount = 1; // Starts alive (Owned by creator)

  /// Call this when sharing the object (e.g., Cache gives it to UI)
  void retain() {
    if (_refCount <= 0) {
      throw StateError('Cannot retain a disposed object.');
    }
    _refCount++;
  }

  /// Call this when you are done with the object.
  /// If refCount hits 0, the object is actually destroyed.
  void release() {
    if (_refCount <= 0) {
      throw StateError('Double-free: Object is already disposed.');
    }

    _refCount--;

    if (_refCount == 0) {
      disposeInternal();
    }
  }

  /// Override this method to perform actual cleanup.
  /// It is public so the mixin can call it, but
  /// you should strictly treat it as internal.
  void disposeInternal();

  bool get isAlive => _refCount > 0;

  int get refCount => _refCount;
}
