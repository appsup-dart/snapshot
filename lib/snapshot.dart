/// A library that can be used to implement data classes
///
///
library snapshot;

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:json_patch/json_patch.dart';
import 'package:meta/meta.dart';
import 'package:quiver/core.dart';
import 'package:snapshot/src/deep_immutable.dart';

export 'src/snapshot_view.dart';

part 'src/decoder.dart';
part 'src/snapshot.dart';
