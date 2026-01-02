/**
 * 北岛 AI 姿态矫正器 - API 封装
 */

const API_BASE = '/api/v1';

class Api {
    constructor() {
        this.token = localStorage.getItem('access_token');
    }

    /**
     * 设置令牌
     */
    setToken(token) {
        this.token = token;
        localStorage.setItem('access_token', token);
    }

    /**
     * 清除令牌
     */
    clearToken() {
        this.token = null;
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
    }

    /**
     * 发起请求
     */
    async request(method, endpoint, data = null) {
        const headers = {
            'Content-Type': 'application/json',
        };

        if (this.token) {
            headers['Authorization'] = `Bearer ${this.token}`;
        }

        const options = {
            method,
            headers,
        };

        if (data && (method === 'POST' || method === 'PUT' || method === 'PATCH')) {
            options.body = JSON.stringify(data);
        }

        try {
            const response = await fetch(`${API_BASE}${endpoint}`, options);
            const result = await response.json();

            if (!response.ok) {
                throw new Error(result.detail || '请求失败');
            }

            return result;
        } catch (error) {
            // 令牌过期，尝试刷新
            if (error.message.includes('401') || error.message.includes('无效')) {
                const refreshed = await this.tryRefreshToken();
                if (refreshed) {
                    return this.request(method, endpoint, data);
                }
                // 刷新失败，跳转登录
                window.location.href = '/admin/';
            }
            throw error;
        }
    }

    /**
     * 尝试刷新令牌
     */
    async tryRefreshToken() {
        const refreshToken = localStorage.getItem('refresh_token');
        if (!refreshToken) return false;

        try {
            const response = await fetch(`${API_BASE}/auth/refresh`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ refresh_token: refreshToken }),
            });

            if (!response.ok) return false;

            const result = await response.json();
            if (result.code === 0 && result.data) {
                this.setToken(result.data.access_token);
                localStorage.setItem('refresh_token', result.data.refresh_token);
                return true;
            }
        } catch {
            return false;
        }
        return false;
    }

    // ========== 认证 API ==========

    /**
     * 管理员登录
     */
    async adminLogin(phone, password) {
        const result = await this.request('POST', '/auth/admin/login', { phone, password });
        if (result.code === 0 && result.data) {
            this.setToken(result.data.access_token);
            localStorage.setItem('refresh_token', result.data.refresh_token);
        }
        return result;
    }

    /**
     * 获取当前用户
     */
    async getCurrentUser() {
        return this.request('GET', '/users/me');
    }

    // ========== 用户 API ==========

    /**
     * 获取用户列表
     */
    async getUsers(page = 1, pageSize = 20, search = null) {
        let url = `/users/?page=${page}&page_size=${pageSize}`;
        if (search) url += `&search=${encodeURIComponent(search)}`;
        return this.request('GET', url);
    }

    /**
     * 获取用户详情
     */
    async getUser(userId) {
        return this.request('GET', `/users/${userId}`);
    }

    /**
     * 更新用户
     */
    async updateUser(userId, data) {
        return this.request('PUT', `/users/${userId}`, data);
    }

    /**
     * 删除用户
     */
    async deleteUser(userId) {
        return this.request('DELETE', `/users/${userId}`);
    }

    // ========== 设备 API ==========

    /**
     * 获取设备列表
     */
    async getDevices(page = 1, pageSize = 20, deviceType = null, search = null) {
        let url = `/devices/?page=${page}&page_size=${pageSize}`;
        if (deviceType) url += `&device_type=${deviceType}`;
        if (search) url += `&search=${encodeURIComponent(search)}`;
        return this.request('GET', url);
    }

    /**
     * 获取设备详情
     */
    async getDevice(deviceId) {
        return this.request('GET', `/devices/${deviceId}`);
    }

    /**
     * 更新设备
     */
    async updateDevice(deviceId, data) {
        return this.request('PUT', `/devices/${deviceId}`, data);
    }

    /**
     * 删除设备
     */
    async deleteDevice(deviceId) {
        return this.request('DELETE', `/devices/${deviceId}`);
    }

    /**
     * 配对设备
     */
    async pairDevice(detectorId, feedbackerId) {
        return this.request('POST', `/devices/${detectorId}/pair?paired_device_id=${feedbackerId}`);
    }
}

// 全局 API 实例
const api = new Api();
