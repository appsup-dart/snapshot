library snapshot.view;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';
import 'package:snapshot/snapshot.dart';

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
  T get<T>(String path, {String? format}) =>
      _snapshot.child(path).as(format: format);

  /// Gets and converts the value at [path] to type List<T> or null
  List<T>? getList<T>(String path, {String? format}) =>
      _snapshot.child(path).asList(format: format);

  /// Gets and converts the value at [path] to type List<T>
  List<T> getNonNullableList<T>(String path, {String? format}) =>
      _snapshot.child(path).asNonNullableList(format: format);

  /// Gets and converts the value at [path] to type Map<String,T> or null
  Map<String, T>? getMap<T>(String path, {String? format}) =>
      _snapshot.child(path).asMap(format: format);

  /// Gets and converts the value at [path] to type Map<String,T>
  Map<String, T> getNonNullableMap<T>(String path, {String? format}) =>
      _snapshot.child(path).asNonNullableMap(format: format);
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

  UnmodifiableSnapshotView(this._snapshot);

  UnmodifiableSnapshotView.fromJson(dynamic json, {SnapshotDecoder? decoder})
      : this(Snapshot.empty(decoder: decoder).set(json));
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
  final BehaviorSubject<Snapshot> _snapshots = BehaviorSubject();

  ModifiableSnapshotView.fromJson(dynamic json, {SnapshotDecoder? decoder}) {
    _snapshots.add(Snapshot.empty(decoder: decoder).set(json));
  }

  ModifiableSnapshotView.fromStream(Stream<Snapshot> stream) {
    StreamSubscription? subscription;
    _snapshots.onListen = () {
      subscription ??= stream.listen(_snapshots.add,
          onError: _snapshots.addError, onDone: _snapshots.close);
      subscription!.resume();
    };
    _snapshots.onCancel = () {
      if (stream.isBroadcast) {
        subscription!.cancel();
        subscription = null;
      } else {
        subscription!.pause();
      }
    };
    _snapshots.done.then((v) {
      subscription?.cancel();
      subscription = null;
    });
  }

  @override
  Snapshot get _snapshot {
    var v = _snapshots.valueOrNull;
    if (v == null) {
      throw StateError('ModifiableSnapshotView has not received a value yet.');
    }
    return v;
  }

  bool get isDisposed => _isDisposed;
  bool _isDisposed = false;
  Future<void> dispose() async {
    _isDisposed = true;
    await _snapshots.close();
  }
}

/// This extension makes setters available to update the content of the snapshot
extension ModifiableSnapshotViewX on ModifiableSnapshotView {
  /// Updates the content at [path] with [value]
  ///
  /// When [path] is null, will set the root snapshot
  ///
  /// To use this method, the [ModifiableSnapshotView.fromJson] constructor
  /// should have been used.
  void set(String? path, dynamic value) {
    if (path == null) {
      _snapshots.add(_snapshot.set(value));
    } else {
      _snapshots.add(_snapshot.setPath(path, value));
    }
  }

  Stream<SnapshotViewChangeEvent> get onChanged => DeferStream(() {
        Snapshot? last;
        return _snapshots.stream.map((v) {
          var event = SnapshotViewChangeEvent(oldValue: last, newValue: v);
          last = v;
          return event;
        });
      }, reusable: true);

  bool get hasValue => _snapshots.hasValue;
}

class SnapshotViewChangeEvent {
  final Snapshot? oldValue;

  final Snapshot? newValue;

  SnapshotViewChangeEvent({this.oldValue, this.newValue});
}
