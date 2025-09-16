library deep_immutable;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

// TODO: uncomment when min sdk >=2.13 for support of typedef for non function types
// /// Union type of DeepImmutable|Null|num|bool|String|DateTime|Duration|Uri|BigInt|RegExp.
// ///
// /// As dart does not support union types, this type is used to indicate that the
// /// value can be any of the types mentioned. This is used in the [toDeepImmutable]
// /// method to indicate that the return type can be any of these types.
// ///
// /// An immutable object implements the [hashCode] and [==] methods and may cache
// /// the hash code for better performance. Collections with immutable objects
// /// do not need to check deep equality as this is checked by the immutable
// /// objects themselves.
// typedef Immutable = Object?;

/// Transforms the [input] to an equivalent object that is deep immutable.
///
/// The input should not contain objects other than core immutable data types,
/// [Map]s, [Iterable]s, [Set]s and [List]s. Otherwise, an [ArgumentError] will
/// be thrown.
///
/// By default, the accepted immutable types are the literal types [Null],
/// [num], [bool] and [String] as well as core dart types that are immutable
/// [DateTime], [Duration], [Uri], [BigInt] and [RegExp]. These latter
/// object types can potentially be extended to non immutable types. Therefore,
/// they are converted to their built-in counterparts.
///
/// Other types can be accepted as immutable with the parameter
/// [isDeepImmutable]. When not `null`, this method will be called for each
/// object inside [input] that is not already detected as a deep immutable
/// object. When the method returns `true`, the object is considered as deep
/// immutable. It is the responsibility of the developer to assure that the
/// object is indeed deep immutable.
///
/// Additionally, all classes that implement [DeepImmutable] are also considered
/// as deep immutable.
dynamic /*Immutable*/ toDeepImmutable(dynamic input,
    {bool Function(dynamic)? isDeepImmutable}) {
  if (input == null ||
      input is num ||
      input is bool ||
      input is String ||
      input is DeepImmutable) {
    return input;
  }
  // DateTime and Duration are immutable, but they can be extended by classes
  // that are not immutable. Therefore, only accept objects with runtimeType
  // equal to the built-in, non-extended DateTime and Duration.
  if ({
    DateTime,
    Duration,
    RegExp('').runtimeType,
    Uri().runtimeType,
    Uri.dataFromString('').runtimeType,
    Uri.parse('http://google.com').runtimeType,
    BigInt.one.runtimeType,
  }.contains(input.runtimeType)) {
    return input;
  }
  // When not the built-in DateTime or Duration is used, we will convert to the
  // built-in one.
  if (input is DateTime) {
    return DateTime.fromMicrosecondsSinceEpoch(input.microsecondsSinceEpoch,
        isUtc: input.isUtc);
  }
  if (input is Duration) {
    return Duration(microseconds: input.inMicroseconds);
  }

  // The built-in Uri, BigInt and RegExp are immutable. We cannot check
  // on runtimeType as these are abstract classes and the runtime classes will
  // be different. Therefore, we create an immutable version of these objects.
  if (input is Uri) {
    return Uri.parse(input.toString());
  }
  if (input is BigInt) {
    return BigInt.parse(input.toString());
  }
  if (input is RegExp) {
    return RegExp(input.pattern,
        caseSensitive: input.isCaseSensitive,
        dotAll: input.isDotAll,
        multiLine: input.isMultiLine,
        unicode: input.isUnicode);
  }

  if (isDeepImmutable != null && isDeepImmutable(input)) {
    return input;
  }
  if (input is Set) {
    return _DeepImmutableSet(input.cast(), isDeepImmutable: isDeepImmutable);
  }
  if (input is Iterable) {
    return _DeepImmutableList(input.cast() as List<dynamic>,
        isDeepImmutable: isDeepImmutable);
  }
  if (input is Map) {
    return _DeepImmutableMap(input.cast(), isDeepImmutable: isDeepImmutable);
  }
  throw ArgumentError.value(
      input, 'value', 'Cannot be converted to a deep immutable object');
}

/// Indicates that the class that implements this interface is deep immutable.
///
/// A class is deep immutable if all of the instance fields of the class,
/// whether defined directly or inherited, are `final` and are themselves deep
/// immutable.
///
/// It is the developers responsibility to assure that no non-deep-immutable
/// class implements this interface. The analyzer will provide feedback when a
/// non final instance field is defined on a class implementing this interface.
/// However, that those fields are themselves deep immutable should be checked
/// by the developer.
@immutable
abstract class DeepImmutable {
  @override
  @mustBeOverridden
  int get hashCode;

  @override
  @mustBeOverridden
  bool operator ==(Object other);
}

class _DeepImmutableMap extends UnmodifiableMapView<String, dynamic>
    implements DeepImmutable {
  _DeepImmutableMap(Map<String, dynamic> map,
      {bool Function(dynamic)? isDeepImmutable})
      : super(Map<String,
                dynamic>.from /*.unmodifiable instead of .from causes an error in web environment: see https://github.com/dart-lang/sdk/issues/46417 */
            (map.map((k, v) => MapEntry<String, dynamic>(
                k, toDeepImmutable(v, isDeepImmutable: isDeepImmutable)))));

  @override
  late final int hashCode = const MapEquality().hash(this);

  @override
  bool operator ==(Object other) =>
      other is _DeepImmutableMap && const MapEquality().equals(this, other);
}

class _DeepImmutableList extends UnmodifiableListView<dynamic>
    implements DeepImmutable {
  _DeepImmutableList(List<dynamic> source,
      {bool Function(dynamic)? isDeepImmutable})
      : super(List.unmodifiable(source
            .map((v) => toDeepImmutable(v, isDeepImmutable: isDeepImmutable))));

  @override
  late final int hashCode = const ListEquality().hash(this);

  @override
  bool operator ==(Object other) =>
      other is _DeepImmutableList && const ListEquality().equals(this, other);
}

class _DeepImmutableSet extends UnmodifiableSetView<dynamic>
    implements DeepImmutable {
  _DeepImmutableSet(Set<dynamic> source,
      {bool Function(dynamic)? isDeepImmutable})
      : super(Set.from(source
            .map((v) => toDeepImmutable(v, isDeepImmutable: isDeepImmutable))));

  @override
  late final int hashCode = const SetEquality().hash(this);

  @override
  bool operator ==(Object other) =>
      other is _DeepImmutableSet && const SetEquality().equals(this, other);
}
