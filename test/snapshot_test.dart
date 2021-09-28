import 'dart:collection';

import 'package:intl/intl.dart';
import 'package:snapshot/snapshot.dart';
import 'package:test/test.dart';

void main() {
  var decoderWithAddress = SnapshotDecoder.from(SnapshotDecoder.defaultDecoder)
    ..register<Snapshot, Address>((v) => Address(v))
    ..seal();

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

      test('Converting from snapshot', () {
        var s = Snapshot.fromJson({'street': 'Mainstreet'},
            decoder: decoderWithAddress);
        expect(s.as<Address>().street, 'Mainstreet');
      });

      test('Should return null when content is null and type is nullable', () {
        var s = Snapshot.fromJson(null);

        expect(s.as<String?>(), null);
        expect(s.as<dynamic>(), null);
      });

      test(
          'Should return same instance when requesting nullable or non-nullable',
          () {
        var s = Snapshot.fromJson({'street': 'Mainstreet'},
            decoder: decoderWithAddress);
        expect(s.as<Address?>(), same(s.as<Address>()));
      });
    });

    group('Snapshot.asList()', () {
      test('Should return an unmodifiable list of T', () {
        var v = Snapshot.fromJson(['1', '2', '3', '4']);

        var l = v.asList<int>(format: 'string');
        expect(l, isA<List<int>>());
        expect(l, [1, 2, 3, 4]);
        expect(() => l!.removeLast(), throwsUnsupportedError);
        expect(() => l![2] = 0, throwsUnsupportedError);

        v = Snapshot.fromJson(['1.1', '2', '3', '4']);

        expect(() => v.asList<int>(format: 'string'), throwsFormatException);
      });
      test('Should cache list and items', () {
        var v = Snapshot.fromJson(['1', '2', '3', '4']);
        var l = v.asList<int>(format: 'string');
        expect(l, same(v.asList<int>(format: 'string')));

        v = Snapshot.fromJson(['https://google.com']);
        expect(v.asList<Uri>()![0], same(v.child('0').as<Uri>()));
      });
      test('Should update cache correctly', () {
        var v = Snapshot.fromJson(['1', '2', '3', '4']);
        // this will create cache entries for all items in the list
        v.asList<int>(format: 'string');

        // this should update the first two elements in cache and remove the other two
        v.set(['5', '6']);
      });

      test('Should return null when content is null', () {
        var v = Snapshot.fromJson(null);
        expect(v.asList(), null);
      });
    });

    group('Snapshot.asNonNullableList()', () {
      test('Should throw when null', () {
        var v = Snapshot.fromJson(null);
        expect(v.asNonNullableList, throwsA(isA<TypeError>()));
      });
      test('Should be identical to result of asMap', () {
        var v = Snapshot.fromJson([
          {'firstname': 'Jane'}
        ]);
        expect(v.asNonNullableList(), same(v.asList()));
      });
    });

    group('Snapshot.asMap()', () {
      test('Should return an unmodifiable map of <String,T>', () {
        var v = Snapshot.fromJson(
            {'first': '1', 'second': '2', 'third': '3', 'fourth': '4'});

        var l = v.asMap<int>(format: 'string');
        expect(l, isA<Map<String, int>>());
        expect(l, {'first': 1, 'second': 2, 'third': 3, 'fourth': 4});
        expect(() => l!.remove('first'), throwsUnsupportedError);
        expect(() => l!['second'] = 0, throwsUnsupportedError);

        v = Snapshot.fromJson({'first': '1.1', 'second': '2'});

        expect(() => v.asMap<int>(format: 'string'), throwsFormatException);
      });
      test('Should cache map and items', () {
        var v = Snapshot.fromJson(
            {'first': '1', 'second': '2', 'third': '3', 'fourth': '4'});
        var l = v.asMap<int>(format: 'string');
        expect(l, same(v.asMap<int>(format: 'string')));

        v = Snapshot.fromJson({'url': 'https://google.com'});
        expect(v.asMap<Uri>()!['url'], same(v.child('url').as<Uri>()));
      });

      test('Should return null when content is null', () {
        var v = Snapshot.fromJson(null);
        expect(v.asMap(), null);
      });
    });

    group('Snapshot.asNonNullableMap()', () {
      test('Should throw when null', () {
        var v = Snapshot.fromJson(null);
        expect(v.asNonNullableMap, throwsA(isA<TypeError>()));
      });
      test('Should be identical to result of asMap', () {
        var v = Snapshot.fromJson({'firstname': 'Jane'});
        expect(v.asNonNullableMap(), same(v.asMap()));
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
        var lastname = v.child('lastname');
        v = v.set({
          'firstname': 'John',
          'lastname': 'Doe',
        });

        expect(v.child('firstname').as(), 'John');
        expect(lastname, same(v.child('lastname')));
      });

      test('Setting with snapshot value should extract content', () {
        v = v.set(Snapshot.fromJson({
          'firstname': 'John',
          'lastname': 'Doe',
        }));

        expect(v.child('firstname').as(), 'John');
      });

      group('Setting with compatible snapshot', () {
        var json = {
          'firstname': 'Jane',
          'lastname': 'Doe',
          'address1': {'street': 'Mainstreet', 'number': '1', 'city': 'London'},
          'address2': {'street': 'Mainstreet', 'number': '1', 'city': 'London'},
          'address3': {'street': 'Mainstreet', 'number': '1', 'city': 'London'},
        };
        test('Should return this when content unchanged', () {
          var person = Snapshot.fromJson(json, decoder: decoderWithAddress);
          var address1Snap = person.child('address1');
          var address1 = address1Snap.as<Address>();
          var address3Snap = person.child('address3');

          var newValue = Snapshot.fromJson(json, decoder: decoderWithAddress);
          newValue.child('address1').as<Address>();
          var address2Snap = newValue.child('address2');
          var address2 = address2Snap.as<Address>();
          var address3 = newValue.child('address3').as<Address>();

          var v = person.set(newValue);

          expect(v, same(person));
          expect(v.child('address1'), same(address1Snap));
          expect(v.child('address1').as<Address>(), same(address1));
          expect(v.child('address2'), same(address2Snap));
          expect(v.child('address2').as<Address>(), same(address2));
          expect(v.child('address3'), same(address3Snap));
          expect(v.child('address3').as<Address>(), same(address3));
        });

        test('Should return other when content changed', () {
          var person = Snapshot.fromJson(json, decoder: decoderWithAddress);
          var address1Snap = person.child('address1');
          var address1 = address1Snap.as<Address>();
          var address3Snap = person.child('address3');

          var newValue = Snapshot.fromJson(json..['firstname'] = 'John',
              decoder: decoderWithAddress);
          newValue.child('address1').as<Address>();
          var address2Snap = newValue.child('address2');
          var address2 = address2Snap.as<Address>();
          var address3 = newValue.child('address3').as<Address>();

          var v = person.set(newValue);

          expect(v, same(newValue));
          expect(v.child('address1'), same(address1Snap));
          expect(v.child('address1').as<Address>(), same(address1));
          expect(v.child('address2'), same(address2Snap));
          expect(v.child('address2').as<Address>(), same(address2));
          expect(v.child('address3'), same(address3Snap));
          expect(v.child('address3').as<Address>(), same(address3));
        });
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

      test('Setting with snapshot value should extract content', () {
        v = v.setPath('address', Snapshot.fromJson({'city': 'New York'}));

        expect(v.child('address/city').as(), 'New York');
      });

      test('Setting same snapshot twice at different locations', () {
        var persons = Snapshot.fromJson({
          'jane-doe': {'firstname': 'Jane', 'lastname': 'Doe'},
          'john-doe': {'firstname': 'John', 'lastname': 'Doe'}
        });

        var address = Snapshot.fromJson(
            {'street': 'Mainstreet', 'number': '1', 'city': 'London'});

        persons = persons
            .setPath('jane-doe/address', address)
            .setPath('john-doe/address', address);

        expect(persons.child('jane-doe/address'),
            same(persons.child('john-doe/address')));
      });

      test('Setting a non existing parent', () {
        var persons = Snapshot.empty();

        persons = persons.setPath('jane-doe/firstname', 'Jane');

        expect(persons.value, {
          'jane-doe': {'firstname': 'Jane'}
        });

        expect(
            () => persons.setPath('john-doe/firstname', 'John',
                createParents: false),
            throwsArgumentError);
      });

      test('Setting a null value', () {
        var person = Snapshot.empty()
            .setPath('firstname', 'Jane')
            .setPath('address', null)
            .setPath('lastname', 'Doe');

        expect(person.value,
            {'firstname': 'Jane', 'address': null, 'lastname': 'Doe'});
      });
    });

    group('Snapshot.withDecoder()', () {
      test('Should return new snapshot with new decoder', () {
        var v = Snapshot.fromJson({
          'firstname': 'Jane',
          'lastname': 'Doe',
          'address': {'city': 'London'}
        });

        var w = v.withDecoder(decoderWithAddress);

        expect(v, isNot(w));
        expect(w.decoder, decoderWithAddress);
        expect(w.child('address').as<Address>().city, 'London');
      });
      test('Should return same snapshot when decoder same', () {
        var v = Snapshot.fromJson({
          'firstname': 'Jane',
          'lastname': 'Doe',
          'address': {'city': 'London'}
        }, decoder: decoderWithAddress);

        var w = v.withDecoder(decoderWithAddress);

        expect(v, same(w));
      });
    });
    group('Snapshot.operator==', () {
      test('Snapshots are equal when same decoder and content', () {
        void _checkEquality(v) {
          var s1 = Snapshot.fromJson(v);
          var s2 = Snapshot.fromJson(v);

          expect(s1, s2);
        }

        _checkEquality('hello world');
        _checkEquality(3.1);
        _checkEquality(true);
        _checkEquality({'hello': 'world'});
        _checkEquality([
          3.1,
          {true}
        ]);
      });
      test('Snapshots are not equal when different decoder', () {
        void _checkInequality(v) {
          var s1 = Snapshot.fromJson(v, decoder: SnapshotDecoder.empty());
          var s2 = Snapshot.fromJson(v);

          expect(s1, isNot(s2));
        }

        _checkInequality('hello world');
        _checkInequality(3.1);
        _checkInequality(true);
        _checkInequality({'hello': 'world'});
        _checkInequality([
          3.1,
          {true}
        ]);
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
        expect(() => v.convert(Snapshot.empty()), throwsStateError);
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
        expect(
            () => v.convert(Snapshot.fromJson(null)), isNot(throwsA(anything)));
      });
      test('Should try converters in reversed order', () {
        var v = SnapshotDecoder.empty()
          ..register<String, DateTime>((String v, {String? format}) {
            var f = DateFormat(format!);
            return f.parse(v);
          }, format: RegExp('.*'))
          ..register<String, DateTime>((String v) => DateTime.parse(v),
              format: 'iso')
          ..seal();

        expect(
            v.convert<DateTime>(Snapshot.fromJson('2020-01-01T10:00'),
                format: 'iso'),
            DateTime(2020, 1, 1, 10, 0));
        expect(
            () => v.convert<DateTime>(Snapshot.fromJson('2020-01-01T10:00'),
                format: 'dd/MM/yyyy'),
            throwsFormatException);
        expect(
            v.convert<DateTime>(Snapshot.fromJson('01/01/2020'),
                format: 'dd/MM/yyyy'),
            DateTime(2020, 1, 1));
        expect(
            () => v.convert<DateTime>(Snapshot.fromJson('01/01/2020'),
                format: 'iso'),
            throwsFormatException);

        v = SnapshotDecoder.from(v)
          ..register<String, DateTime>((String v, {String? format}) {
            var f = DateFormat(format!);
            return f.parse(v);
          }, format: RegExp('.*'))
          ..seal();

        expect(
            () => v.convert<DateTime>(Snapshot.fromJson('2020-01-01T10:00'),
                format: 'iso'),
            throwsFormatException);
        expect(
            () => v.convert<DateTime>(Snapshot.fromJson('2020-01-01T10:00'),
                format: 'dd/MM/yyyy'),
            throwsFormatException);
        expect(
            v.convert<DateTime>(Snapshot.fromJson('01/01/2020'),
                format: 'dd/MM/yyyy'),
            DateTime(2020, 1, 1));
        expect(
            () => v.convert<DateTime>(Snapshot.fromJson('01/01/2020'),
                format: 'iso'),
            throwsFormatException);
      });
    });
  });
}

class Address extends UnmodifiableSnapshotView {
  Address(Snapshot snapshot) : super(snapshot);

  String get street => get('street');
  String get city => get('city');
}
