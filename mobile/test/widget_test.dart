import 'dart:typed_data';

import 'package:flutter_app/models/picked_file.dart';
import 'package:flutter_app/models/uploaded_file.dart';
import 'package:flutter_app/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('User.fromJson lee la respuesta de la API', () {
    final user =
        User.fromJson({'id': 1, 'name': 'Ana', 'email': 'ana@test.com'});
    expect(user.id, 1);
    expect(user.email, 'ana@test.com');
  });

  test('PickedFile detecta el tipo MIME por la extension', () {
    final image = PickedFile(name: 'foto.PNG', bytes: Uint8List(3));
    final doc = PickedFile(name: 'informe.pdf', bytes: Uint8List(3));
    expect(image.mimeType, 'image/png');
    expect(image.isImage, isTrue);
    expect(doc.mimeType, 'application/pdf');
    expect(doc.isImage, isFalse);
  });

  test('UploadedFile.fromJson lee la respuesta de /upload', () {
    final file = UploadedFile.fromJson({
      'id': 1,
      'originalName': 'foto.png',
      'storedName': 'abc.png',
      'contentType': 'image/png',
      'size': 10,
      'url': '/files/abc.png',
    });
    expect(file.isImage, isTrue);
    expect(file.url, '/files/abc.png');
  });
}
