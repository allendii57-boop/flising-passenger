const fs = require('fs');
const file = 'index.js';
let content = fs.readFileSync(file, 'utf8');

let sections = content.split('// 4. PUSH NOTIFICATION');

if (sections.length > 1) {
    sections[0] = sections[0].replace(/notification:\s*\{[^}]+\},?/g, '');
    fs.writeFileSync(file, sections.join('// 4. PUSH NOTIFICATION'));
    console.log('✅ index.js patched! Driver payload is now data-only.');
} else {
    console.log('⚠️ Could not find section 4. File unmodified.');
}
