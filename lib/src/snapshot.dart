part of snapshot;

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
  final SnapshotDecoder _decoder;

  Snapshot._({SnapshotDecoder decoder})
      : _decoder = decoder ?? SnapshotDecoder.defaultDecoder;

  /// Creates an empty snapshot with the specified decoder
  ///
  /// When [decoder] is null, the [SnapshotDecoder.defaultDecoder] will be used
  factory Snapshot.empty({SnapshotDecoder decoder}) =>
      Snapshot.fromJson(null, decoder: decoder);

  /// Creates a snapshot from the JSON-like [content]
  ///
  /// [content] will be converted to an unmodifiable object first, so that the
  /// deep immutability of a snapshot is guaranteed.
  ///
  /// When [decoder] is null, the [SnapshotDecoder.defaultDecoder] will be used
  factory Snapshot.fromJson(dynamic content, {SnapshotDecoder decoder}) =>
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
  T as<T>({String format});

  /// Returns the content of this snapshot as a list of objects of type T.
  ///
  /// The content should be a list and the items of the list should be
  /// convertible to objects of type T.
  ///
  /// The returned list is cached and unmodifiable.
  List<T> asList<T>({String format});

  /// Returns the content of this snapshot as a map with value objects of type T.
  ///
  /// The content should be a map and the value items of the map should be
  /// convertible to objects of type T.
  ///
  /// The returned map is cached and unmodifiable.
  Map<String, T> asMap<T>({String format});

  /// Returns a snapshot with updated content.
  ///
  /// Unmodified children and grandchildren are recycled. So, also their
  /// conversions are reused.
  Snapshot set(dynamic value);

  /// Returns a snapshot with updated content at [path].
  ///
  /// Unmodified children and grandchildren are recycled. So, also their
  /// conversions are reused.
  Snapshot setPath(String path, dynamic value) {
    var pointer =
        JsonPointer.fromString(path.startsWith('/') ? path : '/$path');
    return _setPath(pointer.segments, value);
  }

  Snapshot _setPath(Iterable<String> path, dynamic value) {
    if (path.isEmpty) return set(value);

    var oldChild = child(path.first);
    var newChild = oldChild._setPath(path.skip(1), value);
    if (oldChild == newChild) return this;

    var v = as();
    if (v is Map) {
      return set({...v, path.first: newChild.as()});
    }
    if (v is List) {
      var i = int.parse(path.first);
      return set([
        ...v,
      ]..[i] = newChild.as());
    }
    throw ArgumentError();
  }

  @override
  String toString() => 'Snapshot[${as()}]';

  @override
  int get hashCode => hash2(_decoder, DeepCollectionEquality().hash(as()));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Snapshot &&
        other._decoder == _decoder &&
        DeepCollectionEquality().equals(other.as(), as());
  }
}

class _SnapshotImpl extends Snapshot {
  final dynamic _value;

  _SnapshotImpl(dynamic value, {SnapshotDecoder decoder})
      : _value = toDeepImmutable(value),
        super._(decoder: decoder);

  final Map<Type, Map<String, dynamic>> _decodingCache = {};
  final Map<String, Snapshot> _childrenCache = {};

  @override
  T as<T>({String format}) {
    return _fromCache(
        format, () => _decoder.convert<T>(_value, format: format));
  }

  T _fromCache<T>(String format, T Function() ifAbsent) {
    if (_value == null) return null;
    if (_value is T) return _value;
    return _decodingCache
        .putIfAbsent(T, () => {})
        .putIfAbsent(format, ifAbsent);
  }

  @override
  List<T> asList<T>({String format}) => _fromCache(format, () {
        if (_value is! List) throw FormatException();
        var length = (_value as List).length;
        return List<T>.unmodifiable(List<T>.generate(
            length, (index) => child('$index').as<T>(format: format)));
      });

  @override
  Map<String, T> asMap<T>({String format}) => _fromCache(format, () {
        if (_value is! Map) throw FormatException();

        return Map<String, T>.unmodifiable(Map<String, T>.fromIterable(
            (_value as Map).keys,
            value: (k) => child(k).as<T>(format: format)));
      });

  Snapshot _directChild(String child) => _childrenCache.putIfAbsent(child, () {
        var value;
        if (_value is Map) {
          value = _value[child];
        } else if (_value is List) {
          var index = int.tryParse(child);
          if (index != null && index >= 0 && index < _value.length) {
            value = _value[index];
          }
        }
        return _SnapshotImpl(value, decoder: _decoder);
      });

  @override
  Snapshot child(String path) {
    var pointer =
        JsonPointer.fromString(path.startsWith('/') ? path : '/$path');
    var v = this;
    for (var c in pointer.segments) {
      v = v._directChild(c);
    }
    return v;
  }

  @override
  Snapshot set(value) {
    if (value is Snapshot) {
      // TODO recycle cache
    }
    value = value is Snapshot ? value.as() : value;
    var isEqual = DeepCollectionEquality().equals(_value, value);
    if (isEqual) return this;

    var v = _SnapshotImpl(value, decoder: _decoder);
    v._childrenCache.addAll(_childrenCache
        .map((k, v) => MapEntry(k, v.set(value is Map ? value[k] : null))));
    return v;
  }
}
