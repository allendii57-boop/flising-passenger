#!/bin/bash
FILE="$HOME/flising-driver-app/lib/main_screen.dart"

# Use sed to insert the cleanup loop right after finding the bestId in _restoreActiveRide
sed -i '/if (bestId == null || best == null) return;/i \
    for (final entry in rides.entries) {\
      final r = entry.value;\
      if (r is! Map) continue;\
      if (r['\''status'\''] != '\''ACCEPTED'\'' && r['\''status'\''] != '\''IN_PROGRESS'\'') continue;\
      final String id = entry.key.toString();\
      if (id != bestId) {\
        FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: '\''https://flising-default-rtdb.asia-southeast1.firebasedatabase.app'\'').ref('\''rides/$id'\'').update({'\''status'\'': '\''CANCELLED_SYSTEM_CLEANUP'\''});\
      }\
    }\
' "$FILE"

echo "Patch applied successfully."
