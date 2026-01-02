/**
 * 北岛 AI 姿态矫正器 - 主程序
 */

// ========================================
// Toast 提示
// ========================================
class Toast {
    static container = null;

    static init() {
        if (!this.container) {
            this.container = document.createElement('div');
            this.container.className = 'toast-container';
            document.body.appendChild(this.container);
        }
    }

    static show(message, type = 'info', duration = 3000) {
        this.init();

        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.innerHTML = `
            <span>${message}</span>
            <button class="btn-icon" onclick="this.parentElement.remove()">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <line x1="18" y1="6" x2="6" y2="18"></line>
                    <line x1="6" y1="6" x2="18" y2="18"></line>
                </svg>
            </button>
        `;

        this.container.appendChild(toast);

        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateX(100%)';
            setTimeout(() => toast.remove(), 300);
        }, duration);
    }

    static success(message) { this.show(message, 'success'); }
    static error(message) { this.show(message, 'error'); }
    static warning(message) { this.show(message, 'warning'); }
    static info(message) { this.show(message, 'info'); }
}

// ========================================
// Modal 模态框
// ========================================
class Modal {
    static show(id) {
        const overlay = document.getElementById(id);
        if (overlay) {
            overlay.classList.add('active');
        }
    }

    static hide(id) {
        const overlay = document.getElementById(id);
        if (overlay) {
            overlay.classList.remove('active');
        }
    }

    static confirm(title, message, onConfirm) {
        const overlay = document.createElement('div');
        overlay.className = 'modal-overlay active';
        overlay.innerHTML = `
            <div class="modal">
                <div class="modal-header">
                    <h3 class="modal-title">${title}</h3>
                </div>
                <div class="modal-body">
                    <p>${message}</p>
                </div>
                <div class="modal-footer">
                    <button class="btn btn-secondary" onclick="this.closest('.modal-overlay').remove()">取消</button>
                    <button class="btn btn-danger" id="confirm-btn">确定</button>
                </div>
            </div>
        `;

        document.body.appendChild(overlay);

        overlay.querySelector('#confirm-btn').onclick = () => {
            overlay.remove();
            onConfirm();
        };
    }
}

// ========================================
// 格式化工具
// ========================================
const Format = {
    /**
     * 格式化日期时间
     */
    datetime(dateStr) {
        if (!dateStr) return '-';
        const date = new Date(dateStr);
        return date.toLocaleString('zh-CN', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
        });
    },

    /**
     * 格式化日期
     */
    date(dateStr) {
        if (!dateStr) return '-';
        const date = new Date(dateStr);
        return date.toLocaleDateString('zh-CN');
    },

    /**
     * 格式化手机号 (脱敏)
     */
    phone(phone) {
        if (!phone || phone.length !== 11) return phone;
        return phone.slice(0, 3) + '****' + phone.slice(7);
    },

    /**
     * 格式化设备类型
     */
    deviceType(type) {
        const types = {
            detector: '探测器',
            feedbacker: '反馈器',
        };
        return types[type] || type;
    },

    /**
     * 格式化时长 (秒 -> 时分秒)
     */
    duration(seconds) {
        if (!seconds) return '0秒';
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = seconds % 60;

        let result = '';
        if (h > 0) result += `${h}小时`;
        if (m > 0) result += `${m}分钟`;
        if (s > 0 || result === '') result += `${s}秒`;
        return result;
    },
};

// ========================================
// 侧边栏用户信息
// ========================================
async function initSidebar() {
    const userInfo = document.querySelector('.user-info');
    if (!userInfo || !auth.user) return;

    const avatar = auth.user.nickname ? auth.user.nickname[0].toUpperCase() : 'A';
    userInfo.innerHTML = `
        <div class="user-avatar">${avatar}</div>
        <div class="user-details">
            <div class="user-name">${auth.user.nickname}</div>
            <div class="user-role">管理员</div>
        </div>
        <button class="btn-icon" onclick="auth.logout()" title="退出登录">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path>
                <polyline points="16 17 21 12 16 7"></polyline>
                <line x1="21" y1="12" x2="9" y2="12"></line>
            </svg>
        </button>
    `;
}

// ========================================
// 高亮当前导航
// ========================================
function highlightActiveNav() {
    const path = window.location.pathname;
    const navItems = document.querySelectorAll('.nav-item');

    navItems.forEach(item => {
        item.classList.remove('active');
        const href = item.getAttribute('href');
        if (path.endsWith(href)) {
            item.classList.add('active');
        }
    });
}
