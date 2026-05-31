package service

import (
	"context"
	"fmt"
	"strings"
	"sync"

	"github.com/dushixiang/uart_sms_forwarder/config"
	"go.uber.org/zap"
)

// SerialDeviceInfo 是前端和 API 使用的模块摘要。
type SerialDeviceInfo struct {
	ID            string `json:"id"`
	Name          string `json:"name"`
	Port          string `json:"port"`
	PortName      string `json:"portName"`
	ExpectedICCID string `json:"expectedIccid"`
	Connected     bool   `json:"connected"`
}

// SerialManager 管理一个或多个串口模块。
type SerialManager struct {
	logger    *zap.Logger
	devices   map[string]*SerialService
	order     []string
	defaultID string
	mu        sync.RWMutex
}

func NewSerialManager(
	logger *zap.Logger,
	serialConfig config.SerialConfig,
	textMsgService *TextMessageService,
	notifier *Notifier,
	propertyService *PropertyService,
) (*SerialManager, error) {
	configuredDevices := serialConfig.NormalizedDevices()
	if len(configuredDevices) == 0 {
		return nil, fmt.Errorf("未配置串口模块")
	}

	manager := &SerialManager{
		logger:  logger,
		devices: make(map[string]*SerialService, len(configuredDevices)),
		order:   make([]string, 0, len(configuredDevices)),
	}

	seenIDs := make(map[string]struct{}, len(configuredDevices))
	seenPorts := make(map[string]string, len(configuredDevices))
	multiDeviceMode := len(serialConfig.Devices) > 0

	for _, device := range configuredDevices {
		device.ID = strings.TrimSpace(device.ID)
		device.Name = strings.TrimSpace(device.Name)
		device.Port = strings.TrimSpace(device.Port)
		device.ExpectedICCID = strings.TrimSpace(device.ExpectedICCID)

		if device.ID == "" {
			return nil, fmt.Errorf("串口模块 ID 不能为空")
		}
		if _, ok := seenIDs[device.ID]; ok {
			return nil, fmt.Errorf("串口模块 ID 重复: %s", device.ID)
		}
		if multiDeviceMode && device.Port == "" {
			return nil, fmt.Errorf("多模块模式下必须为 %s 配置固定 Port", device.ID)
		}
		if device.Port != "" {
			if owner, ok := seenPorts[device.Port]; ok {
				return nil, fmt.Errorf("串口 %s 同时绑定到 %s 和 %s", device.Port, owner, device.ID)
			}
			seenPorts[device.Port] = device.ID
		}
		if device.Name == "" {
			device.Name = device.ID
		}

		seenIDs[device.ID] = struct{}{}
		if manager.defaultID == "" {
			manager.defaultID = device.ID
		}
		manager.order = append(manager.order, device.ID)
		manager.devices[device.ID] = NewSerialDeviceService(
			logger,
			device,
			textMsgService,
			notifier,
			propertyService,
		)
	}

	return manager, nil
}

func (m *SerialManager) Start() {
	m.mu.RLock()
	defer m.mu.RUnlock()

	for _, id := range m.order {
		service := m.devices[id]
		go service.Start()
		m.logger.Info("串口模块服务已启动",
			zap.String("device_id", id),
			zap.String("port", service.ConfiguredPort()))
	}
}

func (m *SerialManager) SetScheduledTaskStatusUpdater(updater ScheduledTaskStatusUpdater) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	for _, service := range m.devices {
		service.SetScheduledTaskStatusUpdater(updater)
	}
}

func (m *SerialManager) DefaultDeviceID() string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.defaultID
}

func (m *SerialManager) ResolveDeviceID(deviceID string) string {
	if strings.TrimSpace(deviceID) != "" {
		return strings.TrimSpace(deviceID)
	}
	return m.DefaultDeviceID()
}

func (m *SerialManager) Device(deviceID string) (*SerialService, error) {
	deviceID = m.ResolveDeviceID(deviceID)

	m.mu.RLock()
	defer m.mu.RUnlock()

	service, ok := m.devices[deviceID]
	if !ok {
		return nil, fmt.Errorf("串口模块不存在: %s", deviceID)
	}
	return service, nil
}

func (m *SerialManager) ListDevices() []SerialDeviceInfo {
	m.mu.RLock()
	defer m.mu.RUnlock()

	devices := make([]SerialDeviceInfo, 0, len(m.order))
	for _, id := range m.order {
		devices = append(devices, m.devices[id].DeviceInfo())
	}
	return devices
}

func (m *SerialManager) GetStatus(deviceID string) (*StatusData, error) {
	service, err := m.Device(deviceID)
	if err != nil {
		return nil, err
	}
	return service.GetStatus()
}

func (m *SerialManager) GetAllStatus() ([]*StatusData, error) {
	m.mu.RLock()
	ids := append([]string(nil), m.order...)
	m.mu.RUnlock()

	statuses := make([]*StatusData, 0, len(ids))
	for _, id := range ids {
		status, err := m.GetStatus(id)
		if err != nil {
			return nil, err
		}
		statuses = append(statuses, status)
	}
	return statuses, nil
}

func (m *SerialManager) SendSMS(deviceID, to, content string) (string, error) {
	service, err := m.Device(deviceID)
	if err != nil {
		return "", err
	}
	return service.SendSMS(to, content)
}

func (m *SerialManager) FlyMode(deviceID string) (bool, error) {
	service, err := m.Device(deviceID)
	if err != nil {
		return false, err
	}
	return service.FlyMode(), nil
}

func (m *SerialManager) SetFlymode(deviceID string, enabled bool) error {
	service, err := m.Device(deviceID)
	if err != nil {
		return err
	}
	return service.SetFlymode(enabled)
}

func (m *SerialManager) RebootMcu(deviceID string) error {
	service, err := m.Device(deviceID)
	if err != nil {
		return err
	}
	return service.RebootMcu()
}

func (m *SerialManager) RequestCacheUpdate(deviceID string) error {
	service, err := m.Device(deviceID)
	if err != nil {
		return err
	}
	service.RequestCacheUpdate()
	return nil
}

func (m *SerialManager) RequestAllCacheUpdate(ctx context.Context) {
	m.mu.RLock()
	services := make([]*SerialService, 0, len(m.order))
	for _, id := range m.order {
		services = append(services, m.devices[id])
	}
	m.mu.RUnlock()

	for _, service := range services {
		select {
		case <-ctx.Done():
			return
		default:
			service.RequestCacheUpdate()
		}
	}
}
