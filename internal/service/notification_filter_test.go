package service

import (
	"testing"

	"github.com/dushixiang/uart_sms_forwarder/internal/models"
)

func TestNotificationChannelMatchesDevice(t *testing.T) {
	if !notificationChannelMatchesDevice(nil, "sim1") {
		t.Fatal("empty device list should match all devices")
	}
	if !notificationChannelMatchesDevice([]string{"sim1", " sim2 "}, "sim2") {
		t.Fatal("expected sim2 to match")
	}
	if notificationChannelMatchesDevice([]string{"sim1"}, "sim2") {
		t.Fatal("did not expect sim2 to match sim1-only channel")
	}
	if notificationChannelMatchesDevice([]string{"sim1"}, "sim10") {
		t.Fatal("device routing must be exact, not prefix based")
	}
}

func TestNotificationChannelCanReceiveUsesDeviceIDOnly(t *testing.T) {
	smsFromSim1 := NotificationMessage{Type: "sms", DeviceID: "sim1", DeviceName: "SIM 1"}
	smsFromSim3 := NotificationMessage{Type: "sms", DeviceID: "sim3", DeviceName: "SIM 3"}
	dingTalkForSim1 := models.NotificationChannelConfig{ID: "dingtalk-sim1", Type: "dingtalk", Enabled: true, DeviceIDs: []string{"sim1"}}
	feishuForSim3 := models.NotificationChannelConfig{ID: "feishu-sim3", Type: "feishu", Enabled: true, DeviceIDs: []string{"sim3"}}

	if !notificationChannelCanReceive(dingTalkForSim1, smsFromSim1.DeviceID) {
		t.Fatal("sim1 SMS should be allowed to sim1 channel")
	}
	if notificationChannelCanReceive(dingTalkForSim1, smsFromSim3.DeviceID) {
		t.Fatal("sim3 SMS must not be delivered to sim1 channel")
	}
	if notificationChannelCanReceive(feishuForSim3, smsFromSim1.DeviceID) {
		t.Fatal("sim1 SMS must not be delivered to sim3 channel")
	}
	if !notificationChannelCanReceive(feishuForSim3, smsFromSim3.DeviceID) {
		t.Fatal("sim3 SMS should be allowed to sim3 channel")
	}
}

func TestNormalizeNotificationChannelConfigsAllowsRepeatedTypes(t *testing.T) {
	channels := NormalizeNotificationChannelConfigs([]models.NotificationChannelConfig{
		{Type: "dingtalk", Enabled: true, Config: map[string]interface{}{"accessToken": "token-a"}, DeviceIDs: []string{" sim1 ", "sim1"}},
		{Type: "dingtalk", Enabled: true, Config: map[string]interface{}{"secretKey": "token-b"}, DeviceIDs: []string{"sim2"}},
	})

	if len(channels) != 2 {
		t.Fatalf("expected 2 channels, got %d", len(channels))
	}
	if channels[0].ID == channels[1].ID {
		t.Fatalf("expected unique channel IDs, got %q", channels[0].ID)
	}
	if channels[0].Config["secretKey"] != "token-a" {
		t.Fatalf("expected accessToken alias to become secretKey: %+v", channels[0].Config)
	}
	if len(channels[0].DeviceIDs) != 1 || channels[0].DeviceIDs[0] != "sim1" {
		t.Fatalf("expected normalized device IDs, got %#v", channels[0].DeviceIDs)
	}
}
