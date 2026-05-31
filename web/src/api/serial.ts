import apiClient from './client';
import type {DeviceStatus, SendSMSRequest, SerialDeviceInfo} from './types';

// 发送短信
export const sendSMS = (data: SendSMSRequest) => {
  return apiClient.post('/serial/sms', data);
};

// 获取串口模块列表
export const getDevices = () => {
  return apiClient.get<SerialDeviceInfo[]>('/serial/devices');
};

// 获取设备状态（包含移动网络信息）
export const getStatus = (deviceId?: string) => {
  return apiClient.get<DeviceStatus>('/serial/status', {params: {deviceId}});
};

// 获取所有设备状态
export const getStatuses = () => {
  return apiClient.get<DeviceStatus[]>('/serial/statuses');
};

// 设置飞行模式
export const setFlymode = (enabled: boolean, deviceId?: string) => {
  return apiClient.post('/serial/flymode', { enabled, deviceId });
};

// 重启模块
export const rebootMcu = (deviceId?: string) => {
  return apiClient.post('/serial/reboot', {deviceId});
};
