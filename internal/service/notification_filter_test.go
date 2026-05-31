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
}

func TestNotificationRoutingDoesNotCrossSIMOrType(t *testing.T) {
	channels := []models.NotificationChannelConfig{
		{ID: "dingtalk-sim1", Type: "dingtalk", Enabled: true, DeviceIDs: []string{"sim1"}},
		{ID: "feishu-sim3", Type: "feishu", Enabled: true, DeviceIDs: []string{"sim3"}},
		{ID: "dingtalk-disabled-sim3", Type: "dingtalk", Enabled: false, DeviceIDs: []string{"sim3"}},
	}
	matched := func(deviceID string) []string {
		var ids []string
		for _, channel := range channels {
			if notificationChannelCanReceive(channel, deviceID) {
				ids = append(ids, channel.ID)
			}
		}
		return ids
	}
	if got := matched("sim1"); len(got) != 1 || got[0] != "dingtalk-sim1" {
		t.Fatalf("sim1 must only route to dingtalk-sim1, got %#v", got)
	}
	if got := matched("sim3"); len(got) != 1 || got[0] != "feishu-sim3" {
		t.Fatalf("sim3 must only route to feishu-sim3, got %#v", got)
	}
	if got := matched("sim2"); len(got) != 0 {
		t.Fatalf("sim2 must not route to sim1/sim3 channels, got %#v", got)
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
