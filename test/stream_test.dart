import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:snapshot/snapshot.dart';
import 'package:test/test.dart';

void main() async {
  group('Stream.toSnapshots', () {
    test('Should convert to equivalent stream of snapshots', () async {
      var values = [
        {'firstname': 'Jane'},
        {'firstname': 'Jane', 'lastname': 'Doe'},
        {'firstname': 'John'}
      ];
      var stream = Stream.fromIterable(values).toSnapshots();

      expect(await stream.map((s) => s.as()).toList(), values);
    });

    test('Should reuse cache for unchanged items', () async {
      var values = [
        {'firstname': 'Jane'},
        {'firstname': 'Jane', 'lastname': 'Doe'},
      ];
      var stream = Stream.fromIterable(values).toSnapshots();

      var l = await stream.map((v) => v.child('firstname')).toList();

      expect(l[0], same(l[1]));
    });

    test('Should emit only distinct values', () async {
      var values = [
        {'firstname': 'Jane'},
        {'firstname': 'Jane'},
      ];
      var stream = Stream.fromIterable(values).toSnapshots();

      var l = await stream.toList();

      expect(l.length, 1);
    });
  });
  group('Stream<Snapshot>', () {
    group('Stream<Snapshot>.child', () {
      test('Should take child of each snapshot', () async {
        var stream = Stream.fromIterable([
          {'firstname': 'Jane'},
          {'firstname': 'John'}
        ]).toSnapshots();

        var firstnames = await stream.child('firstname').as<String>().toList();

        expect(firstnames, ['Jane', 'John']);
      });
      test('Should only emit distinct values', () async {
        var stream = Stream.fromIterable([
          {'firstname': 'Jane'},
          {'firstname': 'Jane', 'email': 'jane@example.com'},
          {'firstname': 'John'}
        ]).toSnapshots();

        var firstnames = await stream.child('firstname').as<String>().toList();

        expect(firstnames, ['Jane', 'John']);
      });
    });

    group('Stream<Snapshot>.as', () {
      test('Should convert to objects of type T', () async {
        var stream = Stream.fromIterable([
          'https://avatars.com/jane-doe.png',
          'https://avatars.com/john-doe.png',
        ]).toSnapshots();

        var l = await stream.as<Uri>().toList();

        expect(l, [
          Uri.parse('https://avatars.com/jane-doe.png'),
          Uri.parse('https://avatars.com/john-doe.png'),
        ]);
      });
    });

    group('Stream<Snapshot>.asList', () {
      test('Should convert items to objects of type T', () async {
        var stream = Stream.fromIterable([
          ['https://avatars.com/jane-doe.png'],
          ['https://avatars.com/john-doe.png'],
        ]).toSnapshots();

        var l = await stream.asList<Uri>()!.toList();

        expect(l, [
          [Uri.parse('https://avatars.com/jane-doe.png')],
          [Uri.parse('https://avatars.com/john-doe.png')],
        ]);
      });
    });

    group('Stream<Snapshot>.asMap', () {
      test('Should convert values to objects of type T', () async {
        var stream = Stream.fromIterable([
          {'picture': 'https://avatars.com/jane-doe.png'},
          {'picture': 'https://avatars.com/john-doe.png'},
        ]).toSnapshots();

        var l = await stream.asMap<Uri>().toList();

        expect(l, [
          {'picture': Uri.parse('https://avatars.com/jane-doe.png')},
          {'picture': Uri.parse('https://avatars.com/john-doe.png')},
        ]);
      });
    });

    group('Stream<Snapshot>.setPath', () {
      test('Should overwrite the value at path', () async {
        var stream = Stream.value({'firstname': 'jane'}).toSnapshots();

        stream = stream.setPath('address', {'street': 'Mainstreet'});

        expect((await stream.first).child('address/street').as(), 'Mainstreet');
      });
    });

    group('Stream<Snapshot>.asyncSetPath', () {
      test('Should overwrite the value at path asynchronously', () async {
        var stream = Stream.value({'firstname': 'jane'}).toSnapshots();

        stream = stream.asyncSetPath(
            'address',
            Stream.fromIterable([
              {'street': 'Mainstreet'},
              {'street': '1st street'}
            ]));

        var l = await stream.child('address/street').as().toList();

        expect(l, ['Mainstreet', '1st street']);
      });
    });
    group('Stream<Snapshot>.switchPath', () {
      test('Should overwrite the value at path', () async {
        var stream = Stream.fromIterable([
          {
            'firstname': 'jane',
            'address': {
              'street': 'Mainstreet',
              'number': '1',
              'city': 'London'
            },
          },
        ]).toSnapshots();

        stream = stream.switchPath(
            'address',
            (s) => Stream.value(
                '${s.child('street').as()} ${s.child('number').as()}, ${s.child('city').as()}'));

        expect(
            (await stream.first).child('address').as(), 'Mainstreet 1, London');
      });
      test('Should switch only when value at path changes', () async {
        var stream = Stream.fromIterable([
          {
            'firstname': 'jane',
            'address': {
              'street': 'Mainstreet',
              'number': '1',
              'city': 'London'
            },
          },
          {
            'firstname': 'john',
            'address': {
              'street': 'Mainstreet',
              'number': '1',
              'city': 'London'
            },
          },
          {
            'firstname': 'jane',
            'address': {'street': '1st street', 'number': '111', 'city': 'NY'},
          },
        ]).toSnapshots();

        var values = [];
        stream = stream.switchPath('address', (s) {
          var v =
              '${s.child('street').as()} ${s.child('number').as()}, ${s.child('city').as()}';
          values.add(v);
          return Stream.value(v);
        });

        var l = await stream.child('address').as().toList();
        expect(l, [
          'Mainstreet 1, London',
          '1st street 111, NY',
        ]);
        expect(values, l);
      });

      test('Should keep broadcast behavior', () async {
        var controller = StreamController.broadcast();

        var stream = controller.stream.toSnapshots();

        stream = stream.switchPath('address', (s) {
          var v =
              '${s.child('street').as()} ${s.child('number').as()}, ${s.child('city').as()}';
          return Stream.value(v);
        });

        expect(stream.isBroadcast, true);
      });
    });

    group('Stream<Snapshot>.mapChildren', () {
      test('Should replace all children', () async {
        var stream = Stream.value({
          'jane': {'firstname': 'Jane', 'lastname': 'Doe'},
          'john': {'firstname': 'John', 'lastname': 'Doe'},
        }).toSnapshots();

        stream = stream.mapChildren((key, value) =>
            '${value.child('firstname').as()} ${value.child('lastname').as()}');

        expect((await stream.first).as(),
            {'jane': 'Jane Doe', 'john': 'John Doe'});
      });
    });
    group('Stream<Snapshot>.switchChildren', () {
      test('RemoteReference.switchChildren', () async {
        var stream = Stream<Snapshot>.value(Snapshot.fromJson({
          'jane': {'firstname': 'Jane', 'lastname': 'Doe'},
          'john': {'firstname': 'John', 'lastname': 'Doe'},
        }));

        stream = stream.switchChildren((key, value) => Stream.value(
            '${value.child('firstname').as()} ${value.child('lastname').as()}'));

        expect((await stream.first).as(),
            {'jane': 'Jane Doe', 'john': 'John Doe'});
      });

      test('with empty map', () async {
        var stream = Stream<Snapshot>.value(Snapshot.fromJson({}));

        stream = stream.switchChildren((key, value) => Stream.value(
            '${value.child('firstname').as()} ${value.child('lastname').as()}'));

        expect((await stream.first).as(), {});
      });
    });
    group('Stream<Snapshot>.recycle', () {
      test('Stream<Snapshot>.recycle', () async {
        var controller = BehaviorSubject<Snapshot>();

        var stream = controller.stream.recycle();

        var value = {
          'persons': {
            'jane-doe': {'firstname': 'Jane', 'lastname': 'Doe'},
            'john-doe': {'firstname': 'John', 'lastname': 'Doe'}
          }
        };

        controller.add(Snapshot.fromJson(value));

        var jane = await stream.child('persons/jane-doe').as<dynamic>().first;

        controller.add(Snapshot.fromJson(value));

        var jane2 = await stream.child('persons/jane-doe').as<dynamic>().first;

        expect(jane2, same(jane));
      });
    });
  });
}
