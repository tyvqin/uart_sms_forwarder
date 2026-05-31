package service

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

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
	logger                     *zap.Logger
	devices                    map[string]*SerialService
	order                      []string
	defaultID                  string
	autoDiscover               bool
	discoveryInterval          time.Duration
	textMsgService             *TextMessageService
	notifier                   *Notifier
	propertyService            *PropertyService
	scheduledTaskStatusUpdater ScheduledTaskStatusUpdater
	mu                         sync.RWMutex
}

const serialAutoDiscoveryInterval = 30 * time.Second

func NewSerialManager(
	logger *zap.Logger,
	serialConfig config.SerialConfig,
	textMsgService *TextMessageService,
	notifier *Notifier,
	propertyService *PropertyService,
) (*SerialManager, error) {
	configuredDevices := serialConfig.NormalizedDevices()
	if serialConfig.AutoDiscover {
		var err error
		configuredDevices, err = discoverSerialDevices(logger, configuredDevices)
		if err != nil {
			return nil, err
		}
	}
	if len(configuredDevices) == 0 {
		return nil, fmt.Errorf("未配置串口模块")
	}

	manager := &SerialManager{
		logger:            logger,
		devices:           make(map[string]*SerialService, len(configuredDevices)),
		order:             make([]string, 0, len(configuredDevices)),
		autoDiscover:      serialConfig.AutoDiscover,
		discoveryInterval: serialAutoDiscoveryInterval,
		textMsgService:    textMsgService,
		notifier:          notifier,
		propertyService:   propertyService,
	}

	seenIDs := make(map[string]struct{}, len(configuredDevices))
	seenPorts := make(map[string]string, len(configuredDevices))
	multiDeviceMode := len(serialConfig.Devices) > 0 || serialConfig.AutoDiscover

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
	services := make([]*SerialService, 0, len(m.order))
	ids := append([]string(nil), m.order...)
	for _, id := range ids {
		services = append(services, m.devices[id])
	}
	autoDiscover := m.autoDiscover
	m.mu.RUnlock()

	for i, service := range services {
		go service.Start()
		m.logger.Info("串口模块服务已启动",
			zap.String("device_id", ids[i]),
			zap.String("port", service.ConfiguredPort()))
	}

	if autoDiscover {
		go m.autoDiscoveryLoop()
	}
}

func (m *SerialManager) SetScheduledTaskStatusUpdater(updater ScheduledTaskStatusUpdater) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.scheduledTaskStatusUpdater = updater
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

func (m *SerialManager) autoDiscoveryLoop() {
	ticker := time.NewTicker(m.discoveryInterval)
	defer ticker.Stop()

	for range ticker.C {
		if err := m.refreshDiscoveredDevices(); err != nil {
			m.logger.Warn("serial hotplug discovery failed", zap.Error(err))
		}
	}
}

func (m *SerialManager) refreshDiscoveredDevices() error {
	configured, excludedPorts := m.discoverySnapshot()
	devices, err := discoverSerialDevicesExcluding(m.logger, configured, excludedPorts)
	if err != nil {
		return err
	}
	m.applyDiscoveredDevices(devices)
	return nil
}

func (m *SerialManager) discoverySnapshot() ([]config.SerialDeviceConfig, map[string]struct{}) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	configured := make([]config.SerialDeviceConfig, 0, len(m.order))
	excludedPorts := make(map[string]struct{}, len(m.order))
	for _, id := range m.order {
		service := m.devices[id]
		info := service.DeviceInfo()
		configured = append(configured, config.SerialDeviceConfig{
			ID:            info.ID,
			Name:          info.Name,
			Port:          info.Port,
			ExpectedICCID: info.ExpectedICCID,
		})
		if info.Connected {
			if info.Port != "" {
				excludedPorts[info.Port] = struct{}{}
			}
			if info.PortName != "" {
				excludedPorts[info.PortName] = struct{}{}
			}
		}
	}
	return configured, excludedPorts
}

func (m *SerialManager) applyDiscoveredDevices(configs []config.SerialDeviceConfig) {
	m.mu.Lock()
	defer m.mu.Unlock()

	for _, device := range configs {
		device.ID = strings.TrimSpace(device.ID)
		device.Name = strings.TrimSpace(device.Name)
		device.Port = strings.TrimSpace(device.Port)
		device.ExpectedICCID = strings.TrimSpace(device.ExpectedICCID)
		if device.ID == "" || device.Port == "" {
			continue
		}
		if device.Name == "" {
			device.Name = displaySerialDeviceName(device.ID)
		}

		if service, ok := m.devices[device.ID]; ok {
			service.UpdateDiscoveredBinding(device.Port, device.ExpectedICCID)
			continue
		}

		service := NewSerialDeviceService(
			m.logger,
			device,
			m.textMsgService,
			m.notifier,
			m.propertyService,
		)
		service.SetScheduledTaskStatusUpdater(m.scheduledTaskStatusUpdater)
		m.devices[device.ID] = service
		m.order = append(m.order, device.ID)
		if m.defaultID == "" {
			m.defaultID = device.ID
		}
		go service.Start()
		m.logger.Info("serial hotplug module added",
			zap.String("device_id", device.ID),
			zap.String("port", device.Port))
	}
}
