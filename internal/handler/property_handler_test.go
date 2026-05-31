package handler

import (
	"testing"

	"github.com/dushixiang/uart_sms_forwarder/internal/models"
)

func TestSelectNotificationChannelForTestUsesChannelID(t *testing.T) {
	channels := []models.NotificationChannelConfig{
		{ID: "dingtalk-sim1", Type: "dingtalk"},
		{ID: "dingtalk-sim2", Type: "dingtalk"},
	}

	selected := selectNotificationChannelForTest(channels, "dingtalk", "dingtalk-sim2")
	if selected == nil || selected.ID != "dingtalk-sim2" {
		t.Fatalf("expected dingtalk-sim2, got %#v", selected)
	}
}

func TestSelectNotificationChannelForTestRequiresMatchingType(t *testing.T) {
	channels := []models.NotificationChannelConfig{
		{ID: "shared-id", Type: "feishu"},
	}

	if selected := selectNotificationChannelForTest(channels, "dingtalk", "shared-id"); selected != nil {
		t.Fatalf("expected nil for mismatched type, got %#v", selected)
	}
}
