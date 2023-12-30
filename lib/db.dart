import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

class DB {
  static Database db = null as Database;

  static Future<void> load() async {
    Directory appDocDirectory = await getApplicationDocumentsDirectory();
    String dbPath = '${appDocDirectory.path}/chat.db';
    db = await databaseFactoryIo.openDatabase(dbPath);
  }
}
