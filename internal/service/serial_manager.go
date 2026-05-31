package service

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/dushixiang/uart_sms_forwarder/config"
	"go.uber.org/zap"
)

const serialAutoDiscoveryInterval = 30 * time.Second

type SerialDeviceInfo struct {
	ID            string `json:"id"`
	Name          string `json:"name"`
	Port          string `json:"port"`
	PortName      string `json:"portName"`
	ExpectedICCID string `json:"expectedIccid"`
	Connected     bool   `json:"connected"`
}

type SerialManager struct {
	logger                     *zap.Logger
	devices                    map[string]*SerialService
	order                      []string
	defaultID                  string
	serialConfig               config.SerialConfig
	baseDevices                []config.SerialDeviceConfig
	textMsgService             *TextMessageService
	notifier                   *Notifier
	propertyService            *PropertyService
	scheduledTaskStatusUpdater ScheduledTaskStatusUpdater
	started                    bool
	mu                         sync.RWMutex
}

func NewSerialManager(logger *zap.Logger, serialConfig config.SerialConfig, textMsgService *TextMessageService, notifier *Notifier, propertyService *PropertyService) (*SerialManager, error) {
	baseDevices := serialConfig.NormalizedDevices()
	configuredDevices := baseDevices

	if serialConfig.AutoDiscover {
		discovered, err := discoverSerialDevices(logger, baseDevices)
		if err != nil {
			logger.Warn("启动时自动发现未找到模块，后台会继续扫描", zap.Error(err))
			configuredDevices = devicesWithPorts(baseDevices)
		} else {
			configuredDevices = discovered
		}
	}

	if len(configuredDevices) == 0 && !serialConfig.AutoDiscover {
		return nil, fmt.Errorf("未配置串口模块")
	}

	manager := &SerialManager{
		logger:          logger,
		devices:         make(map[string]*SerialService, len(configuredDevices)),
		order:           make([]string, 0, len(configuredDevices)),
		serialConfig:    serialConfig,
		baseDevices:     append([]config.SerialDeviceConfig(nil), baseDevices...),
		textMsgService:  textMsgService,
		notifier:        notifier,
		propertyService: propertyService,
	}

	for _, device := range configuredDevices {
		if strings.TrimSpace(device.Port) == "" {
			continue
		}
		if err := manager.addDeviceLocked(device, false); err != nil {
			return nil, err
		}
	}

	if len(manager.order) == 0 && !serialConfig.AutoDiscover {
		return nil, fmt.Errorf("未配置可用串口模块")
	}

	return manager, nil
}

func devicesWithPorts(devices []config.SerialDeviceConfig) []config.SerialDeviceConfig {
	filtered := make([]config.SerialDeviceConfig, 0, len(devices))
	for _, device := range devices {
		if strings.TrimSpace(device.Port) != "" {
			filtered = append(filtered, device)
		}
	}
	return filtered
}

func (m *SerialManager) Start() {
	m.mu.Lock()
	if m.started {
		m.mu.Unlock()
		return
	}
	m.started = true
	services := make([]*SerialService, 0, len(m.order))
	for _, id := range m.order {
		services = append(services, m.devices[id])
	}
	m.mu.Unlock()

	for _, service := range services {
		m.startService(service)
	}

	if m.serialConfig.AutoDiscover {
		go m.autoDiscoveryLoop()
	}
}

func (m *SerialManager) startService(service *SerialService) {
	go service.Start()
	m.logger.Info("串口模块服务已启动",
		zap.String("device_id", service.DeviceID()),
		zap.String("port", service.ConfiguredPort()))
}

func (m *SerialManager) autoDiscoveryLoop() {
	ticker := time.NewTicker(serialAutoDiscoveryInterval)
	defer ticker.Stop()

	for range ticker.C {
		m.DiscoverSerialDevices()
	}
}

func (m *SerialManager) DiscoverSerialDevices() {
	configured, excludedPorts := m.discoverySnapshot()

	discovered, err := discoverSerialDevicesExcluding(m.logger, configured, excludedPorts)
	if err != nil {
		m.logger.Debug("后台自动发现未发现新模块", zap.Error(err))
		return
	}

	for _, device := range discovered {
		if strings.TrimSpace(device.Port) == "" {
			continue
		}

		m.mu.Lock()
		if m.deviceExistsLocked(device.ID) || m.portExistsLocked(device.Port) {
			m.mu.Unlock()
			continue
		}
		if err := m.addDeviceLocked(device, true); err != nil {
			m.mu.Unlock()
			m.logger.Warn("自动添加串口模块失败", zap.Error(err), zap.String("device_id", device.ID), zap.String("port", device.Port))
			continue
		}
		m.mu.Unlock()
	}
}

func (m *SerialManager) discoverySnapshot() ([]config.SerialDeviceConfig, map[string]struct{}) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	currentByID := make(map[string]config.SerialDeviceConfig, len(m.order))
	excludedPorts := make(map[string]struct{}, len(m.order)*2)

	for _, id := range m.order {
		service := m.devices[id]
		cfg := config.SerialDeviceConfig{
			ID:            service.DeviceID(),
			Name:          service.DeviceName(),
			Port:          service.ConfiguredPort(),
			ExpectedICCID: service.ExpectedICCID(),
		}
		currentByID[cfg.ID] = cfg
		if cfg.Port != "" {
			excludedPorts[cfg.Port] = struct{}{}
			if resolved, err := filepath.EvalSymlinks(cfg.Port); err == nil {
				excludedPorts[resolved] = struct{}{}
			}
		}
	}

	configured := make([]config.SerialDeviceConfig, 0, len(m.baseDevices)+len(currentByID))
	seenIDs := make(map[string]struct{})

	for _, device := range m.baseDevices {
		device.ID = strings.TrimSpace(device.ID)
		if current, ok := currentByID[device.ID]; ok {
			configured = append(configured, current)
		} else {
			configured = append(configured, device)
		}
		seenIDs[device.ID] = struct{}{}
	}

	for _, id := range m.order {
		if _, ok := seenIDs[id]; ok {
			continue
		}
		configured = append(configured, currentByID[id])
	}

	return configured, excludedPorts
}

func (m *SerialManager) addDeviceLocked(device config.SerialDeviceConfig, start bool) error {
	device.ID = strings.TrimSpace(device.ID)
	device.Name = strings.TrimSpace(device.Name)
	device.Port = strings.TrimSpace(device.Port)
	device.ExpectedICCID = strings.TrimSpace(device.ExpectedICCID)

	if device.ID == "" {
		device.ID = m.nextDeviceIDLocked()
	}
	if device.Name == "" {
		device.Name = displaySerialDeviceName(device.ID)
	}
	if device.Port == "" {
		return fmt.Errorf("串口模块 %s 缺少 Port", device.ID)
	}
	if m.deviceExistsLocked(device.ID) {
		return fmt.Errorf("串口模块 ID 重复: %s", device.ID)
	}
	if owner, ok := m.portOwnerLocked(device.Port); ok {
		return fmt.Errorf("串口 %s 已绑定到 %s", device.Port, owner)
	}

	service := NewSerialDeviceService(m.logger, device, m.textMsgService, m.notifier, m.propertyService)
	if m.scheduledTaskStatusUpdater != nil {
		service.SetScheduledTaskStatusUpdater(m.scheduledTaskStatusUpdater)
	}

	if m.defaultID == "" {
		m.defaultID = device.ID
	}
	m.order = append(m.order, device.ID)
	m.devices[device.ID] = service

	m.logger.Info("串口模块已加入",
		zap.String("device_id", device.ID),
		zap.String("device_name", device.Name),
		zap.String("port", device.Port),
		zap.String("expected_iccid", device.ExpectedICCID))

	if start {
		m.startService(service)
	}
	return nil
}

func (m *SerialManager) nextDeviceIDLocked() string {
	for i := 1; ; i++ {
		id := config.DefaultSerialDeviceID(i - 1)
		if !m.deviceExistsLocked(id) {
			return id
		}
	}
}

func (m *SerialManager) deviceExistsLocked(deviceID string) bool {
	_, ok := m.devices[deviceID]
	return ok
}

func (m *SerialManager) portExistsLocked(port string) bool {
	_, ok := m.portOwnerLocked(port)
	return ok
}

func (m *SerialManager) portOwnerLocked(port string) (string, bool) {
	for id, service := range m.devices {
		if service.ConfiguredPort() == port {
			return id, true
		}
	}
	return "", false
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
