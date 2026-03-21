import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../appwrite_client.dart';
import '../theme/app_theme.dart';

/// Square crop + upload to chat files bucket (avatars / group icons).
Future<String?> pickAndUploadSquareChatImage({
  required String filePrefix,
}) async {
  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (pickedFile == null) return null;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 70,
      maxWidth: 512,
      maxHeight: 512,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: const Color(0xFF161618),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppTheme.focusBlue,
          hideBottomControls: false,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Crop Image', aspectRatioLockEnabled: true),
      ],
    );
    if (croppedFile == null) return null;

    final file = await appwriteStorage.createFile(
      bucketId: AppwriteConstants.chatFilesBucket,
      fileId: ID.unique(),
      file: InputFile.fromPath(
        path: croppedFile.path,
        filename: '$filePrefix-${const Uuid().v4()}.jpg',
      ),
      permissions: publicReadPermissions(),
    );

    return buildStoragePreviewUrl(file.$id, width: 320, height: 320);
  } catch (_) {
    throw Exception('Image upload unavailable');
  }
}
