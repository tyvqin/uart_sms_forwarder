package service

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
