#!/usr/bin/env bash
set -euo pipefail

REPO="tyvqin/uart_sms_forwarder"
TAG="v0.1.5-jays-status-call"
ASSET="uart_sms_forwarder-linux-amd64-jays-status-call.tar.gz"

echo "Applying Jay's SMS UI, status push, and call notification patch..."

python3 <<'PY'
from pathlib import Path
import re

def write(path, text):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(text, encoding="utf-8")

def replace_go_func(src, signature, body):
    start = src.index(signature)
    brace = src.index("{", start)
    depth = 0
    end = brace
    for i in range(brace, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    return src[:start] + body + src[end:]

write("README.md", "")

p = Path("web/index.html")
if p.exists():
    s = p.read_text(encoding="utf-8")
    s = re.sub(r"<title>.*?</title>", "<title>Jay's SMS</title>", s, flags=re.S)
    p.write_text(s, encoding="utf-8")

write("internal/models/property.go", r'''package models

type Property struct {
	ID        string `gorm:"primaryKey" json:"id"`
	Name      string `json:"name"`
	Value     string `json:"value" gorm:"type:text"`
	CreatedAt int64  `json:"createdAt"`
	UpdatedAt int64  `json:"updatedAt" gorm:"autoUpdateTime:milli"`
}

func (Property) TableName() string {
	return "properties"
}

type NotificationChannelConfig struct {
	ID        string                 `json:"id,omitempty"`
	Name      string                 `json:"name,omitempty"`
	Type      string                 `json:"type"`
	Enabled   bool                   `json:"enabled"`
	DeviceIDs []string               `json:"deviceIds,omitempty"`
	Config    map[string]interface{} `json:"config"`
}

type StatusPushConfig struct {
	Enabled        bool     `json:"enabled"`
	Times          []string `json:"times"`
	ChannelIDs     []string `json:"channelIds,omitempty"`
	IncludeSignal  bool     `json:"includeSignal"`
	IncludeNetwork bool     `json:"includeNetwork"`
	IncludeRuntime bool     `json:"includeRuntime"`
	IncludeSim     bool     `json:"includeSim"`
}

type CallNotificationConfig struct {
	Enabled    bool     `json:"enabled"`
	ChannelIDs []string `json:"channelIds,omitempty"`
}

type WebhookConfig struct {
	URL          string            `json:"url"`
	Method       string            `json:"method,omitempty"`
	Headers      map[string]string `json:"headers,omitempty"`
	BodyTemplate string            `json:"bodyTemplate,omitempty"`
	CustomBody   string            `json:"customBody,omitempty"`
}
''')

write("internal/handler/property_handler.go", r'''package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/dushixiang/uart_sms_forwarder/internal/models"
	"github.com/dushixiang/uart_sms_forwarder/internal/service"
	"github.com/labstack/echo/v4"
	"go.uber.org/zap"
)

type PropertyHandler struct {
	logger   *zap.Logger
	service  *service.PropertyService
	notifier *service.Notifier
}

func NewPropertyHandler(logger *zap.Logger, service *service.PropertyService, notifier *service.Notifier) *PropertyHandler {
	return &PropertyHandler{logger: logger, service: service, notifier: notifier}
}

func (h *PropertyHandler) GetProperty(c echo.Context) error {
	id := c.Param("id")
	property, err := h.service.Get(c.Request().Context(), id)
	if err != nil {
		h.logger.Error("get property failed", zap.String("id", id), zap.Error(err))
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "获取配置失败"})
	}

	var value interface{}
	if property.Value != "" {
		if id == service.PropertyIDNotificationChannels {
			var channels []models.NotificationChannelConfig
			if err := json.Unmarshal([]byte(property.Value), &channels); err != nil {
				return c.JSON(http.StatusInternalServerError, map[string]string{"error": "解析通知渠道配置失败"})
			}
			value = redactNotificationChannelsForResponse(service.NormalizeNotificationChannelConfigs(channels))
		} else if err := json.Unmarshal([]byte(property.Value), &value); err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "解析配置失败"})
		}
	}

	return c.JSON(http.StatusOK, map[string]interface{}{"id": property.ID, "name": property.Name, "value": value})
}

func (h *PropertyHandler) SetProperty(c echo.Context) error {
	id := c.Param("id")
	var req struct {
		Name  string      `json:"name"`
		Value interface{} `json:"value"`
	}
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "请求参数无效"})
	}

	if id == service.PropertyIDNotificationChannels {
		raw, err := json.Marshal(req.Value)
		if err != nil {
			return c.JSON(http.StatusBadRequest, map[string]string{"error": "通知渠道配置无效"})
		}
		var channels []models.NotificationChannelConfig
		if err := json.Unmarshal(raw, &channels); err != nil {
			return c.JSON(http.StatusBadRequest, map[string]string{"error": "通知渠道配置无效"})
		}
		channels = h.mergeMaskedNotificationChannelSecrets(c.Request().Context(), channels)
		req.Value = service.NormalizeNotificationChannelConfigs(channels)
	}

	if err := h.service.Set(c.Request().Context(), id, req.Name, req.Value); err != nil {
		h.logger.Error("set property failed", zap.String("id", id), zap.Error(err))
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "保存配置失败"})
	}
	return c.JSON(http.StatusOK, map[string]string{"message": "保存成功"})
}

func (h *PropertyHandler) TestNotificationChannel(c echo.Context) error {
	channelType := strings.TrimSpace(c.Param("type"))
	channelID := strings.TrimSpace(c.QueryParam("channelId"))
	if channelType == "" || channelID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "缺少渠道类型或渠道 ID"})
	}

	ctx := c.Request().Context()
	channels, err := h.service.GetNotificationChannelConfigs(ctx)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "获取通知渠道配置失败"})
	}

	targetChannel := selectNotificationChannelForTest(channels, channelType, channelID)
	if targetChannel == nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "通知渠道不存在"})
	}
	if !targetChannel.Enabled {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "通知渠道未启用"})
	}

	msg := service.NotificationMessage{Type: "test", From: "Jay's SMS", Content: "这是一条测试通知消息", Timestamp: time.Now().Unix()}
	if err := service.SendNotificationByChannel(ctx, h.notifier, *targetChannel, msg); err != nil {
		h.logger.Error("send test notification failed", zap.String("channel_id", channelID), zap.Error(err))
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "发送测试通知失败: " + err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]string{"message": "测试通知已发送"})
}

func selectNotificationChannelForTest(channels []models.NotificationChannelConfig, channelType, channelID string) *models.NotificationChannelConfig {
	channelType = strings.TrimSpace(channelType)
	channelID = strings.TrimSpace(channelID)
	if channelID == "" {
		return nil
	}
	for i := range channels {
		if channels[i].ID == channelID && channels[i].Type == channelType {
			return &channels[i]
		}
	}
	return nil
}

const maskedNotificationSecret = "********"

func redactNotificationChannelsForResponse(channels []models.NotificationChannelConfig) []models.NotificationChannelConfig {
	redacted := make([]models.NotificationChannelConfig, 0, len(channels))
	for _, channel := range channels {
		channel.Config = cloneNotificationConfig(channel.Config)
		for _, key := range notificationSensitiveKeys(channel.Type) {
			if strings.TrimSpace(stringConfigValueForMask(channel.Config, key)) != "" {
				channel.Config[key] = maskedNotificationSecret
			}
		}
		redacted = append(redacted, channel)
	}
	return redacted
}

func (h *PropertyHandler) mergeMaskedNotificationChannelSecrets(ctx context.Context, channels []models.NotificationChannelConfig) []models.NotificationChannelConfig {
	existing, err := h.service.GetNotificationChannelConfigs(ctx)
	if err != nil {
		existing = nil
	}
	return mergeMaskedNotificationChannelConfigSecrets(channels, existing)
}

func mergeMaskedNotificationChannelConfigSecrets(incoming, existing []models.NotificationChannelConfig) []models.NotificationChannelConfig {
	existingByID := make(map[string]models.NotificationChannelConfig, len(existing))
	for _, channel := range existing {
		if strings.TrimSpace(channel.ID) != "" {
			existingByID[channel.ID] = channel
		}
	}

	merged := make([]models.NotificationChannelConfig, 0, len(incoming))
	for _, channel := range incoming {
		oldChannel, hasOld := existingByID[channel.ID]
		channel.Config = cloneNotificationConfig(channel.Config)
		for _, key := range notificationSensitiveKeys(channel.Type) {
			if !isMaskedNotificationSecret(channel.Config[key]) {
				continue
			}
			if hasOld && oldChannel.Config != nil {
				if oldValue, ok := oldChannel.Config[key]; ok {
					channel.Config[key] = oldValue
					continue
				}
			}
			delete(channel.Config, key)
		}
		merged = append(merged, channel)
	}
	return merged
}

func cloneNotificationConfig(config map[string]interface{}) map[string]interface{} {
	clone := make(map[string]interface{}, len(config))
	for key, value := range config {
		clone[key] = value
	}
	return clone
}

func notificationSensitiveKeys(channelType string) []string {
	switch channelType {
	case "dingtalk", "feishu":
		return []string{"secretKey", "signSecret"}
	case "wecom":
		return []string{"secretKey"}
	case "email":
		return []string{"password"}
	case "telegram":
		return []string{"apiToken", "proxyPassword"}
	default:
		return []string{"secretKey", "signSecret", "password", "apiToken", "proxyPassword"}
	}
}

func isMaskedNotificationSecret(value interface{}) bool {
	text, ok := value.(string)
	return ok && strings.TrimSpace(text) == maskedNotificationSecret
}

func stringConfigValueForMask(config map[string]interface{}, key string) string {
	if config == nil {
		return ""
	}
	text, _ := config[key].(string)
	return text
}
''')

write("internal/handler/property_handler_test.go", r'''package handler

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
	channels := []models.NotificationChannelConfig{{ID: "shared-id", Type: "feishu"}}
	if selected := selectNotificationChannelForTest(channels, "dingtalk", "shared-id"); selected != nil {
		t.Fatalf("expected nil for mismatched type, got %#v", selected)
	}
}

func TestSelectNotificationChannelForTestRequiresChannelID(t *testing.T) {
	channels := []models.NotificationChannelConfig{{ID: "dingtalk-sim1", Type: "dingtalk"}}
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
''')

write("internal/service/property_extra.go", r'''package service

import (
	"context"
	"regexp"
	"sort"
	"strings"

	"github.com/dushixiang/uart_sms_forwarder/internal/models"
)

const (
	PropertyIDStatusPushConfig       = "status_push_config"
	PropertyIDCallNotificationConfig = "call_notification_config"
)

var statusPushTimePattern = regexp.MustCompile(`^\d{2}:\d{2}$`)

func DefaultStatusPushConfig() models.StatusPushConfig {
	return models.StatusPushConfig{
		Enabled:        false,
		Times:          []string{"09:00"},
		ChannelIDs:     []string{},
		IncludeSignal:  true,
		IncludeNetwork: true,
		IncludeRuntime: true,
		IncludeSim:     true,
	}
}

func DefaultCallNotificationConfig() models.CallNotificationConfig {
	return models.CallNotificationConfig{Enabled: false, ChannelIDs: []string{}}
}

func (s *PropertyService) GetStatusPushConfig(ctx context.Context) (models.StatusPushConfig, error) {
	cfg := DefaultStatusPushConfig()
	_ = s.GetValue(ctx, PropertyIDStatusPushConfig, &cfg)
	return NormalizeStatusPushConfig(cfg), nil
}

func (s *PropertyService) GetCallNotificationConfig(ctx context.Context) (models.CallNotificationConfig, error) {
	cfg := DefaultCallNotificationConfig()
	_ = s.GetValue(ctx, PropertyIDCallNotificationConfig, &cfg)
	cfg.ChannelIDs = normalizeIDList(cfg.ChannelIDs)
	return cfg, nil
}

func NormalizeStatusPushConfig(cfg models.StatusPushConfig) models.StatusPushConfig {
	times := make([]string, 0, len(cfg.Times))
	seen := map[string]struct{}{}
	for _, value := range cfg.Times {
		value = strings.TrimSpace(value)
		if !statusPushTimePattern.MatchString(value) {
			continue
		}
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		times = append(times, value)
	}
	sort.Strings(times)
	if len(times) == 0 {
		times = []string{"09:00"}
	}
	cfg.Times = times
	cfg.ChannelIDs = normalizeIDList(cfg.ChannelIDs)
	return cfg
}

func normalizeIDList(ids []string) []string {
	seen := map[string]struct{}{}
	out := make([]string, 0, len(ids))
	for _, id := range ids {
		id = strings.TrimSpace(id)
		if id == "" {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		out = append(out, id)
	}
	return out
}
''')

# Add the two new properties to default initialization.
p = Path("internal/service/property_service.go")
s = p.read_text(encoding="utf-8")
needle = '''{
\t\t\tID:    PropertyIDNotificationChannels,
\t\t\tName:  "通知渠道配置",
\t\t\tValue: []models.NotificationChannelConfig{},
\t\t},'''
if needle in s and "PropertyIDStatusPushConfig" not in s:
    s = s.replace(needle, needle + '''
\t\t{
\t\t\tID:    PropertyIDStatusPushConfig,
\t\t\tName:  "设备状态推送配置",
\t\t\tValue: DefaultStatusPushConfig(),
\t\t},
\t\t{
\t\t\tID:    PropertyIDCallNotificationConfig,
\t\t\tName:  "来电通知配置",
\t\t\tValue: DefaultCallNotificationConfig(),
\t\t},''')
else:
    # Works on mojibake/comment-damaged copies too: insert after the notification channel default by value line.
    s = s.replace('Value: []models.NotificationChannelConfig{},\n\t\t},', 'Value: []models.NotificationChannelConfig{},\n\t\t},\n\t\t{\n\t\t\tID:    PropertyIDStatusPushConfig,\n\t\t\tName:  "设备状态推送配置",\n\t\t\tValue: DefaultStatusPushConfig(),\n\t\t},\n\t\t{\n\t\t\tID:    PropertyIDCallNotificationConfig,\n\t\t\tName:  "来电通知配置",\n\t\t\tValue: DefaultCallNotificationConfig(),\n\t\t},', 1)
p.write_text(s, encoding="utf-8")

write("internal/service/notification_dispatch.go", r'''package service

import (
	"context"

	"github.com/dushixiang/uart_sms_forwarder/internal/models"
)

func SendNotificationByChannel(ctx context.Context, notifier *Notifier, channel models.NotificationChannelConfig, msg NotificationMessage) error {
	message := msg.String()
	switch channel.Type {
	case "dingtalk":
		return notifier.SendDingTalkByConfig(ctx, channel.Config, message)
	case "wecom":
		return notifier.SendWeComByConfig(ctx, channel.Config, message)
	case "feishu":
		return notifier.SendFeishuByConfig(ctx, channel.Config, message)
	case "webhook":
		return notifier.SendWebhookByConfig(ctx, channel.Config, msg)
	case "email":
		return notifier.SendEmail(ctx, channel.Config, msg)
	case "telegram":
		return notifier.sendTelegramByConfig(ctx, channel.Config, message)
	default:
		return nil
	}
}

func notificationChannelSelected(channelID string, selectedIDs []string) bool {
	if len(selectedIDs) == 0 {
		return true
	}
	for _, id := range selectedIDs {
		if id == channelID {
			return true
		}
	}
	return false
}
''')

# Make NotificationMessage support status/test content without changing existing SMS formatting.
p = Path("internal/service/notifier.go")
s = p.read_text(encoding="utf-8")
if 'case "status":' not in s:
    s = s.replace('switch m.Type {\n\tcase "call":', 'switch m.Type {\n\tcase "status", "test":\n\t\treturn m.Content\n\tcase "call":', 1)
p.write_text(s, encoding="utf-8")

write("internal/service/privacy_log.go", r'''package service

import "strings"

func maskForLog(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	runes := []rune(value)
	if len(runes) <= 4 {
		return "***"
	}
	if len(runes) <= 8 {
		return string(runes[:1]) + "***" + string(runes[len(runes)-1:])
	}
	return string(runes[:3]) + "***" + string(runes[len(runes)-4:])
}

func commandAction(cmd any) string {
	switch value := cmd.(type) {
	case map[string]any:
		if action, ok := value["action"].(string); ok {
			return action
		}
	case map[string]string:
		return value["action"]
	}
	return "unknown"
}
''')

p = Path("internal/service/serial_service.go")
s = p.read_text(encoding="utf-8")
if "lastIncomingCall" not in s:
    s = s.replace("\tpropertyService            *PropertyService\n", "\tpropertyService            *PropertyService\n\tlastIncomingCall           *IncomingCall\n", 1)
s = re.sub(r'\n\s*s\.logger\.Sugar\(\)\.Debugf\("received data: %s", data\)\n\s*msg, err := parseSMSFrame\(data\)', "\n\tmsg, err := parseSMSFrame(data)", s, count=1)
s = re.sub(r's\.logger\.Warn\([^,\n]*,\s*zap\.String\("data", data\)\)', 's.logger.Warn("message type missing")', s, count=1)
if 'received serial frame' not in s:
    s = s.replace("\ts.routeMessage(msg)\n}", "\ts.logger.Debug(\"received serial frame\", zap.String(\"type\", msg.Type))\n\ts.routeMessage(msg)\n}", 1)
s = s.replace("message, jsonData, err := buildCommandMessage(cmd)", "message, _, err := buildCommandMessage(cmd)")
s = re.sub(r'\n\s*s\.logger\.Sugar\(\)\.Debugf\("send command: %s", jsonData\)', '\n\ts.logger.Debug("send command", zap.String("action", commandAction(cmd)))', s, count=1)
s = s.replace('zap.String("to", to)', 'zap.String("to", maskForLog(to))')
p.write_text(s, encoding="utf-8")

write("internal/service/serial_handlers_call.go", r'''package service

import (
	"context"
	"encoding/json"
	"time"

	"go.uber.org/zap"
)

type IncomingCall struct {
	Timestamp int64  `json:"timestamp"`
	From      string `json:"from"`
	Type      string `json:"type"`
}

func (s *SerialService) handleIncomingCall(msg *ParsedMessage) {
	var call IncomingCall
	if err := json.Unmarshal([]byte(msg.JSON), &call); err != nil {
		s.logger.Error("incoming call parse failed", zap.Error(err))
		return
	}
	if call.Timestamp == 0 {
		call.Timestamp = time.Now().Unix()
	}

	s.mu.Lock()
	s.lastIncomingCall = &call
	s.mu.Unlock()

	s.logger.Info("incoming call detected",
		zap.String("device_id", s.deviceID),
		zap.String("from", maskForLog(call.From)),
		zap.Int64("timestamp", call.Timestamp))
}

func (s *SerialService) handleCallDisconnected(msg *ParsedMessage) {
	timestamp, _ := msg.Payload["timestamp"].(float64)
	if timestamp == 0 {
		timestamp = float64(time.Now().Unix())
	}

	s.mu.Lock()
	call := s.lastIncomingCall
	s.lastIncomingCall = nil
	s.mu.Unlock()

	s.logger.Info("call disconnected", zap.Int64("timestamp", int64(timestamp)))
	if call == nil {
		return
	}

	cfg, err := s.propertyService.GetCallNotificationConfig(context.Background())
	if err != nil {
		s.logger.Warn("get call notification config failed", zap.Error(err))
		return
	}
	if !cfg.Enabled {
		return
	}

	notifMsg := buildCallNotificationMessage(*call, s.deviceID, s.deviceName, int64(timestamp))
	go s.sendNotificationMessageToChannels(context.Background(), notifMsg, cfg.ChannelIDs)
}

func buildCallNotificationMessage(call IncomingCall, deviceID, deviceName string, disconnectedAt int64) NotificationMessage {
	return NotificationMessage{
		Type:       "call",
		DeviceID:   deviceID,
		DeviceName: deviceName,
		From:       call.From,
		Content:    "",
		Timestamp:  disconnectedAt,
	}
}
''')

p = Path("internal/service/serial_handlers_sms.go")
s = p.read_text(encoding="utf-8")
s = s.replace('zap.String("from", sms.From),\n\t\tzap.String("content", sms.Content),', 'zap.String("from", maskForLog(sms.From)),\n\t\tzap.Int("content_length", len([]rune(sms.Content))),')
s = s.replace('zap.String("to", to)', 'zap.String("to", maskForLog(to))')
start = s.index("func (s *SerialService) sendNotificationMessage")
end = s.index("// handleSMSSendResult", start)
s = s[:start] + r'''func (s *SerialService) sendNotificationMessage(ctx context.Context, msg NotificationMessage) {
	s.sendNotificationMessageToChannels(ctx, msg, nil)
}

func (s *SerialService) sendNotificationMessageToChannels(ctx context.Context, msg NotificationMessage, channelIDs []string) {
	channels, err := s.propertyService.GetNotificationChannelConfigs(ctx)
	if err != nil {
		s.logger.Error("get notification channel config failed", zap.Error(err))
		return
	}

	for _, channel := range channels {
		if !notificationChannelSelected(channel.ID, channelIDs) || !notificationChannelCanReceive(channel, msg.DeviceID) {
			continue
		}

		sendErr := SendNotificationByChannel(ctx, s.notifier, channel, msg)
		if sendErr != nil {
			s.logger.Error("send notification failed",
				zap.String("device_id", msg.DeviceID),
				zap.String("channel_id", channel.ID),
				zap.String("type", channel.Type),
				zap.Error(sendErr))
		} else {
			s.logger.Info("notification sent",
				zap.String("device_id", msg.DeviceID),
				zap.String("channel_id", channel.ID),
				zap.String("type", channel.Type))
		}
	}
}

''' + s[end:]
s = re.sub(r'\nfunc notificationChannelMatchesDevice\(deviceIDs \[\]string, deviceID string\) bool \{.*?\n\}', r'''
func notificationChannelCanReceive(channel models.NotificationChannelConfig, deviceID string) bool {
	return channel.Enabled && notificationChannelMatchesDevice(channel.DeviceIDs, deviceID)
}

func notificationChannelMatchesDevice(deviceIDs []string, deviceID string) bool {
	if len(deviceIDs) == 0 {
		return true
	}
	deviceID = strings.TrimSpace(deviceID)
	for _, id := range deviceIDs {
		if strings.TrimSpace(id) == deviceID {
			return true
		}
	}
	return false
}
''', s, flags=re.S)
p.write_text(s, encoding="utf-8")

write("internal/service/notification_filter_test.go", r'''package service

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
''')

p = Path("internal/service/scheduler_service.go")
s = p.read_text(encoding="utf-8")
if '"sync"' not in s:
    s = s.replace('"fmt"\n\t"time"', '"fmt"\n\t"sync"\n\t"time"', 1)
if "propertyService" not in s.split("type SchedulerService struct", 1)[1].split("}", 1)[0]:
    s = s.replace("\tserialManager *SerialManager\n", "\tserialManager *SerialManager\n\tpropertyService *PropertyService\n\tnotifier *Notifier\n\tstatusPushMu sync.Mutex\n\tstatusPushLastSent map[string]struct{}\n", 1)
s = s.replace("serialManager *SerialManager,\n) *SchedulerService", "serialManager *SerialManager,\n\tpropertyService *PropertyService,\n\tnotifier *Notifier,\n) *SchedulerService", 1)
s = s.replace("serialManager: serialManager,\n\t}", "serialManager: serialManager,\n\t\tpropertyService: propertyService,\n\t\tnotifier: notifier,\n\t\tstatusPushLastSent: make(map[string]struct{}),\n\t}", 1)
if "startStatusPushLoop" not in s:
    s = s.replace("\ts.cron.Start()\n", "\ts.cron.Start()\n\tgo s.startStatusPushLoop(ctx)\n", 1)
p.write_text(s, encoding="utf-8")

write("internal/service/status_push_service.go", r'''package service

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/dushixiang/uart_sms_forwarder/internal/models"
	"go.uber.org/zap"
)

func (s *SchedulerService) startStatusPushLoop(ctx context.Context) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-ticker.C:
			if err := s.checkAndSendStatusPush(ctx, now); err != nil {
				s.logger.Warn("status push check failed", zap.Error(err))
			}
		}
	}
}

func (s *SchedulerService) checkAndSendStatusPush(ctx context.Context, now time.Time) error {
	cfg, err := s.propertyService.GetStatusPushConfig(ctx)
	if err != nil || !cfg.Enabled {
		return err
	}
	current := now.Format("15:04")
	for _, scheduled := range cfg.Times {
		if scheduled != current {
			continue
		}
		key := now.Format("2006-01-02") + " " + scheduled
		s.statusPushMu.Lock()
		if _, ok := s.statusPushLastSent[key]; ok {
			s.statusPushMu.Unlock()
			return nil
		}
		s.statusPushLastSent[key] = struct{}{}
		s.statusPushMu.Unlock()
		return s.sendStatusPush(ctx, cfg, now)
	}
	return nil
}

func (s *SchedulerService) TriggerStatusPush(ctx context.Context) error {
	cfg, err := s.propertyService.GetStatusPushConfig(ctx)
	if err != nil {
		return err
	}
	return s.sendStatusPush(ctx, cfg, time.Now())
}

func (s *SchedulerService) sendStatusPush(ctx context.Context, cfg models.StatusPushConfig, now time.Time) error {
	statuses, err := s.serialManager.GetAllStatus()
	if err != nil {
		return err
	}
	channels, err := s.propertyService.GetNotificationChannelConfigs(ctx)
	if err != nil {
		return err
	}
	sent := 0
	var lastErr error
	for _, channel := range channels {
		if !channel.Enabled || !notificationChannelSelected(channel.ID, cfg.ChannelIDs) {
			continue
		}
		scopedStatuses := filterStatusesForChannel(statuses, channel)
		if len(scopedStatuses) == 0 {
			continue
		}
		msg := NotificationMessage{
			Type:      "status",
			From:      "Jay's SMS",
			Content:   formatStatusPushMessage(scopedStatuses, cfg, now),
			Timestamp: now.Unix(),
		}
		if err := SendNotificationByChannel(ctx, s.notifier, channel, msg); err != nil {
			lastErr = err
			s.logger.Error("status push failed", zap.String("channel_id", channel.ID), zap.Error(err))
			continue
		}
		sent++
		s.logger.Info("status push sent", zap.String("channel_id", channel.ID))
	}
	if sent == 0 {
		if lastErr != nil {
			return lastErr
		}
		return fmt.Errorf("没有可用的通知渠道")
	}
	return nil
}

func filterStatusesForChannel(statuses []*StatusData, channel models.NotificationChannelConfig) []*StatusData {
	filtered := make([]*StatusData, 0, len(statuses))
	for _, status := range statuses {
		if status == nil {
			continue
		}
		if notificationChannelMatchesDevice(channel.DeviceIDs, status.DeviceID) {
			filtered = append(filtered, status)
		}
	}
	return filtered
}

func formatStatusPushMessage(statuses []*StatusData, cfg models.StatusPushConfig, now time.Time) string {
	var b strings.Builder
	b.WriteString("Jay's SMS 设备状态\n")
	b.WriteString("时间: " + now.Format(time.DateTime) + "\n")
	for _, status := range statuses {
		name := status.DeviceName
		if name == "" {
			name = status.DeviceID
		}
		online := "离线"
		if status.Connected {
			online = "在线"
		}
		b.WriteString("\n")
		b.WriteString(name + ": " + online)
		if status.Flymode {
			b.WriteString(" / 飞行模式")
		}
		b.WriteString("\n")
		if cfg.IncludeSim {
			sim := "未就绪"
			if status.Mobile.SimReady {
				sim = "已就绪"
			}
			b.WriteString("SIM: " + sim + "\n")
		}
		if cfg.IncludeNetwork {
			registered := "未注册"
			if status.Mobile.IsRegistered {
				registered = "已注册"
			}
			operator := status.Mobile.Operator
			if operator == "" {
				operator = "未知运营商"
			}
			roaming := "否"
			if status.Mobile.IsRoaming {
				roaming = "是"
			}
			b.WriteString(fmt.Sprintf("网络: %s / %s / 漫游:%s\n", registered, operator, roaming))
		}
		if cfg.IncludeSignal {
			desc := status.Mobile.SignalDesc
			if desc == "" {
				desc = "未知"
			}
			b.WriteString(fmt.Sprintf("信号: %s / CSQ:%d / RSRP:%d / RSRQ:%.1f\n", desc, status.Mobile.Csq, status.Mobile.Rsrp, status.Mobile.Rsrq))
		}
		if cfg.IncludeRuntime && status.Mobile.Uptime > 0 {
			b.WriteString("运行: " + formatDurationSeconds(status.Mobile.Uptime) + "\n")
		}
	}
	return strings.TrimSpace(b.String())
}

func formatDurationSeconds(seconds int64) string {
	days := seconds / 86400
	hours := (seconds % 86400) / 3600
	minutes := (seconds % 3600) / 60
	if days > 0 {
		return fmt.Sprintf("%dd %dh %dm", days, hours, minutes)
	}
	if hours > 0 {
		return fmt.Sprintf("%dh %dm", hours, minutes)
	}
	return fmt.Sprintf("%dm", minutes)
}
''')

write("internal/service/status_push_test.go", r'''package service

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
''')

p = Path("internal/app.go")
s = p.read_text(encoding="utf-8")
s = s.replace("serialManager,\n\t)", "serialManager,\n\t\tpropertyService,\n\t\tnotifier,\n\t)", 1)
if 'api.POST("/status-push/test"' not in s:
    s = s.replace('api.POST("/scheduled-tasks/:id/trigger", handlers.ScheduledTask.Trigger)', 'api.POST("/scheduled-tasks/:id/trigger", handlers.ScheduledTask.Trigger)\n\tapi.POST("/status-push/test", handlers.ScheduledTask.TestStatusPush)', 1)
p.write_text(s, encoding="utf-8")

p = Path("internal/handler/scheduled_task_handler.go")
s = p.read_text(encoding="utf-8")
if "TestStatusPush" not in s:
    insert = r'''

func (h *ScheduledTaskHandler) TestStatusPush(c echo.Context) error {
	if err := h.schedulerService.TriggerStatusPush(c.Request().Context()); err != nil {
		h.logger.Error("trigger status push failed", zap.Error(err))
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "设备状态测试推送失败: " + err.Error()})
	}
	return c.JSON(http.StatusOK, map[string]string{"message": "设备状态测试推送已发送"})
}
'''
    s = s.replace("\n// validateTask", insert + "\n// validateTask", 1)
p.write_text(s, encoding="utf-8")

write("web/src/api/property.ts", r'''import apiClient from "@/api/client.ts";

export interface PropertyResponse<T> {
    id: string;
    name: string;
    value: T;
}

export const getProperty = async <T>(propertyId: string): Promise<T> => {
    const response = await apiClient.get<PropertyResponse<T>>(`/properties/${propertyId}`);
    return response.value;
};

export const saveProperty = async <T>(propertyId: string, name: string, value: T): Promise<void> => {
    await apiClient.put(`/properties/${propertyId}`, {name, value});
};

const PROPERTY_ID_NOTIFICATION_CHANNELS = 'notification_channels';
const PROPERTY_ID_STATUS_PUSH_CONFIG = 'status_push_config';
const PROPERTY_ID_CALL_NOTIFICATION_CONFIG = 'call_notification_config';

export interface NotificationChannel {
    id?: string;
    name?: string;
    type: 'dingtalk' | 'wecom' | 'feishu' | 'email' | 'webhook' | 'telegram';
    enabled: boolean;
    deviceIds?: string[];
    config: Record<string, any>;
}

export interface StatusPushConfig {
    enabled: boolean;
    times: string[];
    channelIds?: string[];
    includeSignal: boolean;
    includeNetwork: boolean;
    includeRuntime: boolean;
    includeSim: boolean;
}

export interface CallNotificationConfig {
    enabled: boolean;
    channelIds?: string[];
}

export const getNotificationChannels = async (): Promise<NotificationChannel[]> => {
    const channels = await getProperty<NotificationChannel[]>(PROPERTY_ID_NOTIFICATION_CHANNELS);
    return channels || [];
};

export const saveNotificationChannels = async (channels: NotificationChannel[]): Promise<void> => {
    return saveProperty(PROPERTY_ID_NOTIFICATION_CHANNELS, '通知渠道配置', channels);
};

export const testNotificationChannel = async (channel: Pick<NotificationChannel, 'id' | 'type'>): Promise<{ message: string }> => {
    return apiClient.post<{ message: string }>(`/notifications/${channel.type}/test`, null, {
        params: {channelId: channel.id},
    });
};

export const getStatusPushConfig = async (): Promise<StatusPushConfig> => {
    const config = await getProperty<StatusPushConfig>(PROPERTY_ID_STATUS_PUSH_CONFIG);
    return config || defaultStatusPushConfig();
};

export const saveStatusPushConfig = async (config: StatusPushConfig): Promise<void> => {
    return saveProperty(PROPERTY_ID_STATUS_PUSH_CONFIG, '设备状态推送配置', config);
};

export const testStatusPush = async (): Promise<{ message: string }> => {
    return apiClient.post<{ message: string }>('/status-push/test');
};

export const getCallNotificationConfig = async (): Promise<CallNotificationConfig> => {
    const config = await getProperty<CallNotificationConfig>(PROPERTY_ID_CALL_NOTIFICATION_CONFIG);
    return config || {enabled: false, channelIds: []};
};

export const saveCallNotificationConfig = async (config: CallNotificationConfig): Promise<void> => {
    return saveProperty(PROPERTY_ID_CALL_NOTIFICATION_CONFIG, '来电通知配置', config);
};

export const defaultStatusPushConfig = (): StatusPushConfig => ({
    enabled: false,
    times: ['09:00'],
    channelIds: [],
    includeSignal: true,
    includeNetwork: true,
    includeRuntime: true,
    includeSim: true,
});

export interface Version {
    version: string;
}

export const getVersion = () => apiClient.get<Version>('/version');
''')

write("web/src/components/Layout.tsx", r'''import {Link, Outlet, useLocation, useNavigate} from 'react-router-dom';
import {Bell, Clock, LayoutDashboard, LogOut, MessageSquare, Smartphone} from 'lucide-react';
import {Button} from "@/components/ui/button.tsx";
import {useQuery} from "@tanstack/react-query";
import {getVersion} from "@/api/property.ts";
import {getDevices} from "@/api/serial.ts";
import type {SerialDeviceInfo} from "@/api/types.ts";
import {cn} from "@/lib/utils.ts";
import {toast} from 'sonner';

export default function Layout() {
    const location = useLocation();
    const navigate = useNavigate();

    const navigation = [
        {name: '统计', href: '/', icon: LayoutDashboard},
        {name: '短信', href: '/messages', icon: MessageSquare},
        {name: '串口', href: '/serial', icon: Smartphone},
        {name: '通知', href: '/notifications', icon: Bell},
        {name: '计划', href: '/scheduled-tasks', icon: Clock},
    ];

    const versionQuery = useQuery({queryKey: ['version'], queryFn: getVersion});
    const {data: devices = []} = useQuery<SerialDeviceInfo[]>({
        queryKey: ['serialDevices'],
        queryFn: getDevices,
        refetchInterval: 10000,
    });

    const onlineCount = devices.filter((device) => device.connected).length;
    const firstOnline = devices.find((device) => device.connected);
    const totalCount = devices.length;
    const onlineText = totalCount > 1 ? `${onlineCount}/${totalCount} 在线` : (onlineCount ? '在线' : '离线');
    const shortDevice = firstOnline ? (firstOnline.name || firstOnline.id.toUpperCase()) : '无设备';

    const isActive = (path: string) => path === '/' ? location.pathname === '/' : location.pathname.startsWith(path);

    const handleLogout = () => {
        localStorage.removeItem('token');
        localStorage.removeItem('username');
        toast.success('已退出登录');
        navigate('/login');
    };

    return (
        <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 flex flex-col">
            <nav className="bg-white/95 backdrop-blur-sm border-b border-gray-200 sticky top-0 z-50">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                    <div className="flex justify-between h-16">
                        <div className="flex items-center space-x-4 lg:space-x-8">
                            <div className="flex items-center space-x-2 lg:space-x-3 flex-shrink-0">
                                <img src="/logo.png" alt="Jay's SMS" className="w-6 h-6"/>
                                <div className="hidden sm:flex flex-col">
                                    <h1 className="text-base lg:text-lg font-bold leading-tight bg-gradient-to-r from-gray-900 to-gray-700 bg-clip-text text-transparent">
                                        Jay's SMS
                                    </h1>
                                </div>
                            </div>

                            <div className="hidden md:flex items-center space-x-1">
                                {navigation.map((item) => {
                                    const Icon = item.icon;
                                    const active = isActive(item.href);
                                    return (
                                        <Link
                                            key={item.name}
                                            to={item.href}
                                            className={`px-2 lg:px-3 xl:px-4 py-2 flex items-center space-x-1 lg:space-x-2 rounded-lg transition-all duration-200 font-medium text-xs lg:text-sm whitespace-nowrap ${
                                                active ? 'bg-blue-50 text-blue-600' : 'text-gray-500 hover:bg-gray-100 hover:text-gray-900'
                                            }`}
                                        >
                                            <Icon className="w-4 h-4 flex-shrink-0"/>
                                            <span className="hidden lg:inline">{item.name}</span>
                                        </Link>
                                    );
                                })}
                            </div>
                        </div>

                        <div className="hidden md:flex items-center space-x-2 lg:space-x-4">
                            <div className="min-w-0 rounded-lg border border-gray-100 bg-gray-50 px-3 py-1.5">
                                <div className="flex items-center gap-2">
                                    <div className={cn("w-2 h-2 rounded-full", onlineCount > 0 ? 'bg-green-500' : 'bg-red-500')}/>
                                    <div className="text-xs font-semibold text-gray-700">{onlineText}</div>
                                </div>
                                <div className="max-w-24 truncate text-[10px] text-gray-400 mt-0.5">{shortDevice}</div>
                            </div>

                            <Button variant="ghost" size="sm" onClick={handleLogout} className="text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg">
                                <LogOut className="w-4 h-4 mr-2"/>
                                登出
                            </Button>
                        </div>

                        <div className="flex md:hidden items-center space-x-2">
                            <div className={cn("flex items-center space-x-1 px-2 py-1 rounded-lg", onlineCount > 0 ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700')}>
                                <div className={cn("w-2 h-2 rounded-full", onlineCount > 0 ? 'bg-green-500' : 'bg-red-500')}/>
                                <span className="text-xs font-medium">{onlineText}</span>
                            </div>
                            <Button variant="ghost" size="sm" onClick={handleLogout} className="text-gray-600">
                                <LogOut className="w-4 h-4"/>
                            </Button>
                        </div>
                    </div>
                </div>

                <div className="md:hidden border-t border-gray-200 bg-white">
                    <div className="flex justify-around py-2">
                        {navigation.map((item) => {
                            const Icon = item.icon;
                            const active = isActive(item.href);
                            return (
                                <Link key={item.name} to={item.href} className={`flex flex-col items-center px-3 py-2 text-xs font-medium transition-all duration-200 ${active ? 'text-blue-600' : 'text-gray-500'}`}>
                                    <Icon className={`w-6 h-6 mb-1 transition-transform ${active ? 'scale-110' : ''}`}/>
                                    <span className={active ? 'font-semibold' : ''}>{item.name}</span>
                                </Link>
                            );
                        })}
                    </div>
                </div>
            </nav>

            <main className="flex-1 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 w-full">
                <Outlet/>
            </main>

            <footer className="bg-white/80 backdrop-blur-sm border-t border-gray-200 mt-auto">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
                    <div className="text-center text-xs text-gray-500">
                        Jay's SMS · 版本 {versionQuery.data?.version || 'dev'}
                    </div>
                </div>
            </footer>
        </div>
    );
}
''')

write("web/src/pages/NotificationChannels.tsx", r'''import {useEffect, useMemo, useState} from 'react';
import {useMutation, useQuery, useQueryClient} from '@tanstack/react-query';
import {Bell, Loader2, PhoneCall, Plus, Radio, Save, TestTube, Trash2} from 'lucide-react';
import {toast} from 'sonner';

import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Textarea} from '@/components/ui/textarea';
import {Card, CardContent, CardDescription, CardHeader, CardTitle} from '@/components/ui/card';
import {getDevices} from '@/api/serial.ts';
import {
    defaultStatusPushConfig,
    getCallNotificationConfig,
    getNotificationChannels,
    getStatusPushConfig,
    type CallNotificationConfig,
    type NotificationChannel,
    saveCallNotificationConfig,
    saveNotificationChannels,
    saveStatusPushConfig,
    type StatusPushConfig,
    testNotificationChannel,
    testStatusPush,
} from '@/api/property.ts';

type ChannelType = NotificationChannel['type'];

const CHANNEL_TYPES: Array<{type: ChannelType; label: string; description: string}> = [
    {type: 'dingtalk', label: '钉钉', description: '钉钉自定义机器人'},
    {type: 'feishu', label: '飞书', description: '飞书自定义机器人'},
    {type: 'wecom', label: '企业微信', description: '企业微信群机器人'},
    {type: 'webhook', label: 'Webhook', description: '自定义 HTTP 推送'},
    {type: 'email', label: '邮件', description: 'SMTP 邮件推送'},
    {type: 'telegram', label: 'Telegram', description: 'Telegram Bot 推送'},
];

const DEFAULT_WEBHOOK_BODY = '{"from":"{{from}}","content":"{{content}}","deviceId":"{{deviceId}}","deviceName":"{{deviceName}}","timestamp":"{{timestamp}}"}';

function channelLabel(type: ChannelType) {
    return CHANNEL_TYPES.find((item) => item.type === type)?.label || type;
}

function defaultConfig(type: ChannelType): Record<string, any> {
    switch (type) {
        case 'webhook':
            return {url: '', method: 'POST', contentType: 'application/json; charset=utf-8', headers: {}, body: DEFAULT_WEBHOOK_BODY};
        case 'email':
            return {smtpHost: '', smtpPort: '587', username: '', password: '', from: '', to: '', subject: 'Jay SMS - {{from}}'};
        case 'telegram':
            return {apiToken: '', userid: '', proxyEnabled: false, proxyUrl: '', proxyUsername: '', proxyPassword: ''};
        default:
            return {secretKey: '', signSecret: ''};
    }
}

function makeChannel(type: ChannelType): NotificationChannel {
    const suffix = Date.now().toString(36);
    return {id: `${type}-${suffix}`, name: channelLabel(type), type, enabled: true, deviceIds: [], config: defaultConfig(type)};
}

function withClientDefaults(channel: NotificationChannel, index: number): NotificationChannel {
    return {
        ...channel,
        id: channel.id || `${channel.type}-${index + 1}`,
        name: channel.name || channelLabel(channel.type),
        deviceIds: channel.deviceIds || [],
        config: {...defaultConfig(channel.type), ...(channel.config || {})},
    };
}

function hasAnyConfigValue(config: Record<string, any>) {
    return Object.values(config).some((value) => {
        if (typeof value === 'string') return value.trim() !== '';
        if (Array.isArray(value)) return value.length > 0;
        if (value && typeof value === 'object') return Object.keys(value).length > 0;
        return Boolean(value);
    });
}

function normalizeForSave(channels: NotificationChannel[]) {
    return channels
        .map((channel, index) => withClientDefaults(channel, index))
        .filter((channel) => channel.enabled || hasAnyConfigValue(channel.config || {}))
        .map((channel) => ({
            ...channel,
            name: (channel.name || channelLabel(channel.type)).trim(),
            deviceIds: Array.from(new Set((channel.deviceIds || []).map((id) => id.trim()).filter(Boolean))),
        }));
}

function normalizeStatusConfig(config: StatusPushConfig): StatusPushConfig {
    const times = Array.from(new Set((config.times || []).map((time) => time.trim()).filter(Boolean))).sort();
    return {
        ...config,
        times: times.length ? times : ['09:00'],
        channelIds: Array.from(new Set(config.channelIds || [])),
    };
}

export default function NotificationChannels() {
    const queryClient = useQueryClient();
    const [draft, setDraft] = useState<NotificationChannel[]>([]);
    const [newType, setNewType] = useState<ChannelType>('dingtalk');
    const [statusDraft, setStatusDraft] = useState<StatusPushConfig>(defaultStatusPushConfig());
    const [callDraft, setCallDraft] = useState<CallNotificationConfig>({enabled: false, channelIds: []});

    const {data: channels = [], isLoading} = useQuery({queryKey: ['notificationChannels'], queryFn: getNotificationChannels});
    const {data: devices = []} = useQuery({queryKey: ['serialDevices'], queryFn: getDevices, refetchInterval: 10000});
    const {data: statusPushConfig} = useQuery({queryKey: ['statusPushConfig'], queryFn: getStatusPushConfig});
    const {data: callConfig} = useQuery({queryKey: ['callNotificationConfig'], queryFn: getCallNotificationConfig});

    useEffect(() => setDraft(channels.map(withClientDefaults)), [channels]);
    useEffect(() => {
        if (statusPushConfig) setStatusDraft(normalizeStatusConfig(statusPushConfig));
    }, [statusPushConfig]);
    useEffect(() => {
        if (callConfig) setCallDraft({enabled: Boolean(callConfig.enabled), channelIds: callConfig.channelIds || []});
    }, [callConfig]);

    const deviceOptions = useMemo(() => devices.map((device) => ({id: device.id, label: device.name || device.id.toUpperCase()})), [devices]);
    const channelOptions = useMemo(() => draft.map((channel, index) => withClientDefaults(channel, index)), [draft]);

    const saveMutation = useMutation({
        mutationFn: async () => {
            await Promise.all([
                saveNotificationChannels(normalizeForSave(draft)),
                saveStatusPushConfig(normalizeStatusConfig(statusDraft)),
                saveCallNotificationConfig({enabled: Boolean(callDraft.enabled), channelIds: Array.from(new Set(callDraft.channelIds || []))}),
            ]);
        },
        onSuccess: async () => {
            toast.success('配置已保存');
            await Promise.all([
                queryClient.invalidateQueries({queryKey: ['notificationChannels']}),
                queryClient.invalidateQueries({queryKey: ['statusPushConfig']}),
                queryClient.invalidateQueries({queryKey: ['callNotificationConfig']}),
            ]);
        },
        onError: (error) => toast.error(`保存失败: ${(error as Error).message}`),
    });

    const testChannelMutation = useMutation({
        mutationFn: testNotificationChannel,
        onSuccess: () => toast.success('测试通知已发送'),
        onError: (error) => toast.error(`测试失败: ${(error as Error).message}`),
    });

    const testStatusPushMutation = useMutation({
        mutationFn: testStatusPush,
        onSuccess: () => toast.success('设备状态测试推送已发送'),
        onError: (error) => toast.error(`测试失败: ${(error as Error).message}`),
    });

    const updateChannel = (index: number, patch: Partial<NotificationChannel>) => {
        setDraft((current) => current.map((channel, i) => i === index ? {...channel, ...patch} : channel));
    };

    const updateConfig = (index: number, key: string, value: any) => {
        setDraft((current) => current.map((channel, i) => i === index ? {...channel, config: {...(channel.config || {}), [key]: value}} : channel));
    };

    const toggleDevice = (index: number, deviceId: string) => {
        setDraft((current) => current.map((channel, i) => {
            if (i !== index) return channel;
            const ids = channel.deviceIds || [];
            return {...channel, deviceIds: ids.includes(deviceId) ? ids.filter((id) => id !== deviceId) : [...ids, deviceId]};
        }));
    };

    const toggleChannelId = (ids: string[] | undefined, channelId: string) => {
        const current = ids || [];
        return current.includes(channelId) ? current.filter((id) => id !== channelId) : [...current, channelId];
    };

    const addChannel = () => setDraft((current) => [...current, makeChannel(newType)]);
    const removeChannel = (index: number) => setDraft((current) => current.filter((_, i) => i !== index));
    const save = () => saveMutation.mutate();
    const testChannel = (channel: NotificationChannel) => {
        const normalized = withClientDefaults(channel, 0);
        testChannelMutation.mutate({id: normalized.id, type: normalized.type});
    };

    const renderDeviceScope = (channel: NotificationChannel, index: number) => {
        const selected = channel.deviceIds || [];
        return (
            <div>
                <div className="mb-2 flex items-center justify-between">
                    <label className="text-xs font-semibold text-gray-600">适用 SIM</label>
                    <Button type="button" variant="outline" size="sm" onClick={() => updateChannel(index, {deviceIds: []})}>全部</Button>
                </div>
                <div className="flex flex-wrap gap-2">
                    {deviceOptions.map((device) => {
                        const checked = selected.includes(device.id);
                        return (
                            <label key={device.id} className={`flex cursor-pointer items-center gap-2 rounded-md border px-3 py-1.5 text-sm ${checked ? 'border-blue-200 bg-blue-50 text-blue-700' : 'border-gray-200 bg-white text-gray-600'}`}>
                                <input type="checkbox" className="h-4 w-4" checked={checked} onChange={() => toggleDevice(index, device.id)}/>
                                <span>{device.label}</span>
                            </label>
                        );
                    })}
                </div>
            </div>
        );
    };

    const renderChannelPicker = (selectedIds: string[] | undefined, onChange: (ids: string[]) => void) => (
        <div className="flex flex-wrap gap-2">
            {channelOptions.map((channel) => {
                const id = channel.id || channel.type;
                const checked = (selectedIds || []).includes(id);
                return (
                    <label key={id} className={`flex cursor-pointer items-center gap-2 rounded-md border px-3 py-1.5 text-sm ${checked ? 'border-blue-200 bg-blue-50 text-blue-700' : 'border-gray-200 bg-white text-gray-600'}`}>
                        <input type="checkbox" className="h-4 w-4" checked={checked} onChange={() => onChange(toggleChannelId(selectedIds, id))}/>
                        <span>{channel.name || channelLabel(channel.type)}</span>
                    </label>
                );
            })}
        </div>
    );

    const renderConfig = (channel: NotificationChannel, index: number) => {
        const cfg = channel.config || {};
        if (channel.type === 'dingtalk' || channel.type === 'feishu' || channel.type === 'wecom') {
            return (
                <div className="grid gap-4 md:grid-cols-2">
                    <InputField label="访问令牌" value={cfg.secretKey} onChange={(value) => updateConfig(index, 'secretKey', value)} type="password"/>
                    {channel.type !== 'wecom' && <InputField label="加签密钥" value={cfg.signSecret} onChange={(value) => updateConfig(index, 'signSecret', value)} type="password"/>}
                </div>
            );
        }
        if (channel.type === 'webhook') {
            return (
                <div className="space-y-4">
                    <div className="grid gap-4 md:grid-cols-[1fr_160px]">
                        <InputField label="URL" value={cfg.url} onChange={(value) => updateConfig(index, 'url', value)}/>
                        <div>
                            <label className="mb-2 block text-xs font-semibold text-gray-600">方法</label>
                            <select value={String(cfg.method || 'POST')} onChange={(e) => updateConfig(index, 'method', e.target.value)} className="h-10 w-full rounded-md border border-gray-200 bg-white px-3 text-sm">
                                {['POST', 'PUT', 'PATCH', 'GET', 'DELETE'].map((method) => <option key={method} value={method}>{method}</option>)}
                            </select>
                        </div>
                    </div>
                    <InputField label="Content-Type" value={cfg.contentType || 'application/json; charset=utf-8'} onChange={(value) => updateConfig(index, 'contentType', value)}/>
                    <div>
                        <label className="mb-2 block text-xs font-semibold text-gray-600">请求体模板</label>
                        <Textarea value={String(cfg.body || DEFAULT_WEBHOOK_BODY)} onChange={(e) => updateConfig(index, 'body', e.target.value)} className="min-h-28 font-mono"/>
                    </div>
                </div>
            );
        }
        if (channel.type === 'email') {
            return (
                <div className="grid gap-4 md:grid-cols-2">
                    <InputField label="SMTP 主机" value={cfg.smtpHost} onChange={(value) => updateConfig(index, 'smtpHost', value)}/>
                    <InputField label="SMTP 端口" value={cfg.smtpPort} onChange={(value) => updateConfig(index, 'smtpPort', value)}/>
                    <InputField label="用户名" value={cfg.username} onChange={(value) => updateConfig(index, 'username', value)}/>
                    <InputField label="密码" value={cfg.password} onChange={(value) => updateConfig(index, 'password', value)} type="password"/>
                    <InputField label="发件人" value={cfg.from} onChange={(value) => updateConfig(index, 'from', value)}/>
                    <InputField label="收件人" value={cfg.to} onChange={(value) => updateConfig(index, 'to', value)}/>
                    <div className="md:col-span-2">
                        <InputField label="主题模板" value={cfg.subject} onChange={(value) => updateConfig(index, 'subject', value)}/>
                    </div>
                </div>
            );
        }
        return (
            <div className="grid gap-4 md:grid-cols-2">
                <InputField label="API Token" value={cfg.apiToken} onChange={(value) => updateConfig(index, 'apiToken', value)} type="password"/>
                <InputField label="用户 ID" value={cfg.userid} onChange={(value) => updateConfig(index, 'userid', value)}/>
                <label className="flex items-center gap-2 text-sm text-gray-600">
                    <input type="checkbox" checked={Boolean(cfg.proxyEnabled)} onChange={(e) => updateConfig(index, 'proxyEnabled', e.target.checked)}/>
                    启用 HTTP 代理
                </label>
                <InputField label="代理地址" value={cfg.proxyUrl} onChange={(value) => updateConfig(index, 'proxyUrl', value)}/>
                <InputField label="代理用户名" value={cfg.proxyUsername} onChange={(value) => updateConfig(index, 'proxyUsername', value)}/>
                <InputField label="代理密码" value={cfg.proxyPassword} onChange={(value) => updateConfig(index, 'proxyPassword', value)} type="password"/>
            </div>
        );
    };

    if (isLoading) {
        return <div className="flex items-center justify-center py-20"><div className="h-12 w-12 animate-spin rounded-full border-b-2 border-blue-600"/></div>;
    }

    return (
        <div className="space-y-6">
            <div className="border-b border-gray-200 pb-5">
                <h1 className="text-2xl font-bold text-gray-900">通知渠道</h1>
                <p className="mt-2 text-sm text-gray-500">每个渠道独立绑定 SIM，短信、状态推送和来电通知都会按渠道规则发送。</p>
            </div>

            <Card>
                <CardHeader>
                    <div className="flex flex-wrap items-start justify-between gap-3">
                        <div className="flex items-start gap-3">
                            <div className="flex h-10 w-10 items-center justify-center rounded-md bg-blue-50 text-blue-600"><Radio className="h-5 w-5"/></div>
                            <div>
                                <CardTitle className="text-base">设备状态定时推送</CardTitle>
                                <CardDescription>按设置时间通过通知渠道发送设备在线、SIM、网络和信号状态。</CardDescription>
                            </div>
                        </div>
                        <Button type="button" variant="outline" disabled={testStatusPushMutation.isPending} onClick={() => testStatusPushMutation.mutate()}>
                            {testStatusPushMutation.isPending ? <Loader2 className="mr-2 h-4 w-4 animate-spin"/> : <TestTube className="mr-2 h-4 w-4"/>}
                            测试推送
                        </Button>
                    </div>
                </CardHeader>
                <CardContent className="space-y-4">
                    <label className="flex items-center gap-2 text-sm text-gray-700">
                        <input type="checkbox" checked={statusDraft.enabled} onChange={(e) => setStatusDraft({...statusDraft, enabled: e.target.checked})}/>
                        启用定时推送
                    </label>
                    <div>
                        <label className="mb-2 block text-xs font-semibold text-gray-600">推送时间</label>
                        <div className="flex flex-wrap gap-2">
                            {statusDraft.times.map((time, index) => (
                                <Input key={`${time}-${index}`} type="time" value={time} onChange={(e) => {
                                    const next = [...statusDraft.times];
                                    next[index] = e.target.value;
                                    setStatusDraft({...statusDraft, times: next});
                                }} className="w-32"/>
                            ))}
                            <Button type="button" variant="outline" onClick={() => setStatusDraft({...statusDraft, times: [...statusDraft.times, '09:00']})}>
                                <Plus className="mr-2 h-4 w-4"/>增加
                            </Button>
                            {statusDraft.times.length > 1 && (
                                <Button type="button" variant="outline" onClick={() => setStatusDraft({...statusDraft, times: statusDraft.times.slice(0, -1)})}>删除末项</Button>
                            )}
                        </div>
                    </div>
                    <div>
                        <label className="mb-2 block text-xs font-semibold text-gray-600">推送渠道</label>
                        {renderChannelPicker(statusDraft.channelIds, (ids) => setStatusDraft({...statusDraft, channelIds: ids}))}
                    </div>
                    <div className="flex flex-wrap gap-4 text-sm text-gray-700">
                        <label className="flex items-center gap-2"><input type="checkbox" checked={statusDraft.includeSignal} onChange={(e) => setStatusDraft({...statusDraft, includeSignal: e.target.checked})}/>信号状态</label>
                        <label className="flex items-center gap-2"><input type="checkbox" checked={statusDraft.includeNetwork} onChange={(e) => setStatusDraft({...statusDraft, includeNetwork: e.target.checked})}/>网络状态</label>
                        <label className="flex items-center gap-2"><input type="checkbox" checked={statusDraft.includeSim} onChange={(e) => setStatusDraft({...statusDraft, includeSim: e.target.checked})}/>SIM 状态</label>
                        <label className="flex items-center gap-2"><input type="checkbox" checked={statusDraft.includeRuntime} onChange={(e) => setStatusDraft({...statusDraft, includeRuntime: e.target.checked})}/>运行时长</label>
                    </div>
                </CardContent>
            </Card>

            <Card>
                <CardHeader>
                    <div className="flex items-start gap-3">
                        <div className="flex h-10 w-10 items-center justify-center rounded-md bg-amber-50 text-amber-600"><PhoneCall className="h-5 w-5"/></div>
                        <div>
                            <CardTitle className="text-base">来电挂断通知</CardTitle>
                            <CardDescription>模块检测到来电时不响应，电话挂断后按开关推送通知。</CardDescription>
                        </div>
                    </div>
                </CardHeader>
                <CardContent className="space-y-4">
                    <label className="flex items-center gap-2 text-sm text-gray-700">
                        <input type="checkbox" checked={callDraft.enabled} onChange={(e) => setCallDraft({...callDraft, enabled: e.target.checked})}/>
                        启用来电挂断通知
                    </label>
                    <div>
                        <label className="mb-2 block text-xs font-semibold text-gray-600">推送渠道</label>
                        {renderChannelPicker(callDraft.channelIds, (ids) => setCallDraft({...callDraft, channelIds: ids}))}
                    </div>
                </CardContent>
            </Card>

            <div className="flex flex-wrap items-center gap-3">
                <select value={newType} onChange={(e) => setNewType(e.target.value as ChannelType)} className="h-10 rounded-md border border-gray-200 bg-white px-3 text-sm">
                    {CHANNEL_TYPES.map((item) => <option key={item.type} value={item.type}>{item.label}</option>)}
                </select>
                <Button type="button" onClick={addChannel}>
                    <Plus className="mr-2 h-4 w-4"/>新增渠道
                </Button>
            </div>

            <div className="grid gap-5">
                {draft.length === 0 && <div className="rounded-md border border-dashed border-gray-300 p-8 text-center text-sm text-gray-500">还没有通知渠道</div>}
                {draft.map((channel, index) => {
                    const meta = CHANNEL_TYPES.find((item) => item.type === channel.type);
                    const selected = channel.deviceIds || [];
                    return (
                        <Card key={channel.id || `${channel.type}-${index}`} className="border-gray-200">
                            <CardHeader className="border-b border-gray-100">
                                <div className="flex flex-wrap items-start justify-between gap-3">
                                    <div className="flex items-start gap-3">
                                        <div className={`flex h-11 w-11 items-center justify-center rounded-md ${channel.enabled ? 'bg-blue-50 text-blue-600' : 'bg-gray-100 text-gray-400'}`}>
                                            <Bell className="h-5 w-5"/>
                                        </div>
                                        <div>
                                            <CardTitle className="text-base">{channel.name || meta?.label || channel.type}</CardTitle>
                                            <CardDescription className="mt-1">{meta?.description} · {selected.length === 0 ? '全部 SIM' : selected.join(', ')}</CardDescription>
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-2">
                                        <Button type="button" variant="outline" size="sm" disabled={testChannelMutation.isPending || !channel.enabled} onClick={() => testChannel(channel)}>
                                            <TestTube className="mr-2 h-4 w-4"/>测试
                                        </Button>
                                        <label className="flex items-center gap-2 rounded-md border border-gray-200 px-3 py-2 text-sm">
                                            <input type="checkbox" checked={channel.enabled} onChange={(e) => updateChannel(index, {enabled: e.target.checked})}/>
                                            启用
                                        </label>
                                        <Button type="button" variant="outline" size="sm" onClick={() => removeChannel(index)}>
                                            <Trash2 className="h-4 w-4"/>
                                        </Button>
                                    </div>
                                </div>
                            </CardHeader>
                            <CardContent className="space-y-4 pt-5">
                                <div className="grid gap-4 md:grid-cols-[220px_1fr]">
                                    <InputField label="渠道名称" value={channel.name} onChange={(value) => updateChannel(index, {name: value})}/>
                                    {renderDeviceScope(channel, index)}
                                </div>
                                {renderConfig(channel, index)}
                            </CardContent>
                        </Card>
                    );
                })}
            </div>

            <div className="flex border-t border-gray-200 pt-5">
                <Button onClick={save} disabled={saveMutation.isPending} className="min-w-36">
                    {saveMutation.isPending ? <Loader2 className="mr-2 h-4 w-4 animate-spin"/> : <Save className="mr-2 h-4 w-4"/>}
                    保存配置
                </Button>
            </div>
        </div>
    );
}

function InputField({label, value, onChange, type = 'text'}: {
    label: string;
    value: any;
    onChange: (value: string) => void;
    type?: string;
}) {
    return (
        <div>
            <label className="mb-2 block text-xs font-semibold text-gray-600">{label}</label>
            <Input type={type} autoComplete={type === 'password' ? 'new-password' : undefined} value={String(value || '')} onChange={(e) => onChange(e.target.value)} className="font-mono"/>
        </div>
    );
}
''')

PY

echo "Cleaning accidental release artifacts from repository root..."
git rm -f -- uart_sms_forwarder-linux-amd64-* *.tar.gz 2>/dev/null || true
rm -f -- uart_sms_forwarder-linux-amd64-* *.tar.gz
rm -rf dist
cat >> .gitignore <<'EOF'
dist/
web/dist/
*.tar.gz
uart_sms_forwarder-linux-amd64*
EOF
sort -u .gitignore -o .gitignore

echo "Formatting Go files..."
gofmt -w internal/handler/property_handler.go internal/handler/property_handler_test.go internal/handler/scheduled_task_handler.go internal/models/property.go internal/service/*.go

echo "Privacy scan..."
if rg -q '\+?861[3-9][0-9]{9}|1[3-9][0-9]{9}|SEC[A-Za-z0-9]{12,}|access_token=[A-Za-z0-9_-]{10,}|("iccid"|ExpectedICCID)\s*[:=]\s*"[0-9A-Fa-f]{18,22}"' cmd config internal web README.md config.example.yaml 2>/dev/null; then
  echo "Found private-looking value, aborting."
  exit 1
fi

echo "Running Go tests..."
go test ./...

echo "Building web frontend..."
cd web
npm install
npm run build
cd ..

echo "Building Linux amd64 package..."
mkdir -p dist/uart_sms_forwarder-linux-amd64
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o dist/uart_sms_forwarder-linux-amd64/uart_sms_forwarder ./cmd/serv
cp config.example.yaml README.md dist/uart_sms_forwarder-linux-amd64/
tar -C dist -czf "dist/${ASSET}" uart_sms_forwarder-linux-amd64

echo "Committing and publishing release..."
git add -A
git commit -m "add Jays SMS status and call notifications" || true
git push origin main

git tag -f "$TAG"
git push origin ":refs/tags/$TAG" 2>/dev/null || true
git push origin "$TAG"

gh release delete "$TAG" -y 2>/dev/null || true
gh release create "$TAG" "dist/${ASSET}" \
  --repo "$REPO" \
  --title "$TAG" \
  --notes "Jay's SMS branding, shorter device status, scheduled device status push, test status push, and optional call-disconnect notifications."

echo
echo "DONE:"
echo "https://github.com/${REPO}/releases/tag/${TAG}"
echo "Asset: ${ASSET}"
