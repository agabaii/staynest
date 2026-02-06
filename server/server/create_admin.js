const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function main() {
    const email = 'agabaiaida@gmail.com';
    const password = '123456';
    const name = 'Super Admin';
    const phone = '+77777777777';

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await prisma.user.upsert({
        where: { email: email },
        update: {
            password: hashedPassword,
            role: 'ADMIN',
            isVerified: true,
            name: name,
            phone: phone
        },
        create: {
            email: email,
            password: hashedPassword,
            name: name,
            phone: phone,
            role: 'ADMIN',
            isVerified: true,
            verificationCode: null
        },
    });

    console.log('Admin user created/updated:', user);
}

main()
    .catch((e) => {
        console.error(e);
        process.exit(1);
    })
    .finally(async () => {
        await prisma.$disconnect();
    });
