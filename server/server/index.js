const express = require('express');
require('dns').setDefaultResultOrder('ipv4first');
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const nodemailer = require('nodemailer');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const prisma = new PrismaClient();
const app = express();

app.use(cors());
app.use(express.json());
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    next();
});
// Делаем папку uploads публичной с правильными заголовками для Flutter Web
app.use('/uploads', (req, res, next) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    next();
}, express.static(path.join(__dirname, 'uploads')));

// Обслуживание веб-админки
app.use('/admin', express.static(path.join(__dirname, '../../admin-web')));

const JWT_SECRET = process.env.JWT_SECRET || 'fallback-secret';

// Создаем папку для загрузок, если её нет
if (!fs.existsSync('uploads')) {
    fs.mkdirSync('uploads');
}

// Настройка хранения файлов
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/');
    },
    filename: (req, file, cb) => {
        const safeName = file.originalname.replace(/[^a-z0-9.]/gi, '_').toLowerCase();
        cb(null, Date.now() + '-' + safeName);
    },
});
const upload = multer({ storage });

// Настройка почты
const transporter = nodemailer.createTransport({
    host: process.env.EMAIL_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.EMAIL_PORT) || 587,
    secure: false, // true for 465, false for other ports
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
    },
});

// Проверка соединения с почтой при запуске
transporter.verify((error, success) => {
    if (error) {
        console.log('Ошибка почты:', error);
    } else {
        console.log('Сервер готов к рассылке писем');
    }
});

// Middleware для проверки токена и обновления lastSeen
const authenticate = async (req, res, next) => {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ message: 'Не авторизован' });
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.userId = decoded.userId;

        // Проверяем, не забанен ли пользователь
        const user = await prisma.user.findUnique({
            where: { id: req.userId },
            select: { isBanned: true }
        });

        if (!user || user.isBanned) {
            return res.status(403).json({ message: 'Доступ заблокирован или пользователь удален' });
        }

        // Обновляем время последнего визита (фоново)
        prisma.user.update({
            where: { id: req.userId },
            data: { lastSeen: new Date() }
        }).catch(e => console.error('Error updating lastSeen:', e));

        next();
    } catch (e) {
        res.status(401).json({ message: 'Неверный токен' });
    }
};

// --- УВЕДОМЛЕНИЯ И СИСТЕМНЫЕ СООБЩЕНИЯ ---
const SYSTEM_USER_ID = 99999;

async function initSystemUser() {
    try {
        const systemUser = await prisma.user.findUnique({ where: { id: SYSTEM_USER_ID } });
        if (!systemUser) {
            await prisma.user.create({
                data: {
                    id: SYSTEM_USER_ID,
                    email: 'system@staynest.kz',
                    name: 'StayNest Support',
                    password: await bcrypt.hash('SYSTEM_PROTECTED_' + Math.random(), 10),
                    phone: 'SYSTEM',
                    isVerified: true
                }
            });
            console.log('Системный пользователь создан');
        }
    } catch (e) {
        console.error('Ошибка при создании системного пользователя:', e);
    }
}
initSystemUser();

async function createNotification(userId, content, type = 'SYSTEM') {
    try {
        // Создаем запись в уведомлениях
        await prisma.notification.create({
            data: { userId, content, type }
        });

        // Отправляем как системное сообщение
        await prisma.message.create({
            data: {
                content: content,
                senderId: SYSTEM_USER_ID,
                receiverId: userId,
            }
        });
    } catch (e) {
        console.error('Failed to create notification/system message:', e);
    }
}

// --- ПРОФИЛЬ ---

app.get('/api/profile', authenticate, async (req, res) => {
    try {
        const user = await prisma.user.findUnique({
            where: { id: req.userId },
            select: { id: true, email: true, name: true, phone: true, avatar: true, lastSeen: true }
        });
        res.json(user);
    } catch (e) {
        res.status(500).json({ message: 'Ошибка получения профиля' });
    }
});

app.put('/api/profile', authenticate, upload.single('avatar'), async (req, res) => {
    try {
        const { name, phone } = req.body;
        const updateData = {};
        if (name) updateData.name = name;
        if (phone) updateData.phone = phone;
        if (req.file) {
            updateData.avatar = `/uploads/${req.file.filename}`;
        }
        const user = await prisma.user.update({
            where: { id: req.userId },
            data: updateData
        });
        res.json(user);
    } catch (e) {
        res.status(500).json({ message: 'Ошибка обновления профиля' });
    }
});

app.put('/api/profile/change-password', authenticate, async (req, res) => {
    try {
        const { oldPassword, newPassword } = req.body;
        const user = await prisma.user.findUnique({ where: { id: req.userId } });
        const isMatch = await bcrypt.compare(oldPassword, user.password);
        if (!isMatch) return res.status(400).json({ message: 'Старый пароль неверен' });

        const hashedPassword = await bcrypt.hash(newPassword, 10);
        await prisma.user.update({
            where: { id: req.userId },
            data: { password: hashedPassword }
        });
        res.json({ message: 'Пароль успешно изменен' });
    } catch (e) {
        res.status(500).json({ message: 'Ошибка при смене пароля' });
    }
});

// --- АВТОРИЗАЦИЯ ---

app.post('/api/auth/register', async (req, res) => {
    try {
        const { email, password, name, phone } = req.body;
        if (!phone) return res.status(400).json({ message: 'Номер телефона обязателен' });

        const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
        const hashedPassword = await bcrypt.hash(password, 10);
        const user = await prisma.user.create({
            data: { email, password: hashedPassword, name, phone, verificationCode },
        });
        await transporter.sendMail({
            from: process.env.EMAIL_USER,
            to: email,
            subject: 'Код подтверждения StayNest',
            text: `Ваш код: ${verificationCode}`,
        });
        res.status(201).json({ message: 'Код отправлен', email: user.email });
    } catch (e) {
        console.error(e);
        res.status(500).json({ message: 'Ошибка регистрации' });
    }
});

app.post('/api/auth/verify-email', async (req, res) => {
    const { email, code } = req.body;
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || user.verificationCode !== code) return res.status(400).json({ message: 'Неверный код' });
    await prisma.user.update({ where: { email }, data: { isVerified: true, verificationCode: null } });
    const token = jwt.sign({ userId: user.id }, JWT_SECRET);
    res.json({ token, user: { id: user.id, email: user.email, name: user.name, phone: user.phone, avatar: user.avatar } });
});

app.post('/api/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        console.log(`Login attempt for ${email}`);
        const user = await prisma.user.findUnique({ where: { email } });
        if (!user) {
            console.log(`User not found: ${email}`);
            return res.status(400).json({ message: 'Ошибка входа' });
        }
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            console.log(`Password mismatch for ${email}`);
            return res.status(400).json({ message: 'Ошибка входа' });
        }
        if (user.isBanned) {
            console.log(`User is banned: ${email}`);
            return res.status(403).json({ message: 'Ваш аккаунт заблокирован' });
        }
        if (!user.isVerified) {
            console.log(`User not verified: ${email}`);
            return res.status(403).json({ message: 'Пожалуйста, подтвердите вашу почту' });
        }
        const token = jwt.sign({ userId: user.id, role: user.role }, JWT_SECRET);
        console.log(`Login successful for ${email}`);
        res.json({ token, user: { id: user.id, email: user.email, name: user.name, phone: user.phone, avatar: user.avatar, role: user.role } });
    } catch (e) {
        console.error('Login error:', e);
        res.status(500).json({ message: 'Внутренняя ошибка сервера' });
    }
});

// Забыли пароль - отправка кода
app.post('/api/auth/forgot-password', async (req, res) => {
    try {
        const { email } = req.body;
        const user = await prisma.user.findUnique({ where: { email } });

        if (!user) {
            return res.status(404).json({ message: 'Пользователь с таким email не найден' });
        }

        const resetCode = Math.floor(100000 + Math.random() * 900000).toString();

        await prisma.user.update({
            where: { email },
            data: { verificationCode: resetCode }
        });

        await transporter.sendMail({
            from: process.env.EMAIL_USER,
            to: email,
            subject: 'Код для сброса пароля StayNest',
            text: `Ваш код для сброса пароля: ${resetCode}`,
        });

        res.json({ message: 'Код отправлен на email' });
    } catch (e) {
        console.error('Forgot password error:', e);
        res.status(500).json({ message: 'Ошибка отправки кода' });
    }
});

// Сброс пароля с кодом
app.post('/api/auth/reset-password', async (req, res) => {
    try {
        const { email, code, newPassword } = req.body;
        const user = await prisma.user.findUnique({ where: { email } });

        if (!user || user.verificationCode !== code) {
            return res.status(400).json({ message: 'Неверный код' });
        }

        const hashedPassword = await bcrypt.hash(newPassword, 10);
        await prisma.user.update({
            where: { email },
            data: {
                password: hashedPassword,
                verificationCode: null
            }
        });

        res.json({ message: 'Пароль успешно изменен' });
    } catch (e) {
        console.error('Reset password error:', e);
        res.status(500).json({ message: 'Ошибка сброса пароля' });
    }
});


// --- СООБЩЕНИЯ ---

// Отправить сообщение
app.post('/api/messages', authenticate, async (req, res) => {
    try {
        const { receiverId, content, propertyId } = req.body;
        const message = await prisma.message.create({
            data: {
                content,
                senderId: req.userId,
                receiverId: parseInt(receiverId),
                propertyId: propertyId ? parseInt(propertyId) : null
            },
            include: {
                sender: { select: { name: true, avatar: true } },
                receiver: { select: { name: true, avatar: true } }
            }
        });
        // Уведомление о новом сообщении
        await createNotification(receiverId, `Новое сообщение от ${message.sender.name}`, 'MESSAGE');
        res.status(201).json(message);
    } catch (e) {
        res.status(500).json({ message: 'Ошибка при отправке сообщения' });
    }
});

// Получить список чатов пользователя
app.get('/api/messages/chats', authenticate, async (req, res) => {
    try {
        const userId = req.userId;
        // Находим всех пользователей, с которыми была переписка
        const messages = await prisma.message.findMany({
            where: { OR: [{ senderId: userId }, { receiverId: userId }] },
            include: {
                sender: { select: { id: true, name: true, phone: true, avatar: true, lastSeen: true } },
                receiver: { select: { id: true, name: true, phone: true, avatar: true, lastSeen: true } },
                property: { select: { title: true } }
            },
            orderBy: { createdAt: 'desc' }
        });

        // Группируем по собеседнику
        const chatsMap = new Map();
        messages.forEach(msg => {
            const otherUser = msg.senderId === userId ? msg.receiver : msg.sender;
            if (!chatsMap.has(otherUser.id)) {
                chatsMap.set(otherUser.id, {
                    user: otherUser,
                    lastMessage: msg.content,
                    createdAt: msg.createdAt,
                    property: msg.property,
                    unreadCount: (msg.receiverId === userId && !msg.isRead) ? 1 : 0
                });
            } else if (msg.receiverId === userId && !msg.isRead) {
                chatsMap.get(otherUser.id).unreadCount++;
            }
        });

        res.json(Array.from(chatsMap.values()));
    } catch (e) {
        res.status(500).json({ message: 'Ошибка при получении чатов' });
    }
});

// Получить сообщения с конкретным пользователем
app.get('/api/messages/:otherUserId', authenticate, async (req, res) => {
    try {
        const userId = req.userId;
        const otherUserId = parseInt(req.params.otherUserId);

        // Помечаем сообщения как прочитанные
        await prisma.message.updateMany({
            where: { senderId: otherUserId, receiverId: userId, isRead: false },
            data: { isRead: true }
        });

        const messages = await prisma.message.findMany({
            where: {
                OR: [
                    { senderId: userId, receiverId: otherUserId },
                    { senderId: otherUserId, receiverId: userId }
                ]
            },
            include: {
                sender: { select: { id: true, name: true, avatar: true } },
                receiver: { select: { id: true, name: true, avatar: true } }
            },
            orderBy: { createdAt: 'asc' }
        });
        res.json(messages);
    } catch (e) {
    }
});

// --- БРОНИРОВАНИЕ ---

app.post('/api/bookings', authenticate, async (req, res) => {
    try {
        const { propertyId, startDate, endDate, totalPrice } = req.body;
        const property = await prisma.property.findUnique({ where: { id: parseInt(propertyId) } });

        const booking = await prisma.booking.create({
            data: {
                propertyId: parseInt(propertyId),
                renterId: req.userId,
                startDate: new Date(startDate),
                endDate: new Date(endDate),
                totalPrice: parseFloat(totalPrice),
                status: 'PENDING'
            },
            include: { property: true, renter: true }
        });

        // Уведомление владельцу
        await createNotification(property.authorId, `Новое бронирование на "${property.title}"`, 'BOOKING');
        res.status(201).json(booking);
    } catch (e) {
        res.status(500).json({ message: 'Ошибка бронирования' });
    }
});

app.get('/api/properties/:id/bookings', async (req, res) => {
    const bookings = await prisma.booking.findMany({
        where: {
            propertyId: parseInt(req.params.id),
            status: { in: ['CONFIRMED', 'PENDING', 'AWAITING_PAYMENT'] }
        }
    });
    res.json(bookings);
});

app.get('/api/bookings/my', authenticate, async (req, res) => {
    const bookings = await prisma.booking.findMany({
        where: { renterId: req.userId },
        include: { property: { include: { author: true } } },
        orderBy: { createdAt: 'desc' }
    });
    res.json(bookings);
});

app.get('/api/bookings/owner', authenticate, async (req, res) => {
    const bookings = await prisma.booking.findMany({
        where: { property: { authorId: req.userId } },
        include: { property: true, renter: true },
        orderBy: { createdAt: 'desc' }
    });
    res.json(bookings);
});

app.put('/api/bookings/:id/status', authenticate, async (req, res) => {
    try {
        const { status } = req.body;
        const id = parseInt(req.params.id);

        const booking = await prisma.booking.findUnique({
            where: { id },
            include: { property: true }
        });

        if (!booking) return res.status(404).json({ message: 'Бронирование не найдено' });

        const isOwner = booking.property.authorId === req.userId;
        const isRenter = booking.renterId === req.userId;

        if (!isOwner && !isRenter) return res.status(403).json({ message: 'Нет доступа' });

        // Логика переходов
        if (isOwner) {
            // Хозяин может: Подтвердить запрос (-> Ожидание оплаты) или Отклонить (-> Отклонено)
            if (status === 'AWAITING_PAYMENT' || status === 'REJECTED' || status === 'CANCELLED') {
                // OK
            } else {
                return res.status(400).json({ message: 'Недопустимый статус для хозяина' });
            }
        }

        if (isRenter) {
            // Арендатор может: Оплатить (-> Подтверждено) или Отменить
            if (status === 'CONFIRMED') {
                if (booking.status !== 'AWAITING_PAYMENT') {
                    return res.status(400).json({ message: 'Оплата возможна только после одобрения хозяином' });
                }
            } else if (status === 'CANCELLED') {
                // OK
            } else {
                return res.status(400).json({ message: 'Недопустимый статус для арендатора' });
            }
        }

        const updatedBooking = await prisma.booking.update({
            where: { id },
            data: { status }
        });

        // Уведомление
        const targetUserId = isOwner ? booking.renterId : booking.property.authorId;
        let statusText = 'обновлено';
        if (status === 'AWAITING_PAYMENT') statusText = 'одобрено (ожидает оплаты)';
        if (status === 'REJECTED') statusText = 'отклонено';
        if (status === 'CONFIRMED') statusText = 'оплачено и подтверждено';
        if (status === 'CANCELLED') statusText = 'отменено';

        await createNotification(targetUserId, `Бронирование на "${booking.property.title}" ${statusText}`, 'BOOKING');

        res.json(updatedBooking);
    } catch (e) {
        console.error(e);
        res.status(500).json({ message: 'Ошибка обновления статуса' });
    }
});

// --- УВЕДОМЛЕНИЯ ---

app.get('/api/notifications', authenticate, async (req, res) => {
    const notifications = await prisma.notification.findMany({
        where: { userId: req.userId },
        orderBy: { createdAt: 'desc' }
    });
    res.json(notifications);
});

app.put('/api/notifications/read-all', authenticate, async (req, res) => {
    await prisma.notification.updateMany({
        where: { userId: req.userId, isRead: false },
        data: { isRead: true }
    });
    res.json({ message: 'OK' });
});

// --- ОБЪЯВЛЕНИЯ ---

// Создать объявление с загрузкой фото
app.post('/api/properties', authenticate, upload.any(), async (req, res) => {
    try {
        console.log('--- Property Creation Request ---');
        console.log('Body fields:', Object.keys(req.body));
        console.log('Files received:', req.files ? req.files.map(f => ({ fieldname: f.fieldname, originalname: f.originalname })) : 'None');

        const {
            title, description, price, rentType, propertyType,
            country, city, district, amenities,
            bedrooms, bathrooms, guests, area,
            latitude, longitude
        } = req.body;

        // Принимаем все файлы, пришедшие в запросе, как изображения
        const imageUrls = (req.files || [])
            .map(file => `/uploads/${file.filename}`);

        if (imageUrls.length === 0 && req.files && req.files.length > 0) {
            console.warn('Warning: Files were received but none matched the field "images". First fieldname was:', req.files[0].fieldname);
        }

        // Преобразование числовых значений с защитой от пустых строк и NaN
        const parsedPrice = parseFloat(price);
        const parsedArea = (area && area !== 'null' && area !== '') ? parseFloat(area) : null;
        const parsedBedrooms = parseInt(bedrooms);
        const parsedBathrooms = parseInt(bathrooms);
        const parsedGuests = parseInt(guests);
        const parsedAuthorId = parseInt(req.userId);

        // Проверка существования пользователя
        const userExists = await prisma.user.findUnique({ where: { id: parsedAuthorId } });
        if (!userExists) {
            return res.status(403).json({ message: 'Пользователь не найден в базе данных. Попробуйте перезайти в аккаунт.' });
        }

        let parsedAmenities = [];
        if (typeof amenities === 'string' && amenities.trim() !== '') {
            if (amenities.startsWith('[') && amenities.endsWith(']')) {
                try {
                    parsedAmenities = JSON.parse(amenities);
                } catch (e) {
                    parsedAmenities = amenities.split(',').filter(a => a.trim() !== '');
                }
            } else {
                parsedAmenities = amenities.split(',').filter(a => a.trim() !== '');
            }
        } else if (Array.isArray(amenities)) {
            parsedAmenities = amenities;
        }

        const initialStatus = 'APPROVED';

        const property = await prisma.property.create({
            data: {
                title: title || 'Без названия',
                description: description || '',
                price: isNaN(parsedPrice) ? 0.0 : parsedPrice,
                rentType: rentType || "DAILY",
                propertyType: propertyType || "Apartment",
                country: country || "Казахстан",
                city: city || "Алматы",
                district: district || "",
                bedrooms: isNaN(parseInt(bedrooms)) ? 1 : parseInt(bedrooms),
                bathrooms: isNaN(parseInt(bathrooms)) ? 1 : parseInt(bathrooms),
                guests: isNaN(parseInt(guests)) ? 2 : parseInt(guests),
                area: parsedArea,
                amenities: parsedAmenities,
                images: imageUrls,
                latitude: latitude ? parseFloat(latitude) : null,
                longitude: longitude ? parseFloat(longitude) : null,
                authorId: parsedAuthorId,
                status: initialStatus
            },
            include: {
                author: {
                    select: {
                        id: true,
                        name: true,
                        email: true,
                        phone: true
                    }
                }
            }
        });
        res.status(201).json(property);
    } catch (e) {
        console.error(e);
        res.status(500).json({ message: 'Ошибка при создании' });
    }
});

app.get('/api/properties', async (req, res) => {
    try {
        const { minPrice, maxPrice, type, amenities, sort, status } = req.query;

        const where = {
            // Показываем только одобренные
            status: 'APPROVED',
            // И только от НЕ забаненных авторов
            author: {
                isBanned: false
            }
        };

        if (minPrice) where.price = { ...where.price, gte: parseFloat(minPrice) };
        if (maxPrice) where.price = { ...where.price, lte: parseFloat(maxPrice) };
        if (type) where.rentType = type;
        if (amenities) {
            const amenitiesList = Array.isArray(amenities) ? amenities : [amenities];
            where.amenities = { hasEvery: amenitiesList };
        }

        let orderBy = { createdAt: 'desc' };
        if (sort === 'price_asc') orderBy = { price: 'asc' };
        if (sort === 'price_desc') orderBy = { price: 'desc' };

        const properties = await prisma.property.findMany({
            where,
            orderBy,
            include: { author: { select: { name: true, email: true, phone: true, id: true } } }
        });
        res.json(properties);
    } catch (e) {
        console.error(e);
        res.status(500).json({ message: 'Ошибка получения' });
    }
});

// Обновить объявление
app.put('/api/properties/:id', authenticate, upload.any(), async (req, res) => {
    try {
        const propertyId = parseInt(req.params.id);
        const {
            title, description, price, rentType, propertyType,
            country, city, district, amenities,
            bedrooms, bathrooms, guests, area,
            latitude, longitude,
            existingImages
        } = req.body;

        const property = await prisma.property.findUnique({ where: { id: propertyId } });
        if (!property) return res.status(404).json({ message: 'Не найдено' });
        if (property.authorId !== req.userId) return res.status(403).json({ message: 'Нет доступа' });

        // New images
        const newImageUrls = (req.files || []).map(file => `/uploads/${file.filename}`);

        // Existing images
        let currentImages = [];
        if (existingImages) {
            try {
                currentImages = JSON.parse(existingImages);
            } catch (e) {
                console.error('Error parsing existingImages', e);
            }
        }

        const finalImages = [...currentImages, ...newImageUrls];

        const parsedPrice = parseFloat(price);
        const parsedArea = (area && area !== 'null' && area !== '') ? parseFloat(area) : null;
        const parsedBedrooms = parseInt(bedrooms);
        const parsedBathrooms = parseInt(bathrooms);
        const parsedGuests = parseInt(guests);

        const updatedProperty = await prisma.property.update({
            where: { id: propertyId },
            data: {
                title: title,
                description: description,
                price: isNaN(parsedPrice) ? property.price : parsedPrice,
                rentType: rentType,
                propertyType: propertyType,
                country: country,
                city: city,
                district: district,
                bedrooms: isNaN(parsedBedrooms) ? property.bedrooms : parsedBedrooms,
                bathrooms: isNaN(parsedBathrooms) ? property.bathrooms : parsedBathrooms,
                guests: isNaN(parsedGuests) ? property.guests : parsedGuests,
                area: parsedArea,
                latitude: latitude ? parseFloat(latitude) : property.latitude,
                longitude: longitude ? parseFloat(longitude) : property.longitude,
                amenities: amenities ? amenities.split(',').filter(a => a.trim().length > 0) : [],
                images: finalImages
            }
        });

        res.json(updatedProperty);
    } catch (e) {
        console.error('Error updating property:', e);
        res.status(500).json({ message: 'Ошибка при обновлении' });
    }
});

app.delete('/api/properties/:id', authenticate, async (req, res) => {
    try {
        const propertyId = parseInt(req.params.id);
        const property = await prisma.property.findUnique({ where: { id: propertyId } });
        if (!property) return res.status(404).json({ message: 'Не найдено' });

        const user = await prisma.user.findUnique({ where: { id: req.userId } });

        if (property.authorId !== req.userId && user.role !== 'ADMIN') {
            return res.status(403).json({ message: 'Нельзя удалять чужие объявления' });
        }

        await prisma.propertyCalendar.deleteMany({ where: { propertyId } });
        await prisma.booking.deleteMany({ where: { propertyId } });
        await prisma.message.deleteMany({ where: { propertyId } });
        await prisma.favorite.deleteMany({ where: { propertyId } });
        await prisma.property.delete({ where: { id: propertyId } });
        res.json({ message: 'Удалено' });
    } catch (e) {
        console.error(e);
        res.status(500).json({ message: 'Ошибка при удалении' });
    }
});

// --- АДМИН ПАНЕЛЬ ---
// Middleware для проверки админа
const isAdmin = async (req, res, next) => {
    try {
        const user = await prisma.user.findUnique({ where: { id: req.userId } });
        if (user && user.role === 'ADMIN') {
            next();
        } else {
            res.status(403).json({ message: 'Требуются права администратора' });
        }
    } catch (e) {
        res.status(500).json({ message: 'Ошибка проверки прав' });
    }
};

// Расширенная статистика для админа
app.get('/api/admin/stats', authenticate, isAdmin, async (req, res) => {
    try {
        const usersCount = await prisma.user.count();
        const propsCount = await prisma.property.count();
        const bookings = await prisma.booking.findMany({
            where: { status: 'CONFIRMED' },
            select: { totalPrice: true, createdAt: true }
        });

        const totalRevenue = bookings.reduce((sum, b) => sum + b.totalPrice, 0);

        // Группировка броней по месяцам для графика
        const monthlyRevenue = {};
        bookings.forEach(b => {
            const month = b.createdAt.toLocaleString('ru-RU', { month: 'short' });
            monthlyRevenue[month] = (monthlyRevenue[month] || 0) + b.totalPrice;
        });

        res.json({
            usersCount,
            propsCount,
            totalRevenue,
            monthlyRevenue,
            activeReports: await prisma.report.count({ where: { status: 'PENDING' } })
        });
    } catch (e) {
        res.status(500).json({ message: 'Ошибка получения статистики' });
    }
});

// Получить все бронирования системы
app.get('/api/admin/bookings', authenticate, isAdmin, async (req, res) => {
    try {
        const bookings = await prisma.booking.findMany({
            orderBy: { createdAt: 'desc' },
            include: {
                property: { select: { title: true } },
                renter: { select: { name: true, email: true } }
            }
        });
        res.json(bookings);
    } catch (e) {
        res.status(500).json({ message: 'Ошибка получения бронирований' });
    }
});

// Получить список всех пользователей (для админа)
app.get('/api/admin/users', authenticate, isAdmin, async (req, res) => {
    try {
        const users = await prisma.user.findMany({
            orderBy: { createdAt: 'desc' },
            select: {
                id: true,
                email: true,
                name: true,
                phone: true,
                role: true,
                isBanned: true,
                createdAt: true,
                _count: {
                    select: { properties: true, bookings: true }
                }
            }
        });
        res.json(users);
    } catch (e) {
        res.status(500).json({ message: 'Ошибка получения пользователей' });
    }
});

// Забанить/Разбанить пользователя
app.post('/api/admin/users/:id/toggle-ban', authenticate, isAdmin, async (req, res) => {
    try {
        const userId = parseInt(req.params.id);
        if (userId === req.userId) {
            return res.status(400).json({ message: 'Нельзя забанить самого себя' });
        }

        const user = await prisma.user.findUnique({ where: { id: userId } });
        if (!user) return res.status(404).json({ message: 'Пользователь не найден' });

        const updatedUser = await prisma.user.update({
            where: { id: userId },
            data: { isBanned: !user.isBanned }
        });

        res.json({ message: updatedUser.isBanned ? 'Пользователь заблокирован' : 'Пользователь разблокирован', isBanned: updatedUser.isBanned });
    } catch (e) {
        res.status(500).json({ message: 'Ошибка изменения статуса' });
    }
});

// Обновить данные пользователя (для админа)
app.put('/api/admin/users/:id', authenticate, isAdmin, async (req, res) => {
    try {
        const userId = parseInt(req.params.id);
        const { name, email, role } = req.body;

        if (!userId) return res.status(400).json({ message: 'Некорректный ID пользователя' });

        const updatedUser = await prisma.user.update({
            where: { id: userId },
            data: {
                name: name || undefined,
                email: email || undefined,
                role: role || undefined
            }
        });

        res.json(updatedUser);
    } catch (e) {
        console.error('Update user error:', e);
        if (e.code === 'P2002') return res.status(400).json({ message: 'Этот Email уже занят' });
        res.status(500).json({ message: 'Ошибка обновления пользователя' });
    }
});

// Удалить пользователя (для админа)
app.delete('/api/admin/users/:id', authenticate, isAdmin, async (req, res) => {
    try {
        const userId = parseInt(req.params.id);
        if (userId === req.userId) return res.status(400).json({ message: 'Нельзя удалить самого себя' });

        await prisma.favorite.deleteMany({ where: { userId } });
        await prisma.booking.deleteMany({ where: { renterId: userId } });
        await prisma.report.deleteMany({ where: { OR: [{ reporterId: userId }, { userId }] } });

        await prisma.user.delete({ where: { id: userId } });
        res.json({ message: 'Пользователь удален' });
    } catch (e) {
        console.error(e);
        res.status(500).json({ message: 'Ошибка при удалении' });
    }
});

// Получить все объявления (для админа)
app.get('/api/admin/properties', authenticate, isAdmin, async (req, res) => {
    try {
        const properties = await prisma.property.findMany({
            orderBy: { createdAt: 'desc' },
            include: {
                author: {
                    select: { name: true, email: true }
                },
                _count: {
                    select: { reports: true }
                }
            }
        });
        res.json(properties);
    } catch (e) {
        res.status(500).json({ message: 'Ошибка получения объявлений' });
    }
});

// Изменить статус объявления (APPROVED/REJECTED)
app.put('/api/admin/properties/:id/status', authenticate, isAdmin, async (req, res) => {
    try {
        const { status } = req.body; // APPROVED, REJECTED
        const id = parseInt(req.params.id);

        const property = await prisma.property.update({
            where: { id },
            data: { status }
        });
        res.json(property);
    } catch (e) {
        res.status(500).json({ message: 'Ошибка обновления статуса' });
    }
});

// Обновить данные объявления (для админа)
app.put('/api/admin/properties/:id', authenticate, isAdmin, async (req, res) => {
    try {
        const id = parseInt(req.params.id);
        const { title, price, description, status } = req.body;

        if (!id) return res.status(400).json({ message: 'Некорректный ID объявления' });

        const property = await prisma.property.update({
            where: { id },
            data: {
                title: title || undefined,
                price: price !== undefined ? parseFloat(price) : undefined,
                description: description || undefined,
                status: status || undefined
            }
        });

        console.log(`Property ${id} updated by admin`);
        res.json(property);
    } catch (e) {
        console.error('Update property error:', e);
        res.status(500).json({ message: 'Ошибка обновления объявления (серверная)' });
    }
});

// --- ЖАЛОБЫ ---

// Создать жалобу
app.post('/api/reports', authenticate, async (req, res) => {
    try {
        const { reason, details, propertyId, userId } = req.body;

        if (!propertyId && !userId) {
            return res.status(400).json({ message: 'Не указан объект жалобы' });
        }

        const report = await prisma.report.create({
            data: {
                reason,
                details,
                reporterId: req.userId,
                propertyId: propertyId ? parseInt(propertyId) : null,
                userId: userId ? parseInt(userId) : null
            }
        });
        res.json(report);
    } catch (e) {
        console.error(e);
        res.status(500).json({ message: 'Ошибка создания жалобы' });
    }
});

// Получить все жалобы (для админа)
app.get('/api/admin/reports', authenticate, isAdmin, async (req, res) => {
    try {
        const reports = await prisma.report.findMany({
            orderBy: { createdAt: 'desc' },
            include: {
                reporter: { select: { name: true, email: true } },
                property: { select: { id: true, title: true } },
                user: { select: { id: true, name: true, email: true } }
            }
        });
        res.json(reports);
    } catch (e) {
        res.status(500).json({ message: 'Ошибка получения жалоб' });
    }
});

// Изменить статус жалобы
app.put('/api/admin/reports/:id/status', authenticate, isAdmin, async (req, res) => {
    try {
        const { status } = req.body; // RESOLVED
        const id = parseInt(req.params.id);

        const report = await prisma.report.update({
            where: { id },
            data: { status }
        });
        res.json(report);
    } catch (e) {
        res.status(500).json({ message: 'Ошибка обновления' });
    }
});

// --- ЛОКАЦИИ ---
const locationsData = {
    "Казахстан": {
        "Алматы": ["Алмалинский", "Ауэзовский", "Бостандыкский", "Жетысуский", "Медеуский", "Наурызбайский", "Турксибский", "Алатауский"],
        "Астана": ["Алматы", "Байконур", "Есиль", "Нура", "Сарыарка"],
        "Шымкент": ["Абайский", "Аль-Фарабийский", "Енбекшинский", "Каратауский", "Туранский"],
        "Караганда": ["Район им. Казыбек би", "Октябрьский район"],
        "Актобе": ["Район Астана", "Район Алматы"],
        "Тараз": [],
        "Павлодар": [],
        "Усть-Каменогорск": [],
        "Семей": [],
        "Атырау": [],
        "Костанай": [],
        "Кызылорда": [],
        "Уральск": [],
        "Петропавловск": [],
        "Актау": [],
        "Темиртау": [],
        "Туркестан": [],
        "Кокшетау": [],
        "Талдыкорган": [],
        "Экибастуз": [],
        "Рудный": []
    },
    "Россия": {
        "Москва": ["Центральный", "Северный", "Северо-Восточный", "Восточный", "Юго-Восточный", "Южный", "Юго-Западный", "Западный", "Северо-Западный", "Зеленоградский"],
        "Санкт-Петербург": ["Адмиралтейский", "Василеостровский", "Выборгский", "Калининский", "Кировский", "Колпинский", "Красногвардейский", "Красносельский", "Кронштадтский", "Курортный", "Московский", "Невский", "Петроградский", "Петродворцовый", "Приморский", "Пушкинский", "Фрунзенский", "Центральный"],
        "Новосибирск": [], "Екатеринбург": [], "Казань": []
    },
    "Турция": { "Стамбул": [], "Анталья": [], "Анкара": [], "Измир": [] },
    "ОАЭ": { "Дубай": [], "Абу-Даби": [], "Шарджа": [] },
    "США": { "Нью-Йорк": [], "Лос-Анджелес": [], "Майами": [] },
    "Таиланд": { "Пхукет": [], "Паттайя": [], "Самуи": [], "Бангкок": [] },
    "Грузия": { "Тбилиси": [], "Батуми": [] },
    "Узбекистан": { "Ташкент": [], "Самарканд": [], "Бухара": [] },
    "Кыргызстан": { "Бишкек": [], "Ош": [] }
};

app.get('/api/locations/countries', (req, res) => {
    res.json(Object.keys(locationsData));
});

app.get('/api/locations/cities', (req, res) => {
    const { country } = req.query;
    if (locationsData[country]) {
        res.json(Object.keys(locationsData[country]));
    } else {
        res.json([]);
    }
});

app.get('/api/locations/districts', (req, res) => {
    const { country, city } = req.query;
    if (locationsData[country] && locationsData[country][city]) {
        res.json(locationsData[country][city]);
    } else {
        res.json([]);
    }
});

// --- ИЗБРАННОЕ ---

// Получить список ID избранных объявлений текущего пользователя
app.get('/api/favorites', authenticate, async (req, res) => {
    try {
        const favorites = await prisma.favorite.findMany({
            where: { userId: req.userId },
            select: { propertyId: true }
        });
        res.json(favorites.map(f => f.propertyId));
    } catch (e) {
        console.error(e);
        res.status(500).json({ message: 'Ошибка получения избранного' });
    }
});

// Добавить/удалить из избранного
app.post('/api/favorites/toggle', authenticate, async (req, res) => {
    try {
        const { propertyId } = req.body;
        const userId = req.userId;

        const existing = await prisma.favorite.findUnique({
            where: {
                userId_propertyId: { userId, propertyId: parseInt(propertyId) }
            }
        });

        if (existing) {
            await prisma.favorite.delete({
                where: { id: existing.id }
            });
            res.json({ isFavorite: false });
        } else {
            await prisma.favorite.create({
                data: { userId, propertyId: parseInt(propertyId) }
            });
            res.json({ isFavorite: true });
        }
    } catch (e) {
        console.error(e);
        res.status(500).json({ message: 'Ошибка при изменении избранного' });
    }
});

// Получить объявления со скидками (будущие даты, цена ниже базовой)
app.get('/api/properties/discounts', async (req, res) => {
    try {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);

        // Получаем все календарные записи на будущее с установленной ценой
        const calendarEntries = await prisma.propertyCalendar.findMany({
            where: {
                date: { gte: today },
                price: { not: null },
                isBlocked: false,
            },
            include: {
                property: {
                    include: {
                        author: { select: { id: true, name: true, avatar: true } }
                    }
                }
            },
            orderBy: { date: 'asc' }
        });

        // Фильтруем те, где цена ниже базовой
        const discounted = calendarEntries.filter(entry => entry.price < entry.property.price);

        // Просто группируем по propertyId и цене, собирая все даты
        const resultMap = new Map();
        discounted.forEach(entry => {
            const key = `${entry.propertyId}_${entry.price}`;
            if (!resultMap.has(key)) {
                resultMap.set(key, {
                    property: entry.property,
                    price: entry.price,
                    dates: []
                });
            }
            resultMap.get(key).dates.push(entry.date);
        });

        const results = Array.from(resultMap.values()).sort((a, b) => a.price - b.price);
        res.json(results);
    } catch (e) {
        console.error(e);
        res.status(500).json({ message: 'Ошибка получения скидок' });
    }
});

// --- КАЛЕНДАРЬ ---

app.get('/api/properties/:id/calendar', async (req, res) => {
    try {
        const calendar = await prisma.propertyCalendar.findMany({
            where: { propertyId: parseInt(req.params.id) }
        });
        res.json(calendar);
    } catch (e) {
        res.status(500).json({ message: 'Ошибка получения календаря' });
    }
});

app.post('/api/properties/:id/calendar', authenticate, async (req, res) => {
    try {
        const propertyId = parseInt(req.params.id);
        const { date, price, isBlocked } = req.body;

        const property = await prisma.property.findUnique({ where: { id: propertyId } });
        if (property.authorId !== req.userId) return res.status(403).json({ message: 'Нет доступа' });

        const entry = await prisma.propertyCalendar.upsert({
            where: { propertyId_date: { propertyId, date: new Date(date) } },
            update: {
                price: price !== undefined ? (price === null ? null : parseFloat(price)) : undefined,
                isBlocked
            },
            create: {
                propertyId,
                date: new Date(date),
                price: price !== undefined ? (price === null ? null : parseFloat(price)) : null,
                isBlocked: isBlocked || false
            }
        });
        res.json(entry);
    } catch (e) {
        res.status(500).json({ message: 'Ошибка сохранения календаря' });
    }
});

// --- ОТЗЫВЫ ---

// Создать отзыв
app.post('/api/reviews', authenticate, async (req, res) => {
    try {
        const { propertyId, rating, comment } = req.body;

        // Проверка: оставлял ли уже отзыв?
        const existingReview = await prisma.review.findUnique({
            where: {
                userId_propertyId: {
                    userId: req.userId,
                    propertyId: parseInt(propertyId)
                }
            }
        });

        if (existingReview) {
            return res.status(400).json({ message: 'Вы уже оставили отзыв на это объявление' });
        }

        const review = await prisma.review.create({
            data: {
                rating: parseInt(rating),
                comment,
                userId: req.userId,
                propertyId: parseInt(propertyId)
            },
            include: { user: { select: { name: true, avatar: true } } }
        });
        res.json(review);
    } catch (e) {
        console.error(e);
        res.status(500).json({ message: 'Ошибка создания отзыва' });
    }
});

// Получить отзывы для объявления
app.get('/api/properties/:id/reviews', async (req, res) => {
    try {
        const reviews = await prisma.review.findMany({
            where: { propertyId: parseInt(req.params.id) },
            include: {
                user: {
                    select: { id: true, name: true, avatar: true }
                }
            },
            orderBy: { createdAt: 'desc' }
        });
        res.json(reviews);
    } catch (e) {
        console.error('Error fetching reviews:', e);
        res.status(500).json({ message: 'Ошибка получения отзывов' });
    }
});

// Создать отзыв
app.post('/api/properties/:id/reviews', authenticate, upload.array('photos', 5), async (req, res) => {
    try {
        const propertyId = parseInt(req.params.id);
        const { rating, comment } = req.body;

        // Проверка: пользователь должен был забронировать это жилье
        const hasBooking = await prisma.booking.findFirst({
            where: {
                propertyId,
                renterId: req.userId,
                status: 'CONFIRMED'
            }
        });

        if (!hasBooking) {
            return res.status(403).json({ message: 'Вы можете оставить отзыв только после подтвержденного бронирования' });
        }

        // Проверка: отзыв уже существует?
        const existing = await prisma.review.findUnique({
            where: {
                userId_propertyId: {
                    userId: req.userId,
                    propertyId
                }
            }
        });

        if (existing) {
            return res.status(400).json({ message: 'Вы уже оставили отзыв на это жилье' });
        }

        const photoUrls = (req.files || []).map(file => `/uploads/${file.filename}`);

        const review = await prisma.review.create({
            data: {
                rating: parseInt(rating),
                comment,
                photos: photoUrls,
                userId: req.userId,
                propertyId
            },
            include: {
                user: {
                    select: { id: true, name: true, avatar: true }
                }
            }
        });

        res.json(review);
    } catch (e) {
        console.error('Error creating review:', e);
        res.status(500).json({ message: 'Ошибка создания отзыва' });
    }
});

// Получить средний рейтинг объявления
app.get('/api/properties/:id/rating', async (req, res) => {
    try {
        const reviews = await prisma.review.findMany({
            where: { propertyId: parseInt(req.params.id) },
            select: { rating: true }
        });

        if (reviews.length === 0) {
            return res.json({ averageRating: 0, reviewCount: 0 });
        }

        const sum = reviews.reduce((acc, r) => acc + r.rating, 0);
        const average = sum / reviews.length;

        res.json({
            averageRating: Math.round(average * 10) / 10,
            reviewCount: reviews.length
        });
    } catch (e) {
        console.error('Error calculating rating:', e);
        res.status(500).json({ message: 'Ошибка расчета рейтинга' });
    }
});


const PORT = process.env.PORT || 8001;
app.listen(PORT, () => {
    console.log(`Сервер запущен на порту ${PORT}`);
});
