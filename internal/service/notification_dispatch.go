package service

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
