const fs = require('fs');
const file = 'index.js';
let code = fs.readFileSync(file, 'utf8');

// Split at section 4 so we only affect the Driver New Ride request
let parts = code.split('// 4. PUSH NOTIFICATION');

if (parts.length > 1) {
    // Safely remove the main notification block regardless of dynamic text/braces
    parts[0] = parts[0].replace(/notification:\s*\{[\s\S]*?\},\s*data:/, 'data:');
    
    // Safely remove the android sound configuration
    parts[0] = parts[0].replace(/,\s*notification:\s*\{\s*sound:\s*'default'\s*\}/, '');
    
    fs.writeFileSync(file, parts.join('// 4. PUSH NOTIFICATION'));
    console.log('✅ Payload patched securely! Driver payload is now data-only.');
} else {
    console.log('⚠️ Could not find section 4.');
}
