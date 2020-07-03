library snapshot.view;

import 'package:snapshot/snapshot.dart';
import 'package:meta/meta.dart';

/// A mixin to be used to implement data classes
///
/// Allows to easily define getters. For example:
///
///     mixin AddressMixin on SnapshotView {
///
///       String get city => get('city');
///
///     }
///
///
mixin SnapshotView {
  Snapshot get _snapshot;

  /// Returns the JSON representation of the snapshot
  ///
  /// This will return the unconverted content of the snapshot. In theory, this
  /// could contain non JSON values. The user should make sure that any value
  /// set to a snapshot is valid JSON or can be converted to JSON with a
  /// `toJson` method.
  dynamic toJson() => _snapshot.as();
}

/// This extension makes getters available to convert the JSON content to dart
/// objects on classes extending [SnapshotView]s.
extension SnapshotViewExtension on SnapshotView {
  Snapshot get snapshot => _snapshot;

  /// Gets and converts the value at [path] to type T
  T get<T>(String path, {String format}) =>
      _snapshot.child(path).as(format: format);

  /// Gets and converts the value at [path] to type List<T>
  List<T> getList<T>(String path, {String format}) =>
      _snapshot.child(path).asList(format: format);

  /// Gets and converts the value at [path] to type Map<String,T>
  Map<String, T> getMap<T>(String path, {String format}) =>
      _snapshot.child(path).asMap(format: format);
}

/// Base class for unmodifiable data classes
///
/// Example use:
///
///     class Address = UnmodifiableSnapshotView with AddressMixin;
///
/// This will create an `Address` class containing the getters (and possibly
/// other methods) defined in  `AddressMixin` and with a `fromJson` constructor
/// and `toJson` method.
///
/// The content of this class cannot/should not be changed.
@immutable
class UnmodifiableSnapshotView with SnapshotView {
  @override
  final Snapshot _snapshot;

  UnmodifiableSnapshotView._fromSnapshot(this._snapshot);

  UnmodifiableSnapshotView.fromJson(dynamic json, {SnapshotDecoder decoder})
      : this._fromSnapshot(Snapshot.empty(decoder: decoder).set(json));
}

/// Base class for data classes that can be changed
///
/// Example use:
///
///     mixin AddressMixin {
///
///       String get city => get('city');
///
///       set city(String v) => set('city',v);
///     }
///
///     class Address = ModifiableSnapshotView with AddressMixin;
///
/// This will create an `Address` class containing the getters and setters (and
/// possibly other methods) defined in `AddressMixin` and with a `fromJson`
/// constructor and `toJson` method.
///
/// [ModifiableSnapshotView]s should be used with care as changes will not flow
/// upstream. For example, consider the following code:
///
///     var snapshot = ModifiableSnapshotView.fromJson({
///       'firstname': 'John',
///       'address': {
///         'addressLine1': 'Mainstreet 1',
///         'city': 'London'
///       }
///     });
///     var address = snapshot.get<Address>('address');
///     address.city = 'New York';
///     print(snapshot.get('address/city')); // prints 'London'
///     print(snapshot.get<Address>('address').city); // prints 'New York'
///
class ModifiableSnapshotView with SnapshotView {
  ModifiableSnapshotView._fromSnapshot(this._snapshot);

  ModifiableSnapshotView.fromJson(dynamic json, {SnapshotDecoder decoder})
      : this._fromSnapshot(Snapshot.empty(decoder: decoder).set(json));

  @override
  Snapshot _snapshot;
}

/// This extension makes setters available to update the content of the snapshot
extension ModifiableSnapshotViewExtension on ModifiableSnapshotView {
  /// Updates the content at [path] with [value]
  void set(String path, dynamic value) {
    _snapshot = _snapshot.setPath(path, value);
  }
}
