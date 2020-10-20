// Copyright 2017, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_storage_platform_interface/firebase_storage_platform_interface.dart';
import 'package:firebase/firebase.dart' as fb;
import 'package:firebase_storage_web/src/task_web.dart';
import 'package:firebase_storage_web/src/utils/list.dart';
import 'package:http/http.dart' as http;

import './firebase_storage_web.dart';
import './utils/metadata.dart';

/// The web implementation of a Firebase Storage 'ref'
class ReferenceWeb extends ReferencePlatform {
  /// The js-interop layer for the ref that is wrapped by this class...
  fb.StorageReference _ref;

  // The path for the current ref
  final String _path;

  /// Constructor for this ref
  ReferenceWeb(FirebaseStorageWeb storage, String path)
      : _path = path,
        super(storage, path) {
    if (_path != null && _path.startsWith(r'^(?:gs|https?)://')) {
      _ref = storage.storage.refFromURL(_path);
    } else {
      _ref = storage.storage.ref(_path);
    }
  }

  // Platform overrides follow

  /// Deletes the object at this reference's location.
  Future<void> delete() {
    return _ref.delete();
  }

  /// Fetches a long lived download URL for this object.
  Future<String> getDownloadURL() {
    return _ref.getDownloadURL().then((uri) => uri.toString());
  }

  /// Fetches metadata for the object at this location, if one exists.
  Future<FullMetadata> getMetadata() {
    return _ref.getMetadata().then(fbFullMetadataToFullMetadata);
  }

  /// List items (files) and prefixes (folders) under this storage reference.
  ///
  /// List API is only available for Firebase Rules Version 2.
  ///
  /// GCS is a key-blob store. Firebase Storage imposes the semantic of '/'
  /// delimited folder structure. Refer to GCS's List API if you want to learn more.
  ///
  /// To adhere to Firebase Rules's Semantics, Firebase Storage does not support
  /// objects whose paths end with "/" or contain two consecutive "/"s. Firebase
  /// Storage List API will filter these unsupported objects. [list] may fail
  /// if there are too many unsupported objects in the bucket.
  Future<ListResultPlatform> list(ListOptions options) {
    return _ref
        .list(listOptionsToFbListOptions(options))
        .then((result) => fbListResultToListResultWeb(storage, result));
  }

  ///List all items (files) and prefixes (folders) under this storage reference.
  ///
  /// This is a helper method for calling [list] repeatedly until there are no
  /// more results. The default pagination size is 1000.
  ///
  /// Note: The results may not be consistent if objects are changed while this
  /// operation is running.
  ///
  /// Warning: [listAll] may potentially consume too many resources if there are
  /// too many results.
  Future<ListResultPlatform> listAll() {
    return _ref
        .listAll()
        .then((result) => fbListResultToListResultWeb(storage, result));
  }

  /// Asynchronously downloads the object at the StorageReference to a list in memory.
  ///
  /// Returns a [Uint8List] of the data. If the [maxSize] (in bytes) is exceeded,
  /// the operation will be canceled.
  Future<Uint8List> getData(int maxSize) async {
    if (maxSize > 0) {
      final metadata = await _ref.getMetadata();
      if (metadata.size > maxSize) {
        return null;
      }
    }
    return _ref
        .getDownloadURL()
        .then((uri) => uri.toString())
        .then((downloadUri) => http.readBytes(downloadUri));
  }

  /// Uploads data to this reference's location.
  ///
  /// Use this method to upload fixed sized data as a [Uint8List].
  ///
  /// Optionally, you can also set metadata onto the uploaded object.
  TaskPlatform putData(Uint8List data, [SettableMetadata metadata]) {
    return TaskWeb(
      storage,
      _ref.put(
        data,
        settableMetadataToFbUploadMetadata(
          metadata,
          md5Hash: md5.convert(data).toString(),
        ),
      ),
    );
  }

  /// Upload a [Blob]. Note; this is only supported on web platforms.
  ///
  /// Optionally, you can also set metadata onto the uploaded object.
  TaskPlatform putBlob(dynamic data, [SettableMetadata metadata]) {
    return TaskWeb(
      storage,
      _ref.put(
        data,
        settableMetadataToFbUploadMetadata(
          metadata,
          md5Hash: md5.convert(data).toString(),
        ),
      ),
    );
  }

  /// Upload a [String] value as a storage object.
  ///
  /// Use [PutStringFormat] to correctly encode the string:
  ///   - [PutStringFormat.raw] the string will be encoded in a Base64 format.
  ///   - [PutStringFormat.dataUrl] the string must be in a data url format
  ///     (e.g. "data:text/plain;base64,SGVsbG8sIFdvcmxkIQ=="). If no
  ///     [SettableMetadata.mimeType] is provided as part of the [metadata]
  ///     argument, the [mimeType] will be automatically set.
  ///   - [PutStringFormat.base64] will be encoded as a Base64 string.
  ///   - [PutStringFormat.base64Url] will be encoded as a Base64 string safe URL.
  TaskPlatform putString(
    String data,
    PutStringFormat format, [
    SettableMetadata metadata,
  ]) {
    return TaskWeb(
      storage,
      _ref.putString(
        data,
        putStringFormatToString(format),
        settableMetadataToFbUploadMetadata(
          metadata,
          md5Hash: md5.convert(data.codeUnits).toString(),
        ),
      ),
    );
  }

  /// Updates the metadata on a storage object.
  Future<FullMetadata> updateMetadata(SettableMetadata metadata) {
    return _ref
        .updateMetadata(settableMetadataToFbSettableMetadata(metadata))
        .then(fbFullMetadataToFullMetadata);
  }

  // Purposefully left unimplemented because of lack of dart:io support in web:

  // TaskPlatform writeToFile(File file) {}
  // TaskPlatform putFile(File file, [SettableMetadata metadata]) {}
}