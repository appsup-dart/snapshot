import 'package:snapshot/src/deep_immutable.dart';
import 'package:test/test.dart';

void main() {
  group('toDeepImmutable', () {
    test('Literal types should not be changed', () {
      expect(toDeepImmutable(1), 1);
      expect(toDeepImmutable(1.2), 1.2);
      expect(toDeepImmutable(true), true);
      expect(toDeepImmutable(null), null);
      expect(toDeepImmutable('hello world'), 'hello world');
    });

    test('Core dart types should not be changed', () {
      for (var v in [
        DateTime.now(),
        Duration(milliseconds: 413),
        Uri.parse('http://google.com'),
        BigInt.parse('99999999999999999999999999999999999999999999999999'),
        RegExp(r'[\w]+'),
      ]) {
        expect(toDeepImmutable(v), same(v));
      }
    });

    test(
        'Extended core dart types should be transformed to equivalent core versions',
        () {
      for (var v in <DelegatesTo>[
        MyUri(Uri.parse('https://pub.dev')),
        MyRegExp(r'.*'),
      ]) {
        expect(toDeepImmutable(v), v.delegateTo);
        expect(toDeepImmutable(v), isNot(isA<DelegatesTo>()));
      }
    });

    test(
        'Map, List, Iterable and Set should be transformed to equivalent deep immutable versions',
        () {
      for (var v in [
        [1, 2, 4],
        {'hello': 'world'},
        {true, false},
        {
          'hello': ['jane', 'john', 'joe']
        }
      ]) {
        expect(toDeepImmutable(v), isA<DeepImmutable>());
        expect(toDeepImmutable(v), v);
        expect(toDeepImmutable(v), isNot(same(v)));
      }
    });
  });
}

abstract class DelegatesTo<T> {
  final T delegateTo;

  DelegatesTo(this.delegateTo);
}

class MyUri extends DelegatesTo<Uri> implements Uri {
  MyUri(Uri delegateTo) : super(delegateTo);

  @override
  String toString() => delegateTo.toString();
  @override
  String get authority => delegateTo.authority;

  @override
  UriData get data => delegateTo.data;

  @override
  String get fragment => delegateTo.fragment;

  @override
  bool get hasAbsolutePath => delegateTo.hasAbsolutePath;

  @override
  bool get hasAuthority => delegateTo.hasAuthority;

  @override
  bool get hasEmptyPath => delegateTo.hasEmptyPath;

  @override
  bool get hasFragment => delegateTo.hasFragment;

  @override
  bool get hasPort => delegateTo.hasPort;

  @override
  bool get hasQuery => delegateTo.hasQuery;

  @override
  String get host => delegateTo.host;

  @override
  bool get isAbsolute => delegateTo.isAbsolute;

  @override
  bool isScheme(String scheme) => delegateTo.isScheme(scheme);

  @override
  Uri normalizePath() => delegateTo.normalizePath();

  @override
  String get origin => delegateTo.origin;

  @override
  String get path => delegateTo.path;

  @override
  List<String> get pathSegments => delegateTo.pathSegments;

  @override
  int get port => delegateTo.port;

  @override
  String get query => delegateTo.query;

  @override
  Map<String, String> get queryParameters => delegateTo.queryParameters;

  @override
  Map<String, List<String>> get queryParametersAll =>
      delegateTo.queryParametersAll;

  @override
  Uri removeFragment() => delegateTo.removeFragment();

  @override
  Uri replace(
          {String scheme,
          String userInfo,
          String host,
          int port,
          String path,
          Iterable<String> pathSegments,
          String query,
          Map<String, dynamic> queryParameters,
          String fragment}) =>
      delegateTo.replace(
          scheme: scheme,
          userInfo: userInfo,
          host: host,
          port: port,
          path: path,
          pathSegments: pathSegments,
          query: query,
          queryParameters: queryParameters,
          fragment: fragment);

  @override
  bool get hasScheme => delegateTo.hasScheme;

  @override
  Uri resolve(String reference) => delegateTo.resolve(reference);

  @override
  String get userInfo => delegateTo.userInfo;

  @override
  Uri resolveUri(Uri reference) => delegateTo.resolveUri(reference);

  @override
  String get scheme => delegateTo.scheme;

  @override
  String toFilePath({bool windows}) => delegateTo.toFilePath(windows: windows);
}

class MyRegExp extends DelegatesTo<RegExp> implements RegExp {
  MyRegExp(String source) : super(RegExp(source));

  @override
  Iterable<RegExpMatch> allMatches(String input, [int start = 0]) =>
      delegateTo.allMatches(input, start);

  @override
  RegExpMatch firstMatch(String input) => delegateTo.firstMatch(input);

  @override
  bool hasMatch(String input) => delegateTo.hasMatch(input);

  @override
  bool get isCaseSensitive => delegateTo.isCaseSensitive;

  @override
  bool get isDotAll => delegateTo.isDotAll;

  @override
  bool get isMultiLine => delegateTo.isMultiLine;

  @override
  bool get isUnicode => delegateTo.isUnicode;

  @override
  Match matchAsPrefix(String input, [int start = 0]) =>
      delegateTo.matchAsPrefix(input, start);

  @override
  String stringMatch(String input) => delegateTo.stringMatch(input);

  @override
  String get pattern => delegateTo.pattern;
}
