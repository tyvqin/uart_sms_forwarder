package service

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/dushixiang/uart_sms_forwarder/config"
	"go.bug.st/serial"
	"go.uber.org/zap"
)

const (
	serialProbeTimeout = 5 * time.Second
	serialReadTimeout  = 250 * time.Millisecond
	serialProbeMaxRead = 8192
)

type discoveredSerialDevice struct {
	Port   string
	ICCID  string
	IMSI   string
	Number string
}

func discoverSerialDevices(logger *zap.Logger, configured []config.SerialDeviceConfig) ([]config.SerialDeviceConfig, error) {
	discovered, err := probeDiscoveredSerialDevices(logger, nil)
	if err != nil {
		return nil, err
	}

	return assignDiscoveredSerialDevices(logger, configured, discovered), nil
}

func discoverSerialDevicesExcluding(logger *zap.Logger, configured []config.SerialDeviceConfig, excludedPorts map[string]struct{}) ([]config.SerialDeviceConfig, error) {
	discovered, err := probeDiscoveredSerialDevices(logger, excludedPorts)
	if err != nil {
		if len(configured) > 0 {
			return configured, nil
		}
		return nil, err
	}

	return assignDiscoveredSerialDevices(logger, configured, discovered), nil
}

func probeDiscoveredSerialDevices(logger *zap.Logger, excludedPorts map[string]struct{}) ([]discoveredSerialDevice, error) {
	candidates, err := serialDiscoveryCandidates()
	if err != nil {
		return nil, err
	}
	if len(candidates) == 0 {
		return nil, fmt.Errorf("no serial ports found for auto discovery")
	}

	discovered := make([]discoveredSerialDevice, 0, len(candidates))
	for _, portName := range candidates {
		if serialPortExcluded(portName, excludedPorts) {
			continue
		}
		device, err := probeSerialDevice(portName)
		if err != nil {
			logger.Debug("serial auto discovery skipped port",
				zap.String("port", portName),
				zap.Error(err))
			continue
		}
		logger.Info("serial auto discovery found module",
			zap.String("port", device.Port),
			zap.String("iccid", device.ICCID),
			zap.String("number", device.Number))
		discovered = append(discovered, device)
	}

	if len(discovered) == 0 {
		return nil, fmt.Errorf("auto discovery did not find any uart_sms_forwarder modules")
	}

	return discovered, nil
}

func serialPortExcluded(portName string, excludedPorts map[string]struct{}) bool {
	if len(excludedPorts) == 0 {
		return false
	}
	if _, ok := excludedPorts[portName]; ok {
		return true
	}
	resolved, err := filepath.EvalSymlinks(portName)
	if err != nil {
		return false
	}
	if _, ok := excludedPorts[resolved]; ok {
		return true
	}
	for excluded := range excludedPorts {
		if resolvedExcluded, err := filepath.EvalSymlinks(excluded); err == nil && resolvedExcluded == resolved {
			return true
		}
	}
	return false
}

func serialDiscoveryCandidates() ([]string, error) {
	var candidates []string
	seenTargets := make(map[string]struct{})

	add := func(portName string) {
		target := portName
		if resolved, err := filepath.EvalSymlinks(portName); err == nil {
			target = resolved
		}
		if !isUSBSerialPort(target) {
			return
		}
		if _, ok := seenTargets[target]; ok {
			return
		}
		seenTargets[target] = struct{}{}
		candidates = append(candidates, portName)
	}

	byPathPorts, _ := filepath.Glob("/dev/serial/by-path/*")
	sort.Strings(byPathPorts)
	for _, portName := range byPathPorts {
		add(portName)
	}

	ports, err := serial.GetPortsList()
	if err != nil && len(candidates) == 0 {
		return nil, fmt.Errorf("list serial ports: %w", err)
	}
	sort.Strings(ports)
	for _, portName := range ports {
		add(portName)
	}

	return candidates, nil
}

func isUSBSerialPort(portName string) bool {
	base := filepath.Base(portName)
	return strings.HasPrefix(base, "ttyACM") || strings.HasPrefix(base, "ttyUSB") || strings.HasPrefix(base, "COM")
}

func probeSerialDevice(portName string) (discoveredSerialDevice, error) {
	mode := &serial.Mode{
		BaudRate: 115200,
		DataBits: 8,
		StopBits: serial.OneStopBit,
		Parity:   serial.NoParity,
	}

	port, err := serial.Open(portName, mode)
	if err != nil {
		return discoveredSerialDevice{}, err
	}
	defer port.Close()

	_ = port.SetReadTimeout(serialReadTimeout)

	message, _, err := buildCommandMessage(map[string]string{"action": "get_status"})
	if err != nil {
		return discoveredSerialDevice{}, err
	}
	if _, err := port.Write(message); err != nil {
		return discoveredSerialDevice{}, fmt.Errorf("write probe command: %w", err)
	}

	var response strings.Builder
	buf := make([]byte, 1024)
	deadline := time.Now().Add(serialProbeTimeout)
	for time.Now().Before(deadline) && response.Len() < serialProbeMaxRead {
		n, err := port.Read(buf)
		if n > 0 {
			response.Write(buf[:n])
			if status, ok := parseStatusResponseFromBuffer(response.String()); ok {
				return discoveredSerialDevice{
					Port:   portName,
					ICCID:  normalizeICCID(status.Mobile.Iccid),
					IMSI:   strings.TrimSpace(status.Mobile.Imsi),
					Number: strings.TrimSpace(status.Mobile.Number),
				}, nil
			}
		}
		if err != nil && !isReadTimeout(err) {
			return discoveredSerialDevice{}, fmt.Errorf("read probe response: %w", err)
		}
	}

	return discoveredSerialDevice{}, fmt.Errorf("no status response")
}

func isReadTimeout(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "timeout") || strings.Contains(msg, "timed out")
}

func parseStatusResponseFromBuffer(data string) (*StatusData, bool) {
	rest := data
	for {
		start := strings.Index(rest, smsPrefix)
		if start < 0 {
			return nil, false
		}
		rest = rest[start:]
		end := strings.Index(rest, smsSuffix)
		if end < 0 {
			return nil, false
		}

		frame := rest[:end+len(smsSuffix)]
		msg, err := parseSMSFrame(frame)
		if err == nil && msg.Type == "status_response" {
			var status StatusData
			if err := json.Unmarshal([]byte(msg.JSON), &status); err == nil {
				return &status, true
			}
		}
		rest = rest[end+len(smsSuffix):]
	}
}

func normalizeICCID(iccid string) string {
	iccid = strings.TrimSpace(iccid)
	if strings.EqualFold(iccid, "unknown") {
		return ""
	}
	return iccid
}

func assignDiscoveredSerialDevices(
	logger *zap.Logger,
	configured []config.SerialDeviceConfig,
	discovered []discoveredSerialDevice,
) []config.SerialDeviceConfig {
	byICCID := make(map[string]discoveredSerialDevice, len(discovered))
	for _, device := range discovered {
		if device.ICCID != "" {
			byICCID[device.ICCID] = device
		}
	}

	usedPorts := make(map[string]struct{}, len(discovered))
	usedIDs := make(map[string]struct{}, len(configured)+len(discovered))
	devices := make([]config.SerialDeviceConfig, 0, len(configured)+len(discovered))

	for _, device := range configured {
		device.ID = strings.TrimSpace(device.ID)
		device.Name = strings.TrimSpace(device.Name)
		device.Port = strings.TrimSpace(device.Port)
		device.ExpectedICCID = strings.TrimSpace(device.ExpectedICCID)
		if device.ID == "" {
			device.ID = nextSerialDeviceID(usedIDs)
		}
		if device.Name == "" {
			device.Name = device.ID
		}
		usedIDs[device.ID] = struct{}{}

		if device.ExpectedICCID != "" {
			if found, ok := byICCID[device.ExpectedICCID]; ok {
				device.Port = found.Port
				usedPorts[found.Port] = struct{}{}
				devices = append(devices, device)
				continue
			}
			if device.Port == "" {
				logger.Warn("configured serial module not found during auto discovery",
					zap.String("device_id", device.ID),
					zap.String("expected_iccid", device.ExpectedICCID))
				continue
			}
		}

		if device.Port == "" {
			if found, ok := firstUnusedDiscovered(discovered, usedPorts); ok {
				device.Port = found.Port
				device.ExpectedICCID = found.ICCID
				usedPorts[found.Port] = struct{}{}
			}
		} else {
			usedPorts[device.Port] = struct{}{}
		}

		if device.Port != "" {
			devices = append(devices, device)
		}
	}

	for _, found := range discovered {
		if _, ok := usedPorts[found.Port]; ok {
			continue
		}
		id := nextSerialDeviceID(usedIDs)
		usedIDs[id] = struct{}{}
		usedPorts[found.Port] = struct{}{}
		devices = append(devices, config.SerialDeviceConfig{
			ID:            id,
			Name:          displaySerialDeviceName(id),
			Port:          found.Port,
			ExpectedICCID: found.ICCID,
		})
	}

	return devices
}

func firstUnusedDiscovered(discovered []discoveredSerialDevice, usedPorts map[string]struct{}) (discoveredSerialDevice, bool) {
	for _, device := range discovered {
		if _, ok := usedPorts[device.Port]; !ok {
			return device, true
		}
	}
	return discoveredSerialDevice{}, false
}

func nextSerialDeviceID(used map[string]struct{}) string {
	for i := 1; ; i++ {
		id := config.DefaultSerialDeviceID(i - 1)
		if _, ok := used[id]; !ok {
			return id
		}
	}
}

func displaySerialDeviceName(id string) string {
	if strings.HasPrefix(strings.ToLower(id), "sim") {
		suffix := strings.TrimSpace(id[3:])
		if suffix != "" {
			return "SIM " + suffix
		}
	}
	return strings.ToUpper(id)
}
