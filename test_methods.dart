// Quick test to verify methods exist
import 'lib/database_helper.dart';

void main() async {
  final db = DatabaseHelper();
  
  // Test 1: getUnsyncedPOE
  print('Testing getUnsyncedPOE...');
  final unsynced = await db.getUnsyncedPOE(123);
  print('✓ getUnsyncedPOE works: ${unsynced.length} records');
  
  // Test 2: saveLearnerPathwaysCache
  print('Testing saveLearnerPathwaysCache...');
  await db.saveLearnerPathwaysCache(123, {'test': 'data'});
  print('✓ saveLearnerPathwaysCache works');
  
  // Test 3: getLearnerPathwaysCache
  print('Testing getLearnerPathwaysCache...');
  final cache = await db.getLearnerPathwaysCache(123);
  print('✓ getLearnerPathwaysCache works: ${cache != null}');
  
  print('\n✅ All methods exist and are callable!');
}
