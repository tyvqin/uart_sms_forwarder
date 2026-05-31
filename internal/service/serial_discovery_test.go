package service

import (
	"testing"

	"github.com/dushixiang/uart_sms_forwarder/config"
	"go.uber.org/zap"
)

func TestParseStatusResponseFromBuffer(t *testing.T) {
	status, ok := parseStatusResponseFromBuffer(`noise SMS_START:{"type":"status_response","mobile":{"iccid":"89860083192095723560","imsi":"460076500486335","number":"+8618520408808"}}:SMS_END tail`)
	if !ok {
		t.Fatal("expected status response")
	}
	if status.Mobile.Iccid != "89860083192095723560" {
		t.Fatalf("unexpected iccid: %s", status.Mobile.Iccid)
	}
}

func TestAssignDiscoveredSerialDevicesByICCID(t *testing.T) {
	devices := assignDiscoveredSerialDevices(zap.NewNop(), []config.SerialDeviceConfig{
		{ID: "sim1", Name: "SIM 1", ExpectedICCID: "iccid-1"},
		{ID: "sim2", Name: "SIM 2", ExpectedICCID: "iccid-2"},
	}, []discoveredSerialDevice{
		{Port: "/dev/serial/by-path/modem-b", ICCID: "iccid-2"},
		{Port: "/dev/serial/by-path/modem-a", ICCID: "iccid-1"},
	})

	if len(devices) != 2 {
		t.Fatalf("expected 2 devices, got %d", len(devices))
	}
	if devices[0].ID != "sim1" || devices[0].Port != "/dev/serial/by-path/modem-a" {
		t.Fatalf("sim1 was not bound by ICCID: %+v", devices[0])
	}
	if devices[1].ID != "sim2" || devices[1].Port != "/dev/serial/by-path/modem-b" {
		t.Fatalf("sim2 was not bound by ICCID: %+v", devices[1])
	}
}

func TestAssignDiscoveredSerialDevicesAppendsNewModules(t *testing.T) {
	devices := assignDiscoveredSerialDevices(zap.NewNop(), []config.SerialDeviceConfig{
		{ID: "sim1", Name: "SIM 1", ExpectedICCID: "iccid-1"},
	}, []discoveredSerialDevice{
		{Port: "/dev/serial/by-path/modem-a", ICCID: "iccid-1"},
		{Port: "/dev/serial/by-path/modem-b", ICCID: "iccid-2"},
	})

	if len(devices) != 2 {
		t.Fatalf("expected 2 devices, got %d", len(devices))
	}
	if devices[1].ID != "sim2" || devices[1].ExpectedICCID != "iccid-2" {
		t.Fatalf("new module was not appended as sim2: %+v", devices[1])
	}
}
