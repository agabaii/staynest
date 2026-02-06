const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
    console.log('Prisma keys:', Object.keys(prisma));
    try {
        const count = await prisma.user.count();
        console.log('User count:', count);
    } catch (e) {
        console.error('User error:', e.message);
    }

    try {
        console.log('PropertyCalendar model:', prisma.propertyCalendar ? 'Exists' : 'Missing');
    } catch (e) {
        console.error('PropertyCalendar error:', e.message);
    }
}

main().finally(() => prisma.$disconnect());
