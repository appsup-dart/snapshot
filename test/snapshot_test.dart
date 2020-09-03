import 'package:intl/intl.dart';
import 'package:snapshot/snapshot.dart';
import 'package:test/test.dart';

void main() {
  group('Snapshot', () {
    group('Snapshot.child()', () {
      var v = Snapshot.fromJson({
        'firstname': 'Jane',
        'lastname': 'Doe',
        'address': {'city': 'London'},
        'phones': [
          {'type': 'work', 'number': '+11111'}
        ]
      });
      test('Leading `/` is optional', () {
        expect(v.child('firstname').as(), 'Jane');
        expect(v.child('/firstname').as(), 'Jane');
        expect(v.child('firstname'), same(v.child('/firstname')));
      });
      test('Child snapshots should be cached', () {
        expect(v.child('lastname'), same(v.child('lastname')));
        expect(v.child('address/city'), same(v.child('address').child('city')));
      });
      test('Should return empty snapshot when not a map or list', () {
        expect(v.child('lastname').child('city').as(), isNull);
      });
      test('Should return a snapshot corresponding to the JSON pointer', () {
        expect(v.child('phones/0/type').as(), 'work');
        expect(v.child('phones/1').as(), isNull);
        expect(v.child('address/city').as(), 'London');
        expect(v.child('givenName').as(), isNull);
      });
    });
    group('Snapshot.as()', () {
      test('Accessing unconverted values', () {
        var s = Snapshot.fromJson({'hello': 'world'});

        expect(s.as(), {'hello': 'world'});
        expect(s.child('hello').as(), 'world');
        expect(s.child('hi').as(), null);
      });

      test('Converting', () {
        var s = Snapshot.fromJson('https://www.google.com');

        expect(s.as<Uri>(), Uri.parse('https://www.google.com'));
        expect(() => s.as<DateTime>(), throwsFormatException);

        s = Snapshot.fromJson('2020-01-01');
        expect(s.as<DateTime>(), DateTime(2020, 1, 1));

        expect(() => s.as<int>(), throwsFormatException);

        s = Snapshot.fromJson('11');
        expect(s.as<int>(format: 'radix:10'), 11);
        expect(s.as<int>(format: 'radix:16'), 17);
        expect(s.as<int>(format: 'string'), 11);
        expect(s.as<num>(format: 'string'), 11);
        expect(s.as<double>(format: 'string'), 11.0);

        s = Snapshot.fromJson('0x11');
        expect(s.as<int>(format: 'string'), 17);

        s = Snapshot.fromJson('1.1');
        expect(s.as<double>(format: 'string'), 1.1);
        expect(s.as<num>(format: 'string'), 1.1);
        expect(() => s.as<int>(format: 'string'), throwsFormatException);

        s = Snapshot.fromJson('02-03-2020');
        expect(s.as<DateTime>(format: 'dd-MM-yyyy'), DateTime(2020, 03, 02));
      });

      test('Converting with custom decoder', () {
        var decoder = SnapshotDecoder.from(SnapshotDecoder.defaultDecoder)
          ..register<String, DateTime>((String v) {
            return DateTime(
                int.parse(v.substring(0, 4)),
                int.parse(v.substring(4, 6)),
                int.parse(v.substring(6, 8)),
                int.parse(v.substring(9, 11)),
                int.parse(v.substring(11, 13)));
          }, format: 'datetime_key')
          ..seal();

        var s = Snapshot.fromJson('20200101-1030', decoder: decoder);
        expect(s.as<DateTime>(format: 'datetime_key'),
            DateTime(2020, 1, 1, 10, 30));
      });

      test('Decoded values should be cached', () {
        var s = Snapshot.fromJson('https://www.google.com');
        expect(s.as<Uri>(), same(s.as<Uri>()));

        s = Snapshot.fromJson('2020-01-01');
        expect(s.as<DateTime>(), same(s.as<DateTime>()));
      });
    });

    group('Snapshot.asList()', () {
      test('Should return an unmodifiable list of T', () {
        var v = Snapshot.fromJson(['1', '2', '3', '4']);

        var l = v.asList<int>(format: 'string');
        expect(l, isA<List<int>>());
        expect(l, [1, 2, 3, 4]);
        expect(() => l.removeLast(), throwsUnsupportedError);
        expect(() => l[2] = 0, throwsUnsupportedError);

        v = Snapshot.fromJson(['1.1', '2', '3', '4']);

        expect(() => v.asList<int>(format: 'string'), throwsFormatException);
      });
      test('Should cache list and items', () {
        var v = Snapshot.fromJson(['1', '2', '3', '4']);
        var l = v.asList<int>(format: 'string');
        expect(l, same(v.asList<int>(format: 'string')));

        v = Snapshot.fromJson(['https://google.com']);
        expect(v.asList<Uri>()[0], same(v.child('0').as<Uri>()));
      });
    });

    group('Snapshot.asMap()', () {
      test('Should return an unmodifiable map of <String,T>', () {
        var v = Snapshot.fromJson(
            {'first': '1', 'second': '2', 'third': '3', 'fourth': '4'});

        var l = v.asMap<int>(format: 'string');
        expect(l, isA<Map<String, int>>());
        expect(l, {'first': 1, 'second': 2, 'third': 3, 'fourth': 4});
        expect(() => l.remove('first'), throwsUnsupportedError);
        expect(() => l['second'] = 0, throwsUnsupportedError);

        v = Snapshot.fromJson({'first': '1.1', 'second': '2'});

        expect(() => v.asMap<int>(format: 'string'), throwsFormatException);
      });
      test('Should cache map and items', () {
        var v = Snapshot.fromJson(
            {'first': '1', 'second': '2', 'third': '3', 'fourth': '4'});
        var l = v.asMap<int>(format: 'string');
        expect(l, same(v.asMap<int>(format: 'string')));

        v = Snapshot.fromJson({'url': 'https://google.com'});
        expect(v.asMap<Uri>()['url'], same(v.child('url').as<Uri>()));
      });
    });

    group('Snapshot.set()', () {
      var v = Snapshot.fromJson({
        'firstname': 'Jane',
        'lastname': 'Doe',
      });

      test('Unchanged content should return same object', () {
        var w = v.set({
          'firstname': 'Jane',
          'lastname': 'Doe',
        });
        expect(w, same(v));
      });

      test('Unmodified children should be recycled', () {
        var firstname = v.child('lastname');
        v = v.set({
          'firstname': 'John',
          'lastname': 'Doe',
        });

        expect(v.child('firstname').as(), 'John');
        expect(firstname, same(v.child('lastname')));
      });
    });

    group('Snapshot.setPath()', () {
      var v = Snapshot.fromJson({
        'firstname': 'Jane',
        'lastname': 'Doe',
        'address': {'city': 'London'}
      });

      test('Unchanged content should return same object', () {
        var w = v.setPath('address', {'city': 'London'});
        expect(w, same(v));
        w = v.setPath('address/city', 'London');
        expect(w, same(v));
      });

      test('Unmodified children should be recycled', () {
        var firstname = v.child('lastname');
        v = v.setPath('address', {'city': 'New York'});

        expect(v.child('address/city').as(), 'New York');
        expect(firstname, same(v.child('lastname')));
      });
    });
  });

  group('SnapshotDecoder', () {
    group('SnapshotDecoder.seal()', () {
      test('Should allow register/disallow usage when not sealed', () {
        var v = SnapshotDecoder();
        expect(v.isSealed, isFalse);
        expect(() => v.register<String, DateTime>((_) => DateTime.now()),
            isNot(throwsA(anything)));
        expect(
            () =>
                v.register<String, DateTime>((_) => DateTime.now(), format: ''),
            isNot(throwsA(anything)));
        expect(() => v.convert(null), throwsStateError);
      });
      test('Should disallow register/allow usage when sealed', () {
        var v = SnapshotDecoder()..seal();
        expect(v.isSealed, isTrue);
        expect(() => v.register<String, DateTime>((_) => DateTime.now()),
            throwsStateError);
        expect(
            () =>
                v.register<String, DateTime>((_) => DateTime.now(), format: ''),
            throwsStateError);
        expect(() => v.convert(null), isNot(throwsA(anything)));
      });
      test('Should try converters in reversed order', () {
        var v = SnapshotDecoder.empty()
          ..register<String, DateTime>((String v, {String format}) {
            var f = DateFormat(format);
            return f.parse(v);
          }, format: RegExp('.*'))
          ..register<String, DateTime>((String v) => DateTime.parse(v),
              format: 'iso')
          ..seal();

        expect(v.convert<DateTime>('2020-01-01T10:00', format: 'iso'),
            DateTime(2020, 1, 1, 10, 0));
        expect(
            () => v.convert<DateTime>('2020-01-01T10:00', format: 'dd/MM/yyyy'),
            throwsFormatException);
        expect(v.convert<DateTime>('01/01/2020', format: 'dd/MM/yyyy'),
            DateTime(2020, 1, 1));
        expect(() => v.convert<DateTime>('01/01/2020', format: 'iso'),
            throwsFormatException);

        v = SnapshotDecoder.from(v)
          ..register<String, DateTime>((String v, {String format}) {
            var f = DateFormat(format);
            return f.parse(v);
          }, format: RegExp('.*'))
          ..seal();

        expect(() => v.convert<DateTime>('2020-01-01T10:00', format: 'iso'),
            throwsFormatException);
        expect(
            () => v.convert<DateTime>('2020-01-01T10:00', format: 'dd/MM/yyyy'),
            throwsFormatException);
        expect(v.convert<DateTime>('01/01/2020', format: 'dd/MM/yyyy'),
            DateTime(2020, 1, 1));
        expect(() => v.convert<DateTime>('01/01/2020', format: 'iso'),
            throwsFormatException);
      });
    });
  });
}