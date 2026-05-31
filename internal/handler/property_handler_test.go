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

func TestSelectNotificationChannelForTestRequiresChannelID(t *testing.T) {
	channels := []models.NotificationChannelConfig{
		{ID: "dingtalk-sim1", Type: "dingtalk"},
	}

	if selected := selectNotificationChannelForTest(channels, "dingtalk", ""); selected != nil {
		t.Fatalf("expected nil when channelId is missing, got %#v", selected)
	}
}

func TestRedactNotificationChannelsForResponseMasksSecrets(t *testing.T) {
	channels := []models.NotificationChannelConfig{
		{ID: "dingtalk-sim1", Type: "dingtalk", Config: map[string]interface{}{"secretKey": "token", "signSecret": "sign"}},
	}

	redacted := redactNotificationChannelsForResponse(channels)
	if redacted[0].Config["secretKey"] != maskedNotificationSecret || redacted[0].Config["signSecret"] != maskedNotificationSecret {
		t.Fatalf("expected masked secrets, got %#v", redacted[0].Config)
	}
	if channels[0].Config["secretKey"] == maskedNotificationSecret {
		t.Fatal("redaction must not mutate stored config")
	}
}

func TestMergeMaskedNotificationChannelConfigSecretsPreservesExisting(t *testing.T) {
	existing := []models.NotificationChannelConfig{
		{ID: "feishu-sim3", Type: "feishu", Config: map[string]interface{}{"secretKey": "old-token", "signSecret": "old-sign"}},
	}
	incoming := []models.NotificationChannelConfig{
		{ID: "feishu-sim3", Type: "feishu", Config: map[string]interface{}{"secretKey": maskedNotificationSecret, "signSecret": "new-sign"}},
	}

	merged := mergeMaskedNotificationChannelConfigSecrets(incoming, existing)
	if merged[0].Config["secretKey"] != "old-token" {
		t.Fatalf("expected old secret to be preserved, got %#v", merged[0].Config)
	}
	if merged[0].Config["signSecret"] != "new-sign" {
		t.Fatalf("expected changed sign secret to be saved, got %#v", merged[0].Config)
	}
}
