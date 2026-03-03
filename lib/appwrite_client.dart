import 'package:appwrite/appwrite.dart';

class Environment {
  static const String appwriteProjectId = '69a6d89d0007909f06f7';
  static const String appwriteProjectName = 'Point Chat';
  static const String appwritePublicEndpoint = 'https://fra.cloud.appwrite.io/v1';
}

final Client client = Client()
  .setProject(Environment.appwriteProjectId)
  .setEndpoint(Environment.appwritePublicEndpoint);
