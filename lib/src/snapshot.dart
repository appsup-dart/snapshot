part of '../snapshot.dart';

/// A Snapshot holds immutable data that represents part of the content of a
/// (remote) database at some moment.
///
/// It typically contains JSON-like data received through a network connection.
/// The content can however also be easily converted to other data types, like
/// [DateTime] or [Uri]. The instance method [Snapshot.as] makes this conversion and
/// caches the result, so that subsequent calls with the same type parameter do
/// not invoke a new conversion.
@immutable
abstract class Snapshot implements DeepImmutable {
  /// The decoder that will be used to decode content
  final SnapshotDecoder decoder;

  Snapshot._({SnapshotDecoder? decoder})
      : decoder = decoder ?? SnapshotDecoder.defaultDecoder;

  /// Creates an empty snapshot with the specified decoder
  ///
  /// When [decoder] is null, the [SnapshotDecoder.defaultDecoder] will be used
  factory Snapshot.empty({SnapshotDecoder? decoder}) =>
      Snapshot.fromJson(null, decoder: decoder);

  /// Creates a snapshot from the JSON-like [content]
  ///
  /// [content] will be converted to an unmodifiable object first, so that the
  /// deep immutability of a snapshot is guaranteed.
  ///
  /// When [decoder] is null, the [SnapshotDecoder.defaultDecoder] will be used
  factory Snapshot.fromJson(dynamic content, {SnapshotDecoder? decoder}) =>
      _SnapshotImpl(content, decoder: decoder);

  /// The [Snapshot] that represents a (grand)child of this Snapshot.
  ///
  /// The path should be in a JSON pointer format
  /// ([RFC 6901](https://tools.ietf.org/html/rfc6901)). The leading `/` is
  /// optional. Therefore, the following two expressions are equivalent
  ///
  ///     snapshot.child('firstname')
  ///     snapshot.child('/firstname')
  ///
  /// The returned children are cached. Subsequent calls to [child] will return
  /// the exact same object. Also, the result of a call with a [path] with
  /// multiple segments will result in the exact same object as recursive calls
  /// to [child] with the different segments:
  ///
  ///     snapshot.child('address/city') == snapshot.child('address').child('city')
  ///
  /// When the content of this snapshot is not a [Map] or [List], an empty
  /// snapshot will be returned.
  ///
  /// When the content is a [Map], the first segment of the path will be used as
  /// key and the returned child will have the content of the child in this map
  /// that corresponds to this key. When the map does not have a child with this
  /// key or that child is equal to null, an empty [Snapshot] will be returned.
  /// Therefore, it is not possible to distinguish between a non-existing child
  /// and a null-child.
  ///
  /// When the content is a [List], the first segment of the path will be
  /// converted to an integer and used as index. When this conversion fails or
  /// the index is out of range, an empty snapshot will be returned.
  Snapshot child(String path);

  /// The raw content of this snapshot
  ///
  /// This value is deep immutable
  dynamic /*Immutable*/ get value;

  /// Returns the content of this snapshot as an object of type T.
  ///
  /// When the content is `null` or of type T, the content will be returned as
  /// is. Otherwise, a factory function registered in the [SnapshotDecoder] class will
  /// be used to convert the raw content to an object of type T. When no
  /// suitable factory function is found or the conversion fails, an error is
  /// thrown.
  ///
  /// When [format] is specified, only factory functions that can handle this
  /// format will be used. For example,
  ///
  ///     snapshot.as<DateTime>(format: 'epoch') // will interpret content as millis since epoch
  ///     snapshot.as<DateTime>(format: 'dd/MM/yyyy') // will convert string content to according to specified date format
  ///     snapshot.as<double>(format: 'string') // will parse string content as double
  ///
  /// The result of the conversion is cached, so that subsequent calls to [as]
  /// with the same type parameter and [format], returns the exact same object.
  T as<T>({String? format});

  /// Returns the content of this snapshot as a non-nullable list of objects of
  /// type T.
  ///
  /// The content should be a list and the items of the list should be
  /// convertible to objects of type T.
  ///
  /// The returned list is cached and unmodifiable.
  List<T> asNonNullableList<T>({String? format}) {
    if (value == null) throw TypeError();
    return asList<T>(format: format)!;
  }

  /// Returns the content of this snapshot as a nullable list of objects of type
  /// T.
  ///
  /// The content should be a list or null and the items of the list should be
  /// convertible to objects of type T.
  ///
  /// The returned list is cached and unmodifiable.
  List<T>? asList<T>({String? format});

  /// Returns the content of this snapshot as a non-nullable map with value
  /// objects of type T.
  ///
  /// The content should be a map and the value items of the map should be
  /// convertible to objects of type T.
  ///
  /// The returned map is cached and unmodifiable.
  Map<String, T> asNonNullableMap<T>({String? format}) {
    if (value == null) throw TypeError();
    return asMap(format: format) as Map<String, T>;
  }

  /// Returns the content of this snapshot as a nullable map with value objects
  /// of type T.
  ///
  /// The content should be a map or null and the value items of the map should
  /// be convertible to objects of type T.
  ///
  /// The returned map is cached and unmodifiable.
  Map<String, T>? asMap<T>({String? format});

  /// Returns a snapshot with updated content.
  ///
  /// Unmodified children and grandchildren are recycled. So, also their
  /// conversions are reused.
  ///
  /// [value] may either be a JSON-like object or a [Snapshot].
  ///
  /// When the new value equals the old value, this Snapshot will be returned.
  /// In case the [value] argument was a compatible (i.e. with same decoder)
  /// [Snapshot], the cache of the argument will be merged into this snapshot.
  ///
  /// When [value] is a compatible snapshot (and the content changed), value
  /// will be returned with the cache of this snapshot merged.
  Snapshot set(dynamic value);

  /// Returns a snapshot with updated content at [path].
  ///
  /// Unmodified children and grandchildren are recycled. So, also their
  /// conversions are reused.
  ///
  /// [value] may either be a JSON-like object or a [Snapshot].
  ///
  /// When the updated value equals the old value, this snapshot will be
  /// returned. In case the [value] argument was a compatible (i.e. with same
  /// decoder) [Snapshot], the cache of the argument will be merged into this
  /// snapshot.
  ///
  /// When [value] is a compatible snapshot (and the content changed), the
  /// returned snapshot will contain [value] in its cache.
  ///
  /// When [createParents] is true (default) and some of the parents do not
  /// exist or are not of type Map or List, they are created (as a Map). When
  /// [createParents] is false an error will be thrown.
  Snapshot setPath(String path, dynamic value, {bool createParents = true}) {
    var pointer =
        JsonPointer.fromString(path.startsWith('/') ? path : '/$path');

    if (pointer.segments.isEmpty) return set(value);

    var content = value is Snapshot ? value.value : value;
    var newContent = _setPathInContent(this.value, pointer.segments, content,
        createParents: createParents);

    var snapshot = Snapshot.fromJson(newContent, decoder: decoder);

    if (value is Snapshot && value.decoder == decoder) {
      var parent = snapshot.child(pointer.parent.toString());
      (parent as _SnapshotImpl)._childrenCache[pointer.segments.last] = value;
    }
    return set(snapshot);
  }

  /// Returns a snapshot with another [decoder].
  ///
  /// When [decoder] is equal to the current decoder, this method will return
  /// the current snapshot.
  Snapshot withDecoder(SnapshotDecoder decoder) => decoder == this.decoder
      ? this
      : Snapshot.fromJson(value, decoder: decoder);

  dynamic _setPathInContent(
      dynamic value, Iterable<String> path, dynamic newValue,
      {bool createParents = true}) {
    if (path.isEmpty) return newValue;

    var child = path.first;
    path = path.skip(1);

    dynamic setChild(value, child, newValue) {
      if (value is Map) {
        return {...value}..[child] = newValue;
      }
      if (value is List) {
        var i = int.parse(child);
        return [...value]..[i] = newValue;
      }
      if (createParents) {
        return {child: newValue};
      }
      throw ArgumentError('Unable to set $child in $value');
    }

    dynamic directChild(dynamic value, String child) {
      if (value is Map) {
        return value[child];
      }
      if (value is List) {
        var index = int.tryParse(child);
        if (index != null && index >= 0 && index < value.length) {
          return value[index];
        }
      }
      return null;
    }

    return toDeepImmutable(setChild(
        value,
        child,
        _setPathInContent(directChild(value, child), path, newValue,
            createParents: createParents)));
  }

  @override
  String toString() => 'Snapshot[${as()}]';

  @override
  int get hashCode => hash2(decoder, value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Snapshot &&
        other.decoder == decoder &&
        other.value == value;
  }
}

class _SnapshotImpl extends Snapshot {
  @override
  final dynamic /*Immutable*/ value;

  _SnapshotImpl(dynamic value, {super.decoder})
      : value = toDeepImmutable(value),
        super._();

  final Map<Type?, Map<String?, dynamic>> _decodingCache = {};
  final Map<String?, Snapshot?> _childrenCache = {};

  @override
  T as<T>({String? format}) {
    return _fromCache<T?>(
        format, () => decoder.convert<T>(this, format: format)) as T;
  }

  T _fromCache<T>(String? format, T Function() ifAbsent) {
    assert(null is T,
        '_fromCache should be called with nullable type parameters, was called with $T instead');
    if (value is T) return value as T;
    return _decodingCache
        .putIfAbsent(T, () => {})
        .putIfAbsent(format, ifAbsent);
  }

  @override
  List<T>? asList<T>({String? format}) => _fromCache(format, () {
        if (value is! List) throw TypeError();
        var length = (value as List).length;
        return List<T>.unmodifiable(List<T>.generate(
            length, (index) => child('$index').as<T>(format: format)));
      });

  @override
  Map<String, T>? asMap<T>({String? format}) => _fromCache(format, () {
        if (value is! Map) throw TypeError();

        return Map<String, T>.unmodifiable(Map<String, T>.fromIterable(
            (value as Map).keys,
            value: (k) => child(k).as<T>(format: format)));
      });

  Snapshot _directChild(String child) => _childrenCache.putIfAbsent(child, () {
        dynamic v;
        if (value is Map) {
          v = (value as Map)[child];
        } else if (value is List) {
          var index = int.tryParse(child);
          if (index != null && index >= 0 && index < (value as List).length) {
            v = (value as List)[index];
          }
        }
        return _SnapshotImpl(v, decoder: decoder);
      })!;

  @override
  Snapshot child(String path) {
    var pointer =
        JsonPointer.fromString(path.startsWith('/') ? path : '/$path');
    var v = this;
    for (var c in pointer.segments) {
      v = v._directChild(c) as _SnapshotImpl;
    }
    return v;
  }

  @override
  Snapshot set(newValue) {
    if (newValue is _SnapshotImpl && decoder == newValue.decoder) {
      // the new value is a snapshot

      if (value == newValue.value) {
        // content is identical: return this with cache from newValue

        for (var k in newValue._childrenCache.keys) {
          if (_childrenCache.containsKey(k)) {
            _childrenCache[k] =
                _childrenCache[k]!.set(newValue._childrenCache[k]);
          } else {
            _childrenCache[k] = newValue._childrenCache[k];
          }
        }

        for (var t in newValue._decodingCache.keys) {
          for (var f in newValue._decodingCache[t]!.keys) {
            _decodingCache.putIfAbsent(t, () => {}).putIfAbsent(
                f, () => (newValue as _SnapshotImpl)._decodingCache[t]![f]);
          }
        }
        return this;
      } else {
        // we will return the new value with cache values from old value

        for (var k in _childrenCache.keys) {
          if (newValue._childrenCache.containsKey(k)) {
            newValue._childrenCache[k] =
                _childrenCache[k]!.set(newValue._childrenCache[k]);
          } else {
            newValue._childrenCache[k] =
                _childrenCache[k]!.set(newValue._directChild(k!));
          }
        }

        return newValue;
      }
    }

    newValue = newValue is Snapshot ? newValue.as() : newValue;
    var isEqual = DeepCollectionEquality().equals(value, newValue);
    if (isEqual) return this;

    var v = _SnapshotImpl(newValue, decoder: decoder);

    if (newValue is Map && value is Map) {
      _childrenCache.forEach((k, child) {
        if (newValue[k] == null) return;
        v._childrenCache[k] = child!.set(newValue[k]);
      });
    } else if (newValue is List && value is List) {
      _childrenCache.forEach((k, child) {
        var index = int.parse(k!);
        if (index >= newValue.length) return;
        v._childrenCache[k] = child!.set(newValue[index]);
      });
    }
    return v;
  }

  @override
  // ignore: unnecessary_overrides
  bool operator ==(Object other) => super == other;

  @override
  late final int hashCode = super.hashCode;
}
