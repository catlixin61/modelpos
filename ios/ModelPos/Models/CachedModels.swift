// SwiftData 本地缓存模型

import Foundation
import SwiftData

/// 缓存的姿态日志
@Model
final class CachedPostureLog {
    var deviceId: Int
    var postureType: String
    var duration: Int
    var isCorrect: Bool
    var recordedAt: Date
    var isSynced: Bool  // 是否已同步到服务器
    var createdAt: Date
    
    init(
        deviceId: Int,
        postureType: String,
        duration: Int,
        isCorrect: Bool,
        recordedAt: Date
    ) {
        self.deviceId = deviceId
        self.postureType = postureType
        self.duration = duration
        self.isCorrect = isCorrect
        self.recordedAt = recordedAt
        self.isSynced = false
        self.createdAt = Date()
    }
    
    /// 转换为 API 请求模型
    func toCreateRequest() -> PostureLogCreate {
        return PostureLogCreate(
            deviceId: deviceId,
            postureType: postureType,
            duration: duration,
            isCorrect: isCorrect,
            recordedAt: recordedAt
        )
    }
}

/// 缓存的设备信息
@Model
final class CachedDevice {
    @Attribute(.unique) var id: Int
    var macAddress: String
    var deviceType: String
    var name: String
    var firmwareVersion: String
    var pairedDeviceMac: String?
    var lastSyncAt: Date
    
    init(from device: DeviceInfo) {
        self.id = device.id
        self.macAddress = device.macAddress
        self.deviceType = device.deviceType.rawValue
        self.name = device.name
        self.firmwareVersion = device.firmwareVersion
        self.pairedDeviceMac = device.pairedDeviceMac
        self.lastSyncAt = Date()
    }
    
    /// 获取设备类型
    var type: DeviceType {
        return DeviceType(rawValue: deviceType) ?? .detector
    }
}
