class JsonPointer {
  final List<String> segments;

  JsonPointer.fromSegments(this.segments) : assert(segments != null);

  factory JsonPointer.fromString(String pointer) {
    if (!(pointer.isEmpty || pointer.startsWith('/'))) {
      throw ArgumentError.value(pointer, 'pointer', 'Invalid JSON Pointer.');
    }

    return JsonPointer.fromSegments(pointer
        .split('/')
        .skip(1)
        .map((String segment) => segment
            .replaceAll(RegExp(r'~1'), '/')
            .replaceAll(RegExp(r'~0'), '~'))
        .toList());
  }

  factory JsonPointer.join(JsonPointer lhs, JsonPointer rhs) {
    return JsonPointer.fromSegments(
      List.from(lhs.segments)..addAll(rhs.segments),
    );
  }

  bool get isRoot => segments.isEmpty;
  bool get hasParent => !isRoot;
  JsonPointer get parent {
    assert(hasParent);
    return JsonPointer.fromSegments(List.from(segments)..removeLast());
  }

  @override
  String toString() {
    return segments
        .map((String segment) => segment
            .replaceAll(RegExp(r'~'), '~0')
            .replaceAll(RegExp(r'/'), '~1'))
        .map((String segment) => '/' + segment)
        .join();
  }
}
