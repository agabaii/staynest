const { execSync } = require('child_process');

try {
    console.log('Running prisma generate...');
    const output = execSync('npx prisma generate', { encoding: 'utf8' });
    console.log('Output:', output);
} catch (e) {
    console.error('Error:', e.message);
    if (e.stdout) console.log('Stdout:', e.stdout);
    if (e.stderr) console.log('Stderr:', e.stderr);
}
