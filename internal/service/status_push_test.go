package service

import (
	"strings"
	"testing"
	"time"

	"github.com/dushixiang/uart_sms_forwarder/internal/models"
)

func TestFilterStatusesForChannelRespectsDeviceScope(t *testing.T) {
	statuses := []*StatusData{
		{DeviceID: "sim1", DeviceName: "SIM 1", Connected: true},
		{DeviceID: "sim3", DeviceName: "SIM 3", Connected: true},
	}
	channel := models.NotificationChannelConfig{ID: "feishu-sim3", Type: "feishu", Enabled: true, DeviceIDs: []string{"sim3"}}
	filtered := filterStatusesForChannel(statuses, channel)
	if len(filtered) != 1 || filtered[0].DeviceID != "sim3" {
		t.Fatalf("expected only sim3 status, got %#v", filtered)
	}
}

func TestFormatStatusPushMessageDoesNotIncludePrivateIdentifiers(t *testing.T) {
	status := &StatusData{DeviceID: "sim1", DeviceName: "SIM 1", Connected: true}
	status.Mobile.Iccid = "12345678901234567890"
	status.Mobile.Imsi = "460001234567890"
	status.Mobile.Number = "+8613800000000"
	status.Mobile.SignalDesc = "强"
	status.Mobile.Csq = 31
	msg := formatStatusPushMessage([]*StatusData{status}, DefaultStatusPushConfig(), time.Unix(1700000000, 0))
	for _, forbidden := range []string{status.Mobile.Iccid, status.Mobile.Imsi, status.Mobile.Number} {
		if strings.Contains(msg, forbidden) {
			t.Fatalf("status push message leaked private identifier %q: %s", forbidden, msg)
		}
	}
	if !strings.Contains(msg, "SIM 1") || !strings.Contains(msg, "信号") {
		t.Fatalf("status push message missing expected status fields: %s", msg)
	}
}

func TestBuildCallNotificationMessageUsesDisconnectTime(t *testing.T) {
	call := IncomingCall{Timestamp: 100, From: "+123"}
	msg := buildCallNotificationMessage(call, "sim1", "SIM 1", 200)
	if msg.Type != "call" || msg.DeviceID != "sim1" || msg.Timestamp != 200 || msg.From != "+123" {
		t.Fatalf("unexpected call notification message: %#v", msg)
	}
}
