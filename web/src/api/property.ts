// ==================== 通用 Property 接口 ====================

// 通用的 Property 响应类型
import apiClient from "@/api/client.ts";

export interface PropertyResponse<T> {
    id: string;
    name: string;
    value: T;
}

// 通用的获取 Property 方法
export const getProperty = async <T>(propertyId: string): Promise<T> => {
    const response = await apiClient.get<PropertyResponse<T>>(`/properties/${propertyId}`);
    return response.value;
};

// 通用的保存 Property 方法
export const saveProperty = async <T>(propertyId: string, name: string, value: T): Promise<void> => {
    await apiClient.put(`/properties/${propertyId}`, {
        name,
        value,
    });
};

// ==================== 通知渠道配置 ====================

const PROPERTY_ID_NOTIFICATION_CHANNELS = 'notification_channels';

// 通知渠道配置（id 是唯一渠道 ID，type 只表示渠道类型）
export interface NotificationChannel {
    id?: string;
    name?: string;
    type: 'dingtalk' | 'wecom' | 'feishu' | 'email' | 'webhook' | 'telegram'; // 渠道类型，作为唯一标识
    enabled: boolean; // 是否启用
    deviceIds?: string[]; // 适用模块；为空表示全部 SIM
    config: Record<string, any>; // JSON配置，根据type不同而不同
}

// 获取通知渠道列表
export const getNotificationChannels = async (): Promise<NotificationChannel[]> => {
    const channels = await getProperty<NotificationChannel[]>(PROPERTY_ID_NOTIFICATION_CHANNELS);
    return channels || [];
};

// 保存通知渠道列表
export const saveNotificationChannels = async (channels: NotificationChannel[]): Promise<void> => {
    return saveProperty(PROPERTY_ID_NOTIFICATION_CHANNELS, '通知渠道配置', channels);
};

// 测试通知渠道（从数据库读取配置）
export const testNotificationChannel = async (channel: Pick<NotificationChannel, 'id' | 'type'>): Promise<{ message: string }> => {
    return await apiClient.post<{ message: string }>(`/notifications/${channel.type}/test`, null, {
        params: channel.id ? {channelId: channel.id} : undefined,
    });
};

export interface Version {
    version: string;
}

export const getVersion = () => {
    return apiClient.get<Version>('/version');
}
