package handler

import (
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
	return &PropertyHandler{
		logger:   logger,
		service:  service,
		notifier: notifier,
	}
}

// GetProperty 获取属性（返回 JSON 值）
func (h *PropertyHandler) GetProperty(c echo.Context) error {
	id := c.Param("id")

	property, err := h.service.Get(c.Request().Context(), id)
	if err != nil {
		h.logger.Error("获取属性失败", zap.String("id", id), zap.Error(err))
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "获取属性失败",
		})
	}

	var value interface{}
	if property.Value != "" {
		if id == service.PropertyIDNotificationChannels {
			var channels []models.NotificationChannelConfig
			if err := json.Unmarshal([]byte(property.Value), &channels); err != nil {
				h.logger.Error("解析通知渠道配置失败", zap.String("id", id), zap.Error(err))
				return c.JSON(http.StatusInternalServerError, map[string]string{
					"error": "解析通知渠道配置失败",
				})
			}
			value = service.NormalizeNotificationChannelConfigs(channels)
		} else if err := json.Unmarshal([]byte(property.Value), &value); err != nil {
			h.logger.Error("解析属性值失败", zap.String("id", id), zap.Error(err))
			return c.JSON(http.StatusInternalServerError, map[string]string{
				"error": "解析属性值失败",
			})
		}
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"id":    property.ID,
		"name":  property.Name,
		"value": value,
	})
}

// SetProperty 设置属性
func (h *PropertyHandler) SetProperty(c echo.Context) error {
	id := c.Param("id")

	var req struct {
		Name  string      `json:"name"`
		Value interface{} `json:"value"`
	}

	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "无效的请求参数",
		})
	}

	if id == service.PropertyIDNotificationChannels {
		raw, err := json.Marshal(req.Value)
		if err != nil {
			return c.JSON(http.StatusBadRequest, map[string]string{
				"error": "无效的通知渠道配置",
			})
		}
		var channels []models.NotificationChannelConfig
		if err := json.Unmarshal(raw, &channels); err != nil {
			return c.JSON(http.StatusBadRequest, map[string]string{
				"error": "无效的通知渠道配置",
			})
		}
		req.Value = service.NormalizeNotificationChannelConfigs(channels)
	}

	if err := h.service.Set(c.Request().Context(), id, req.Name, req.Value); err != nil {
		h.logger.Error("设置属性失败", zap.String("id", id), zap.Error(err))
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "设置属性失败",
		})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"message": "设置成功",
	})
}

// TestNotificationChannel 测试通知渠道（从数据库读取配置）
func (h *PropertyHandler) TestNotificationChannel(c echo.Context) error {
	channelType := strings.TrimSpace(c.Param("type"))
	channelID := strings.TrimSpace(c.QueryParam("channelId"))
	if channelType == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "缺少渠道类型参数",
		})
	}

	ctx := c.Request().Context()

	channels, err := h.service.GetNotificationChannelConfigs(c.Request().Context())
	if err != nil {
		h.logger.Error("获取通知渠道配置失败", zap.Error(err))
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "获取通知渠道配置失败",
		})
	}

	targetChannel := selectNotificationChannelForTest(channels, channelType, channelID)

	if targetChannel == nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": "通知渠道不存在，请先配置",
		})
	}

	if !targetChannel.Enabled {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "通知渠道未启用",
		})
	}

	// 发送测试消息
	message := "这是一条测试通知消息"

	var sendErr error
	switch targetChannel.Type {
	case "dingtalk":
		sendErr = h.notifier.SendDingTalkByConfig(ctx, targetChannel.Config, message)
	case "wecom":
		sendErr = h.notifier.SendWeComByConfig(ctx, targetChannel.Config, message)
	case "feishu":
		sendErr = h.notifier.SendFeishuByConfig(ctx, targetChannel.Config, message)
	case "webhook":
		sendErr = h.notifier.SendWebhookByConfig(ctx, targetChannel.Config, service.NotificationMessage{
			Type:      "sms",
			From:      "13800001234",
			Content:   message,
			Timestamp: time.Now().Unix(),
		})
	case "email":
		sendErr = h.notifier.SendEmailByConfig(ctx, targetChannel.Config, message)
	case "telegram":
		sendErr = h.notifier.SendTelegramByConfig(ctx, targetChannel.Config, message)

	default:
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "不支持的通知渠道类型",
		})
	}

	if sendErr != nil {
		h.logger.Error("发送测试通知失败",
			zap.String("type", channelType),
			zap.String("channel_id", channelID),
			zap.Error(sendErr))
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "发送测试通知失败: " + sendErr.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"message": "测试通知已发送",
	})
}

func selectNotificationChannelForTest(channels []models.NotificationChannelConfig, channelType, channelID string) *models.NotificationChannelConfig {
	channelType = strings.TrimSpace(channelType)
	channelID = strings.TrimSpace(channelID)

	for i := range channels {
		if channelID != "" && channels[i].ID == channelID && channels[i].Type == channelType {
			return &channels[i]
		}
	}

	if channelID != "" {
		return nil
	}

	for i := range channels {
		if channels[i].Type == channelType {
			return &channels[i]
		}
	}
	return nil
}
