const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const fs = require('fs');
const path = require('path');
const https = require('https');

const prisma = new PrismaClient();

async function downloadImage(url, filename) {
    const filePath = path.join(__dirname, 'uploads', filename);
    return new Promise((resolve, reject) => {
        https.get(url, (res) => {
            if (res.statusCode === 200) {
                const fileStream = fs.createWriteStream(filePath);
                res.pipe(fileStream);
                fileStream.on('finish', () => {
                    fileStream.close();
                    resolve(`/uploads/${filename}`);
                });
            } else {
                reject(new Error(`Failed to download: ${res.statusCode}`));
            }
        }).on('error', reject);
    });
}

async function main() {
    const email = 'agabaiii@icloud.com';
    const password = '123456';
    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await prisma.user.upsert({
        where: { email },
        update: { password: hashedPassword, isVerified: true },
        create: { email, password: hashedPassword, name: 'Agabai', isVerified: true },
    });

    console.log('Пользователь:', user.email);

    if (!fs.existsSync('uploads')) {
        fs.mkdirSync('uploads');
    }

    await prisma.property.deleteMany({ where: { authorId: user.id } });

    const propertySeeds = [
        {
            title: 'Пентхаус Esentai City',
            description: 'Современный пентхаус в самом престижном районе Алматы. Панорамные окна, дизайнерский ремонт. Огромная терраса с видом на горы.',
            price: 65000, rentType: 'DAILY', propertyType: 'Квартира', country: 'Казахстан', city: 'Алматы', district: 'Медеуский',
            amenities: ['Wi-Fi', 'Кондиционер', 'Парковка', 'Кухня'],
            imageUrls: [
                'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800&q=70',
                'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800&q=70'
            ]
        },
        {
            title: 'Вилла Royal Palm',
            description: 'Эксклюзивная вилла в Дубае. Собственный бассейн и выход к морю.',
            price: 150000, rentType: 'DAILY', propertyType: 'Вилла', country: 'ОАЭ', city: 'Дубай', district: 'Palm Jumeirah',
            amenities: ['Бассейн', 'Кондиционер', 'Парковка', 'Wi-Fi'],
            imageUrls: [
                'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=800&q=70',
                'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800&q=70'
            ]
        },
        {
            title: 'Loft Manhattan',
            description: 'Стильный лофт в центре Нью-Йорка. Высокие потолки, индустриальный дизайн.',
            price: 95000, rentType: 'DAILY', propertyType: 'Лофт', country: 'США', city: 'Нью-Йорк', district: 'Манхэттен',
            amenities: ['Wi-Fi', 'Кондиционер', 'Стиральная машина'],
            imageUrls: [
                'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800&q=70',
                'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800&q=70'
            ]
        },
        {
            title: 'Студия Orchidée Paris',
            description: 'Уютная студия с видом на Эйфелеву башню. Идеально для пар.',
            price: 75000, rentType: 'DAILY', propertyType: 'Квартира', country: 'Франция', city: 'Париж', district: '7-й округ',
            amenities: ['Wi-Fi', 'Кухня', 'ТВ', 'Фен'],
            imageUrls: [
                'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800&q=70',
                'https://images.unsplash.com/photo-1499916078039-922301b0eb9b?w=800&q=70'
            ]
        },
        {
            title: 'Дом в Ремизовке',
            description: 'Просторный дом в предгорьях Алматы. Свежий воздух и тишина.',
            price: 85000, rentType: 'DAILY', propertyType: 'Дом', country: 'Казахстан', city: 'Алматы', district: 'Бостандыкский',
            amenities: ['Парковка', 'Wi-Fi', 'Кухня', 'Бассейн'],
            imageUrls: [
                'https://images.unsplash.com/photo-1518780664697-55e3ad937233?w=800&q=70',
                'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800&q=70'
            ]
        }
    ];

    console.log('Скачиваю фотографии...');

    for (let i = 0; i < propertySeeds.length; i++) {
        const p = propertySeeds[i];
        const savedPaths = [];

        for (let j = 0; j < p.imageUrls.length; j++) {
            const filename = `seed-${i}-${j}.jpg`;
            try {
                const localPath = await downloadImage(p.imageUrls[j], filename);
                savedPaths.push(localPath);
            } catch (err) { console.error(`Ошибка при скачивании: ${err.message}`); }
        }

        await prisma.property.create({
            data: {
                title: p.title,
                description: p.description,
                price: p.price,
                rentType: p.rentType,
                propertyType: p.propertyType,
                country: p.country,
                city: p.city,
                district: p.district,
                amenities: p.amenities,
                authorId: user.id,
                images: savedPaths
            }
        });
    }

    console.log('База наполнена оптимизированными локальными фото!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
