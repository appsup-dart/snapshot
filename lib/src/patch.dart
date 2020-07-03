library deep_immutable.patch;

import 'package:snapshot/snapshot.dart';
import 'package:json_patch/json_patch.dart';
import 'package:snapshot/src/deep_immutable.dart';
import 'snapshot_view.dart';

final _decoder = SnapshotDecoder()
  ..register<List<Map<String, dynamic>>, Patch>((v) => Patch.fromJson(v))
  ..register<Map<String, dynamic>, Operation>((v) => Operation.fromJson(v));

/// Describes changes between JSON-like objects.
class Patch extends UnmodifiableSnapshotView {
  /// Creates a [Patch] from [json].
  ///
  /// [json] should be in JSON Patch format
  /// ([RFC 6902](http://tools.ietf.org/html/rfc6902))
  Patch.fromJson(json) : super.fromJson(json, decoder: _decoder);

  /// Creates a [Patch] from individual [operations].
  Patch(Iterable<Operation> operations)
      : this.fromJson([...operations.map((o) => o.toJson())]);

  /// Creates a [Patch] that transforms the [source] into [target].
  Patch.diff(dynamic source, dynamic target)
      : this.fromJson(JsonPatch.diff(source, target));

  /// Returns the individual operations in this patch
  List<Operation> get operations => snapshot.asList();

  /// Applies this patch to [value]
  dynamic apply(dynamic value) {
    // JsonPatch uses field `to` instead of `path` as defined by the standard.
    // We'll need to convert it.
    var json = operations.map((o) => <String, dynamic>{
          'op': o.operation,
          if (o.from != null) 'from': o.from,
          if (o.path != null && {'move', 'copy'}.contains(o.operation))
            'to': o.path
          else if (o.path != null)
            'path': o.path,
          'value': o.value,
        });
    return toDeepImmutable(JsonPatch.apply(value, json));
  }
}

/// Describes a single difference between JSON-like objects
class Operation extends UnmodifiableSnapshotView {
  /// Creates a [Operation] from [json]
  ///
  /// [json] should be in JSON Patch format
  /// ([RFC 6902](http://tools.ietf.org/html/rfc6902))
  Operation.fromJson(json) : super.fromJson(json, decoder: _decoder);

  /// Creates an operation that adds [value] at the location described by [path].
  Operation.add(String path, dynamic value)
      : this.fromJson({'op': 'add', 'path': path.toString(), 'value': value});

  /// Creates an operation that replaces the value at [path] with [value].
  Operation.replace(String path, dynamic value)
      : this.fromJson(
            {'op': 'replace', 'path': path.toString(), 'value': value});

  /// Creates an operation that tests that the value at [path] equals [value].
  Operation.test(String path, dynamic value)
      : this.fromJson({'op': 'test', 'path': path.toString(), 'value': value});

  Operation.remove(String path)
      : this.fromJson({'op': 'remove', 'path': path.toString()});

  Operation.move(String from, String to)
      : this.fromJson(
            {'op': 'move', 'path': to.toString(), 'from': from.toString()});

  Operation.copy(String from, String to)
      : this.fromJson(
            {'op': 'copy', 'path': to.toString(), 'from': from.toString()});

  /// The operation to perform.
  String get operation => get('op');

  /// A JSON Pointer path to the node this operation should be applied to.
  String get path => get('path');

  /// A JSON Pointer path pointing to the location to move/copy from.
  String get from => get('from');

  /// The value to add, replace or test.
  dynamic get value => get('value');
}
