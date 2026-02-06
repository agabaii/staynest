const API_BASE = 'http://172.20.10.5:8001/api';
let token = localStorage.getItem('admin_token');

// Elements
const loginScreen = document.getElementById('login-screen');
const dashboardScreen = document.getElementById('dashboard-screen');
const loginForm = document.getElementById('login-form');
const loginError = document.getElementById('login-error');
const logoutBtn = document.getElementById('logout-btn');
const navItems = document.querySelectorAll('.nav-item');
const tabContents = document.querySelectorAll('.tab-content');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    if (token) {
        showDashboard();
    } else {
        showLogin();
    }
});

// Navigation
navItems.forEach(item => {
    item.addEventListener('click', (e) => {
        e.preventDefault();
        const tabId = item.getAttribute('data-tab');

        navItems.forEach(i => i.classList.remove('active'));
        item.classList.add('active');

        tabContents.forEach(tab => {
            tab.classList.remove('active');
            if (tab.id === `${tabId}-tab`) {
                tab.classList.add('active');
            }
        });

        loadTabData(tabId);
    });
});

async function loadTabData(tabId) {
    switch (tabId) {
        case 'stats': fetchStats(); break;
        case 'users': fetchUsers(); break;
        case 'properties': fetchProperties(); break;
        case 'bookings': fetchBookings(); break;
        case 'reports': fetchReports(); break;
    }
}

// Auth functions
loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;

    try {
        const res = await fetch(`${API_BASE}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password })
        });
        const data = await res.json();

        if (res.ok) {
            if (data.user.role !== 'ADMIN') {
                loginError.innerText = 'Доступ запрещен. Только для администраторов.';
                return;
            }
            token = data.token;
            localStorage.setItem('admin_token', token);
            document.getElementById('admin-name').innerText = data.user.name;
            showDashboard();
        } else {
            loginError.innerText = data.message || 'Ошибка входа';
        }
    } catch (err) {
        loginError.innerText = 'Ошибка соединения с сервером';
    }
});

logoutBtn.addEventListener('click', () => {
    localStorage.removeItem('admin_token');
    token = null;
    showLogin();
});

function showLogin() {
    loginScreen.classList.add('active');
    dashboardScreen.classList.remove('active');
}

function showDashboard() {
    loginScreen.classList.remove('active');
    dashboardScreen.classList.add('active');
    fetchStats();
}

// Data fetching
async function apiCall(endpoint, method = 'GET', body = null) {
    const options = {
        method,
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        }
    };
    if (body) options.body = JSON.stringify(body);

    const res = await fetch(`${API_BASE}${endpoint}`, options);
    if (res.status === 401) {
        logoutBtn.click();
        return null;
    }
    return res.json();
}

let revenueChart = null;

async function fetchStats() {
    const data = await apiCall('/admin/stats');
    if (!data) return;

    document.getElementById('stat-users-count').innerText = data.usersCount;
    document.getElementById('stat-props-count').innerText = data.propsCount;
    document.getElementById('stat-reports-count').innerText = data.activeReports;
    document.getElementById('stat-revenue').innerText = data.totalRevenue.toLocaleString() + ' ₸';

    // Update Chart
    const ctx = document.getElementById('revenueChart').getContext('2d');
    const labels = Object.keys(data.monthlyRevenue);
    const values = Object.values(data.monthlyRevenue);

    if (revenueChart) revenueChart.destroy();

    revenueChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Выручка (₸)',
                data: values,
                borderColor: '#5865f2',
                backgroundColor: 'rgba(88, 101, 242, 0.1)',
                borderWidth: 3,
                fill: true,
                tension: 0.4,
                pointRadius: 5,
                pointBackgroundColor: '#5865f2'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(255,255,255,0.05)' },
                    ticks: { color: '#a0a0a0' }
                },
                x: {
                    grid: { display: false },
                    ticks: { color: '#a0a0a0' }
                }
            }
        }
    });
}

async function fetchUsers() {
    const list = document.getElementById('users-list');
    list.innerHTML = '<tr><td colspan="6" style="text-align:center">Загрузка...</td></tr>';

    const users = await apiCall('/admin/users');
    if (!users) return;

    list.innerHTML = users.map(u => `
        <tr>
            <td>
                <div style="display:flex; align-items:center; gap:10px">
                    <div class="avatar" style="width:30px; height:30px; font-size:12px">${u.name[0]}</div>
                    <span>${u.name}</span>
                </div>
            </td>
            <td>${u.email}<br><small style="color:var(--text-dim)">${u.phone}</small></td>
            <td><span class="badge ${u.role === 'ADMIN' ? 'badge-admin' : ''}">${u.role}</span></td>
            <td>${u._count.properties} / ${u._count.bookings}</td>
            <td><span class="badge ${u.isBanned ? 'badge-banned' : 'badge-approved'}">${u.isBanned ? 'Забанен' : 'Активен'}</span></td>
            <td>
                ${u.role !== 'ADMIN' ? `
                    <button class="action-btn ${u.isBanned ? 'unban' : 'ban'}" onclick="toggleBan(${u.id})" title="${u.isBanned ? 'Разбанить' : 'Забанить'}">
                        <i class="fas ${u.isBanned ? 'fa-unlock' : 'fa-user-slash'}"></i>
                    </button>
                ` : ''}
            </td>
        </tr>
    `).join('');
}

async function fetchProperties() {
    const list = document.getElementById('props-list');
    list.innerHTML = '<tr><td colspan="6" style="text-align:center">Загрузка...</td></tr>';

    const props = await apiCall('/admin/properties');
    if (!props) return;

    list.innerHTML = props.map(p => `
        <tr>
            <td><strong style="display:block">${p.title}</strong><small style="color:var(--text-dim)">${p.city}, ${p.country}</small></td>
            <td>${p.author.name}</td>
            <td>${p.price.toLocaleString()}₸</td>
            <td>${p.propertyType}</td>
            <td><span class="badge badge-${p.status.toLowerCase()}">${p.status}</span></td>
            <td>
                <button class="action-btn approve" onclick="updatePropStatus(${p.id}, 'APPROVED')" title="Одобрить"><i class="fas fa-check"></i></button>
                <button class="action-btn reject" onclick="updatePropStatus(${p.id}, 'REJECTED')" title="Отклонить"><i class="fas fa-times"></i></button>
            </td>
        </tr>
    `).join('');
}

async function fetchBookings() {
    const list = document.getElementById('bookings-list');
    list.innerHTML = '<tr><td colspan="5" style="text-align:center">Загрузка...</td></tr>';

    const bookings = await apiCall('/admin/bookings');
    if (!bookings) return;

    list.innerHTML = bookings.map(b => `
        <tr>
            <td><strong>${b.property.title}</strong></td>
            <td>${b.renter.name}<br><small>${b.renter.email}</small></td>
            <td>${new Date(b.startDate).toLocaleDateString()} - ${new Date(b.endDate).toLocaleDateString()}</td>
            <td>${b.totalPrice.toLocaleString()} ₸</td>
            <td><span class="badge badge-${b.status.toLowerCase()}">${b.status}</span></td>
        </tr>
    `).join('');
}

async function fetchReports() {
    const list = document.getElementById('reports-list');
    list.innerHTML = '<tr><td colspan="6" style="text-align:center">Загрузка...</td></tr>';

    const reports = await apiCall('/admin/reports');
    if (!reports) return;

    list.innerHTML = reports.map(r => `
        <tr>
            <td><strong>${r.reason}</strong><br><small>${r.details || ''}</small></td>
            <td>${r.property ? 'Объект: ' + r.property.title : 'Пользователь: ' + r.user.name}</td>
            <td>${r.reporter.name}</td>
            <td>${new Date(r.createdAt).toLocaleDateString()}</td>
            <td><span class="badge ${r.status === 'RESOLVED' ? 'badge-approved' : 'badge-pending'}">${r.status}</span></td>
            <td>
                ${r.status !== 'RESOLVED' ? `<button class="action-btn approve" onclick="resolveReport(${r.id})" title="Решить"><i class="fas fa-check-double"></i></button>` : '<i class="fas fa-check" style="color:var(--success)"></i>'}
            </td>
        </tr>
    `).join('');
}

// Actions
window.toggleBan = async (id) => {
    await apiCall(`/admin/users/${id}/toggle-ban`, 'POST');
    fetchUsers();
}

window.updatePropStatus = async (id, status) => {
    await apiCall(`/admin/properties/${id}/status`, 'PUT', { status });
    fetchProperties();
}

window.resolveReport = async (id) => {
    await apiCall(`/admin/reports/${id}/status`, 'PUT', { status: 'RESOLVED' });
    fetchReports();
}
