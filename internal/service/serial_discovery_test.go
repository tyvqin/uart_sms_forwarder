package service

import (
	"testing"

	"github.com/dushixiang/uart_sms_forwarder/config"
	"go.uber.org/zap"
)

func TestAssignDiscoveredSerialDevicesPreservesConfiguredPortWhenSimChanges(t *testing.T) {
	devices := assignDiscoveredSerialDevices(zap.NewNop(), []config.SerialDeviceConfig{
		{ID: "sim3", Name: "SIM 3", Port: "/dev/serial/by-path/hub-port-3", ExpectedICCID: "old-card"},
	}, []discoveredSerialDevice{
		{Port: "/dev/serial/by-path/hub-port-3", ICCID: "new-card"},
	})

	if len(devices) != 1 {
		t.Fatalf("expected 1 device, got %d", len(devices))
	}
	if devices[0].ID != "sim3" || devices[0].Port != "/dev/serial/by-path/hub-port-3" {
		t.Fatalf("slot was not preserved after SIM change: %+v", devices[0])
	}
	if devices[0].ExpectedICCID != "" {
		t.Fatalf("ICCID must not be persisted as a routing lock: %+v", devices[0])
	}
}

func TestAssignDiscoveredSerialDevicesAppendsNewPortsSequentiallyWithoutCardLock(t *testing.T) {
	devices := assignDiscoveredSerialDevices(zap.NewNop(), []config.SerialDeviceConfig{
		{ID: "sim1", Name: "SIM 1", Port: "/dev/serial/by-path/hub-port-1"},
	}, []discoveredSerialDevice{
		{Port: "/dev/serial/by-path/hub-port-1", ICCID: "card-a"},
		{Port: "/dev/serial/by-path/hub-port-2", ICCID: "card-b"},
	})

	if len(devices) != 2 {
		t.Fatalf("expected 2 devices, got %d", len(devices))
	}
	if devices[1].ID != "sim2" || devices[1].Port != "/dev/serial/by-path/hub-port-2" {
		t.Fatalf("new module was not appended as sim2 by port: %+v", devices[1])
	}
	if devices[1].ExpectedICCID != "" {
		t.Fatalf("new module must not store ICCID as a routing key: %+v", devices[1])
	}
}

func TestAssignDiscoveredSerialDevicesUsesStablePortOrderForEmptySlots(t *testing.T) {
	devices := assignDiscoveredSerialDevices(zap.NewNop(), []config.SerialDeviceConfig{
		{ID: "sim1", Name: "SIM 1"},
	}, []discoveredSerialDevice{
		{Port: "/dev/serial/by-path/hub-port-b"},
		{Port: "/dev/serial/by-path/hub-port-a"},
	})

	if len(devices) != 2 {
		t.Fatalf("expected 2 devices, got %d", len(devices))
	}
	if devices[0].ID != "sim1" || devices[0].Port != "/dev/serial/by-path/hub-port-a" {
		t.Fatalf("empty slot should bind first stable port: %+v", devices[0])
	}
	if devices[1].ID != "sim2" || devices[1].Port != "/dev/serial/by-path/hub-port-b" {
		t.Fatalf("second port should become sim2: %+v", devices[1])
	}
}

func TestDisplaySerialDeviceName(t *testing.T) {
	if got := displaySerialDeviceName("sim12"); got != "SIM 12" {
		t.Fatalf("unexpected device name: %q", got)
	}
}
