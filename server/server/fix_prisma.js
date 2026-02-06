const { execSync } = require('child_process');
const path = require('path');

const env = {
    ...process.env,
    DATABASE_URL: "postgresql://postgres:1105@localhost:5433/staynest?schema=public"
};

try {
    console.log('Generating Prisma Client...');
    execSync('npx prisma generate', { env, stdio: 'inherit' });
    console.log('Success!');
} catch (e) {
    console.error('Failed to generate Prisma Client');
    process.exit(1);
}
