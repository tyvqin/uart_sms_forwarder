package service

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
