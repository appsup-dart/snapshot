part of snapshot;

/// Holds methods to convert [Snapshot]s to objects of specific types.
///
/// The [SnapshotDecoder.defaultDecoder] handles conversions of common dart
/// types. The following conversions are available by default:
///
/// | from type | to type | format | description
/// | --------- | ------- | ------ | -----------
/// | String | DateTime | null | uses DateTime.parse
/// | num | DateTime | 'epoch' | milliseconds since epoch
/// | String | Uri | null | uses Uri.parse
/// | String | int | 'radix:{radix}' | uses int.parse with radix
/// | String | int | 'string' | uses int.parse
/// | String | double | 'string' | uses double.parse
/// | String | num | 'string' | uses num.parse
/// | String | DateTime | '{date-format}' | uses intl.DateFormat.parse
///
///
///
/// A custom decoder can be created by calling one of the constructors and
/// registering new conversion functions. Before a decoder can be used, it needs
/// to be sealed by calling [SnapshotDecoder.seal]. Once sealed, it is not
/// allowed to register any additional converters.
class SnapshotDecoder {
  final Map<Type, List<_SnapshotDecoderFactory>> _converters = {};

  bool _sealed = false;

  static final SnapshotDecoder _defaultDecoder = SnapshotDecoder()..seal();

  /// Create a new, unsealed [SnapshotDecoder] containing the default converters
  ///
  /// Additional converters can be registered with [SnapshotDecoder.register]
  /// and [SnapshotDecoder.registerWithFormat]. Before being able to use this
  /// [SnapshotDecoder], you'll need to seal it by calling [SnapshotDecoder.seal].
  SnapshotDecoder() {
    register<String, DateTime>((v) => DateTime.parse(v));
    register<num, DateTime>(
        (v) => DateTime.fromMicrosecondsSinceEpoch((v * 1000).toInt()),
        format: 'epoch');
    register<String, Uri>((v) => Uri.parse(v));
    register<String, int>(
        (v, {String? format}) =>
            int.parse(v, radix: int.parse(format!.substring('radix:'.length))),
        format: RegExp(r'radix:(\d+)'));
    register<String, int>((v) => int.parse(v), format: 'string');
    register<String, double>((v) => double.parse(v), format: 'string');
    register<String, num>((v) => num.parse(v), format: 'string');
    register<String, DateTime>((v, {String? format}) {
      var f = DateFormat(format!);
      return f.parse(v);
    }, format: RegExp('.*'));
  }

  /// Create a new, unsealed empty [SnapshotDecoder]
  ///
  /// This decoder will not contain the default decoders
  SnapshotDecoder.empty();

  /// Create a new, unsealed [SnapshotDecoder] containing the converters in the
  /// decoder [other].
  ///
  /// Additional converters can be registered with [SnapshotDecoder.register]
  /// and [SnapshotDecoder.registerWithFormat]. Before being able to use this
  /// [SnapshotDecoder], you'll need to seal it by calling [SnapshotDecoder.seal].
  SnapshotDecoder.from(SnapshotDecoder other) {
    other._converters.forEach((key, value) {
      var l = _converters.putIfAbsent(key, () => []);
      for (var c in value) {
        l.add(c);
      }
    });
  }

  /// The default, sealed [SnapshotDecoder]
  ///
  /// Contains the default converters
  static SnapshotDecoder get defaultDecoder => _defaultDecoder;

  /// `true` when this decoder is sealed
  ///
  /// When sealed, the decoder is ready to be used for conversions. It is not
  /// possible anymore to register any additional converters.
  bool get isSealed => _sealed;

  /// Seals this decoder
  ///
  /// When sealed, the decoder is ready to be used for conversions. It is not
  /// possible anymore to register any additional converters.
  void seal() => _sealed = true;

  /// Registers a conversion function
  ///
  /// This registers a converter from source type [S] to destination type [T].
  /// The optional [format] parameter can be used to register a converter for
  /// specific formats only. In that case, the converter will only be used when
  /// calling [Snapshot.as] with a format parameter that matches this format.
  /// The format can be a plain string, in which case it should be an exact
  /// match, or a [RegExp] in which case it will handle any request with a
  /// format that matches this regular expression.
  ///
  /// When [converter] has a named optional parameter `format`, the `format`
  /// parameter used in [Snapshot.as] will be forwarded to this converter.
  ///
  ///     register<String, DateTime>((String v, {String format}) {
  ///       var f = DateFormat(format);
  ///       return f.parse(v);
  ///     }, format: RegExp('.*'));
  ///
  /// Converters are applied in reverse order of how they were registered. So,
  /// you can (partly) overwrite an already registered converter, by registering
  /// a new one.
  void register<S, T>(T Function(S) converter, {Pattern? format}) {
    if (isSealed) {
      throw StateError('Cannot register new conversion methods when sealed.');
    }
    _addConverter(_SnapshotDecoderFactory<S, T?>((s, format) {
      if (s == null) return null;
      if (converter is T Function(S, {String? format})) {
        return converter(s, format: format);
      }
      return converter(s);
    }, format));
  }

  void _addConverter<S, T>(_SnapshotDecoderFactory<S, T> factory) {
    _converters.putIfAbsent(T, () => []).add(factory);
  }

  List<_SnapshotDecoderFactory> _getConverters<T>() => _converters[T] ?? [];

  /// Converts [input] to an object of type T
  ///
  /// Throws a [StateError] when not sealed.
  /// Throws a [FormatException] when no applicable converter registered.
  T convert<T>(Snapshot input, {String? format}) {
    if (!isSealed) {
      throw StateError('Cannot be used when not sealed.');
    }
    var value = input.value;
    if (value is T) return value;
    var factories = _getConverters<T?>();
    for (var factory in factories.reversed) {
      if (factory.canHandle(input, format)) {
        return factory.create(input, format);
      }
    }
    throw FormatException('Decoding of `$input` to type $T not supported.');
  }
}

class _SnapshotDecoderFactory<S, T> {
  final T Function(S, String?) converter;
  final Pattern? format;

  _SnapshotDecoderFactory(this.converter, this.format);

  bool canHandle(Snapshot v, String? format) {
    var input = v.value;
    if (input is! S && S != Snapshot) return false;
    if (!_canHandleFormat(format)) return false;
    return true;
  }

  bool _canHandleFormat(String? format) {
    if (this.format == null) return format == null;
    if (format == null) return false;
    var matches = this.format!.allMatches(format);
    return matches.isNotEmpty &&
        matches.any((element) => element.group(0) == format);
  }

  T create(Snapshot source, String? format) {
    return converter(S == Snapshot ? source as S : source.value, format);
  }
}
