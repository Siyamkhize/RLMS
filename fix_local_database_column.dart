// fix_local_database_column.dart
// Quick fix to add the missing assessorExpiryDate column to local database

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<void> fixLocalDatabaseColumn() async {
  try {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'local_data.db');
    
    final database = await openDatabase(path);
    
    print('Checking if assessorExpiryDate column exists...');
    
    // Check if column exists
    final result = await database.rawQuery("PRAGMA table_info(facilitator)");
    bool columnExists = false;
    
    for (final row in result) {
      if (row['name'] == 'assessorExpiryDate') {
        columnExists = true;
        break;
      }
    }
    
    if (!columnExists) {
      print('Adding assessorExpiryDate column...');
      await database.execute('ALTER TABLE facilitator ADD COLUMN assessorExpiryDate TEXT');
      print('✓ Column added successfully!');
    } else {
      print('✓ Column already exists');
    }
    
    // Verify the column was added
    final verifyResult = await database.rawQuery("PRAGMA table_info(facilitator)");
    print('\nCurrent facilitator table columns:');
    for (final row in verifyResult) {
      print('- ${row['name']} (${row['type']})');
    }
    
    await database.close();
    print('\nDatabase fix completed!');
    
  } catch (e) {
    print('Error fixing database: $e');
  }
}

void main() async {
  await fixLocalDatabaseColumn();
}

/*
To run this fix:
1. Add this file to your Flutter project
2. Run: flutter run fix_local_database_column.dart
3. Or call fixLocalDatabaseColumn() from your app

This will add the missing assessorExpiryDate column to your local database.
*/