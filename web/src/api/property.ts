import apiClient from "@/api/client.ts";

export interface PropertyResponse<T> {
    id: string;
    name: string;
    value: T;
}

export const getProperty = async <T>(propertyId: string): Promise<T> => {
    const response = await apiClient.get<PropertyResponse<T>>(`/properties/${propertyId}`);
    return response.value;
};

export const saveProperty = async <T>(propertyId: string, name: string, value: T): Promise<void> => {
    await apiClient.put(`/properties/${propertyId}`, {name, value});
};

const PROPERTY_ID_NOTIFICATION_CHANNELS = 'notification_channels';
const PROPERTY_ID_STATUS_PUSH_CONFIG = 'status_push_config';
const PROPERTY_ID_CALL_NOTIFICATION_CONFIG = 'call_notification_config';

export interface NotificationChannel {
    id?: string;
    name?: string;
    type: 'dingtalk' | 'wecom' | 'feishu' | 'email' | 'webhook' | 'telegram';
    enabled: boolean;
    deviceIds?: string[];
    config: Record<string, any>;
}

export interface StatusPushConfig {
    enabled: boolean;
    times: string[];
    channelIds?: string[];
    includeSignal: boolean;
    includeNetwork: boolean;
    includeRuntime: boolean;
    includeSim: boolean;
}

export interface CallNotificationConfig {
    enabled: boolean;
    channelIds?: string[];
}

export const getNotificationChannels = async (): Promise<NotificationChannel[]> => {
    const channels = await getProperty<NotificationChannel[]>(PROPERTY_ID_NOTIFICATION_CHANNELS);
    return channels || [];
};

export const saveNotificationChannels = async (channels: NotificationChannel[]): Promise<void> => {
    return saveProperty(PROPERTY_ID_NOTIFICATION_CHANNELS, '通知渠道配置', channels);
};

export const testNotificationChannel = async (channel: Pick<NotificationChannel, 'id' | 'type'>): Promise<{ message: string }> => {
    return apiClient.post<{ message: string }>(`/notifications/${channel.type}/test`, null, {
        params: {channelId: channel.id},
    });
};

export const getStatusPushConfig = async (): Promise<StatusPushConfig> => {
    const config = await getProperty<StatusPushConfig>(PROPERTY_ID_STATUS_PUSH_CONFIG);
    return config || defaultStatusPushConfig();
};

export const saveStatusPushConfig = async (config: StatusPushConfig): Promise<void> => {
    return saveProperty(PROPERTY_ID_STATUS_PUSH_CONFIG, '设备状态推送配置', config);
};

export const testStatusPush = async (): Promise<{ message: string }> => {
    return apiClient.post<{ message: string }>('/status-push/test');
};

export const getCallNotificationConfig = async (): Promise<CallNotificationConfig> => {
    const config = await getProperty<CallNotificationConfig>(PROPERTY_ID_CALL_NOTIFICATION_CONFIG);
    return config || {enabled: false, channelIds: []};
};

export const saveCallNotificationConfig = async (config: CallNotificationConfig): Promise<void> => {
    return saveProperty(PROPERTY_ID_CALL_NOTIFICATION_CONFIG, '来电通知配置', config);
};

export const defaultStatusPushConfig = (): StatusPushConfig => ({
    enabled: false,
    times: ['09:00'],
    channelIds: [],
    includeSignal: true,
    includeNetwork: true,
    includeRuntime: true,
    includeSim: true,
});

export interface Version {
    version: string;
}

export const getVersion = () => apiClient.get<Version>('/version');
