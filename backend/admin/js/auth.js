/**
 * 北岛 AI 姿态矫正器 - 认证管理
 */

class Auth {
    constructor() {
        this.user = null;
    }

    /**
     * 检查是否已登录
     */
    isLoggedIn() {
        return !!localStorage.getItem('access_token');
    }

    /**
     * 登录
     */
    async login(phone, password) {
        try {
            const result = await api.adminLogin(phone, password);
            if (result.code === 0) {
                return { success: true };
            }
            return { success: false, message: result.message || '登录失败' };
        } catch (error) {
            return { success: false, message: error.message };
        }
    }

    /**
     * 登出
     */
    logout() {
        api.clearToken();
        this.user = null;
        window.location.href = '/admin/';
    }

    /**
     * 获取当前用户信息
     */
    async fetchCurrentUser() {
        try {
            const result = await api.getCurrentUser();
            if (result.code === 0) {
                this.user = result.data;
                return this.user;
            }
        } catch (error) {
            console.error('获取用户信息失败:', error);
        }
        return null;
    }

    /**
     * 要求登录 (用于页面保护)
     */
    async requireAuth() {
        if (!this.isLoggedIn()) {
            window.location.href = '/admin/';
            return false;
        }

        const user = await this.fetchCurrentUser();
        if (!user) {
            this.logout();
            return false;
        }

        if (!user.is_admin) {
            Toast.show('需要管理员权限', 'error');
            this.logout();
            return false;
        }

        return true;
    }
}

// 全局认证实例
const auth = new Auth();
