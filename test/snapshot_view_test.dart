import 'dart:async';

import 'package:snapshot/snapshot.dart';
import 'package:test/test.dart';

void main() {
  group('SnapshotView', () {
    group('SnapshotView.toJson()', () {
      test('Should return content unmodified', () {
        SnapshotView v = UnmodifiableSnapshotView.fromJson(
            {'firstname': 'Jane', 'lastname': 'Doe'});

        expect(v.toJson(), {'firstname': 'Jane', 'lastname': 'Doe'});

        v = ModifiableSnapshotView.fromJson(
            {'firstname': 'Jane', 'lastname': 'Doe'});

        expect(v.toJson(), {'firstname': 'Jane', 'lastname': 'Doe'});
      });
    });

    group('SnapshotView.get()', () {
      test('Should return and convert property', () {
        var decoder = SnapshotDecoder()
          ..register<Map<String, dynamic>, Address>((v) => Address.fromJson(v))
          ..seal();
        SnapshotView v = UnmodifiableSnapshotView.fromJson({
          'firstname': 'Jane',
          'lastname': 'Doe',
          'pictureUrl': 'https://my.avatar.com/jane-doe',
          'address': {'addressLine1': 'Mainstreet 1', 'city': 'London'}
        }, decoder: decoder);

        expect(v.get('firstname'), 'Jane');
        expect(v.get<Uri>('pictureUrl'),
            Uri.parse('https://my.avatar.com/jane-doe'));
        var address = v.get<Address>('address');
        expect(address, isA<Address>());
        expect(address.city, 'London');
        expect(address.addressLine1, 'Mainstreet 1');

        v = ModifiableSnapshotView.fromJson({
          'firstname': 'Jane',
          'lastname': 'Doe',
          'pictureUrl': 'https://my.avatar.com/jane-doe',
          'address': {'addressLine1': 'Mainstreet 1', 'city': 'London'}
        }, decoder: decoder);

        expect(v.get('firstname'), 'Jane');
        expect(v.get<Uri>('pictureUrl'),
            Uri.parse('https://my.avatar.com/jane-doe'));
        address = v.get<Address>('address');
        expect(address, isA<Address>());
        expect(address.city, 'London');
        expect(address.addressLine1, 'Mainstreet 1');
      });
    });

    group('SnapshotView.set()', () {
      test('Should update content', () {
        var decoder = SnapshotDecoder()
          ..register<Map<String, dynamic>, ModifiableAddress>(
              (v) => ModifiableAddress.fromJson(v))
          ..seal();
        var v = ModifiableSnapshotView.fromJson({
          'firstname': 'Jane',
          'lastname': 'Doe',
          'pictureUrl': 'https://my.avatar.com/jane-doe',
          'address': {'addressLine1': 'Mainstreet 1', 'city': 'London'}
        }, decoder: decoder);

        v.set('firstname', 'John');
        expect(v.get('firstname'), 'John');
        expect(v.get('lastname'), 'Doe');

        var address = v.get<ModifiableAddress>('address');

        address.city = 'New York';
        expect(address.city, 'New York');
        expect(address.addressLine1, 'Mainstreet 1');
        expect(v.get('address/city'), 'London');

        v.set('address', address.toJson());
        expect(v.get('address/city'), 'New York');
      });
    });
  });

  group('ModifiableSnapshotView', () {
    group('ModifiableSnapshotView.fromJson', () {
      test('Should create a SnapshotView with initial data', () {
        var snapshot = ModifiableSnapshotView.fromJson({
          'firstname': 'John',
          'address': {'addressLine1': 'Mainstreet 1', 'city': 'London'}
        });

        expect(snapshot.get('address/city'), 'London');
        expect(snapshot.get('firstname'), 'John');
      });
      test('Should allow to set content', () {
        var snapshot = ModifiableSnapshotView.fromJson({
          'firstname': 'John',
          'address': {'addressLine1': 'Mainstreet 1', 'city': 'London'}
        });

        snapshot.set('address/city', 'New York');

        expect(snapshot.get('address/city'), 'New York');
      });
    });

    group('ModifiableSnapshotView.fromStream', () {
      test('Lifecycle for non broadcast stream', () async {
        var listenCalled = false,
            pauseCalled = false,
            cancelCalled = false,
            resumeCalled = false;
        var controller = StreamController<Snapshot>(onListen: () {
          listenCalled = true;
        }, onPause: () {
          pauseCalled = true;
        }, onResume: () {
          resumeCalled = true;
        }, onCancel: () {
          cancelCalled = true;
        });
        var view = ModifiableSnapshotView.fromStream(controller.stream);

        expect(() => view.snapshot, throwsStateError);
        expect(view.hasValue, false);
        expect(listenCalled, false);

        // listening on onChanged should trigger listen on controller
        var s = view.onChanged.listen((_) => null);
        expect(view.hasValue, false);
        expect(listenCalled, true);

        // adding a snapshot to the controller should update the view
        controller.add(Snapshot.empty());
        await Future.microtask(() => null);
        expect(view.hasValue, true);
        expect(view.snapshot, isNotNull);

        // canceling the subscription onChanged should pause the controller
        expect(pauseCalled, false);
        await s.cancel();
        expect(pauseCalled, true);

        // listening again should trigger resume on controller
        expect(resumeCalled, false);
        s = view.onChanged.listen((_) => null);
        expect(resumeCalled, true);

        // disposing the snapshot view should cancel the controller
        expect(cancelCalled, false);
        await view.dispose();
        expect(cancelCalled, true);
      });
      test('Lifecycle for broadcast stream', () async {
        var listenCalled = false, cancelCalled = false;
        var controller = StreamController<Snapshot>.broadcast(onListen: () {
          listenCalled = true;
        }, onCancel: () {
          cancelCalled = true;
        });
        var view = ModifiableSnapshotView.fromStream(controller.stream);

        expect(() => view.snapshot, throwsStateError);
        expect(view.hasValue, false);
        expect(listenCalled, false);

        // listening on onChanged should trigger listen on controller
        var s = view.onChanged.listen((_) => null);
        expect(view.hasValue, false);
        expect(listenCalled, true);

        // adding a snapshot to the controller should update the view
        controller.add(Snapshot.empty());
        await Future.microtask(() => null);
        expect(view.hasValue, true);
        expect(view.snapshot, isNotNull);

        // canceling the subscription should cancel the controller
        expect(cancelCalled, false);
        await s.cancel();
        expect(cancelCalled, true);

        // listening again should trigger listen on controller
        listenCalled = false;
        s = view.onChanged.listen((_) => null);
        expect(listenCalled, true);

        // disposing the snapshot view should cancel the controller
        cancelCalled = false;
        await view.dispose();
        expect(cancelCalled, true);
      });
    });
  });
}

mixin AddressMixin on SnapshotView {
  String? get addressLine1 => get('addressLine1');

  String? get city => get('city');
}

class Address = UnmodifiableSnapshotView with AddressMixin;

mixin ModifiableAddressMixin on ModifiableSnapshotView {
  set addressLine1(String? v) => set('addressLine1', v);

  set city(String? v) => set('city', v);
}

class ModifiableAddress = ModifiableSnapshotView
    with AddressMixin, ModifiableAddressMixin;
