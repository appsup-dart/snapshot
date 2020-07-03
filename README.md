A library that can be used to implement data classes

A `Snapshot` simplifies accessing and converting properties in a JSON-like 
object, for example a JSON object returned from a REST-api service.

# Using Snapshot objects directly

```dart
void main() {
  var v = Snapshot.fromJson({
    'firstname': 'Jane',
    'lastname': 'Doe',
    'profileUrl': 'https://my.avatar.com/jane-doe.png',
    'createdAt': 1593698272650,
    'dateOfBirth': '2001-01-02',
    'address': {
      'addressLine1': 'Mainstreet 1',
      'city': 'London',
    }
  });

  // getting a property as core data type
  var firstname = v.child('firstname').as<String>();
  print('firstname = $firstname');

  // getting a property and converting it to an Uri
  var profileUrl = v.child('profileUrl').as<Uri>();
  print('profile url = $profileUrl');

  // converting to a DateTime object
  var dateOfBirth = v.child('dateOfBirth').as<DateTime>();
  print('age = ${DateTime.now().difference(dateOfBirth).inDays} days');

  // converting to a DateTime object with alternative format
  var createAt = v.child('createdAt').as<DateTime>(format: 'epoch');
  print('created at = $createAt');

  // accessing a subfield
  var addressLine1 = v.child('address/addressLine1').as<String>();
  print('address = $addressLine1');

  // or
  addressLine1 = v.child('address').child('addressLine1').as();
  print('address = $addressLine1');
}

```

# Creating data object classes based on snapshots

```dart

// create a mixin on a [SnapshotView]
mixin PersonMixin on SnapshotView {
  
  // add getters for fields 
  String get firstname => get('firstname');
  
  // no need to add type arguments, it will be detected automatically
  Uri get profileUrl => get('profileUrl');

  // add format parameter when not in a default format
  DateTime get createdAt => get('createdAt', format: 'epoch');

}

// create a class extending a UnmodifiableSnapshotView with the mixin
// this will provide a `fromJson` constructor 
class Person = UnmodifiableSnapshotView with PersonMixin;

void main() {
  // registering a converter for the data class
  var decoder = SnapshotDecoder()
    ..register<Map<String, dynamic>, Person>((v) => Person.fromJson(v));

  var snapshot = Snapshot.fromJson({
    'firstname': 'Jane',
    'profileUrl': 'https://my.avatar.com/jane-doe.png',
    'createdAt': 1593698272650
  }, decoder: decoder);

  var person = snapshot.as<Person>();

  print('hello ${person.firstname}');
}
```