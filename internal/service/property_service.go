package service

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/dushixiang/uart_sms_forwarder/internal/models"
	"github.com/dushixiang/uart_sms_forwarder/internal/repo"
	"github.com/go-orz/cache"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

const (
	// PropertyIDNotificationChannels 通知渠道配置的固定 ID
	PropertyIDNotificationChannels = "notification_channels"
)

type PropertyService struct {
	repo   *repo.PropertyRepo
	logger *zap.Logger
	// 内存缓存，使用 go-orz/cache，永不过期
	cache cache.Cache[string, *models.Property]
}

func NewPropertyService(logger *zap.Logger, db *gorm.DB) *PropertyService {
	return &PropertyService{
		repo:   repo.NewPropertyRepo(db),
		logger: logger,
		cache:  cache.New[string, *models.Property](time.Minute), // 0 表示永不过期
	}
}

// Get 获取属性（返回原始 JSON 字符串）
func (s *PropertyService) Get(ctx context.Context, id string) (*models.Property, error) {
	// 先尝试从缓存读取
	if property, ok := s.cache.Get(id); ok {
		return property, nil
	}

	// 缓存未命中，从数据库读取
	property, err := s.repo.FindById(ctx, id)
	if err != nil {
		return nil, err
	}

	// 更新缓存
	s.cache.Set(id, &property, time.Hour)

	return &property, nil
}

// GetValue 获取属性值并反序列化
func (s *PropertyService) GetValue(ctx context.Context, id string, target interface{}) error {
	// 使用 Get 方法，内部已经支持缓存
	property, err := s.Get(ctx, id)
	if err != nil {
		return err
	}

	if property.Value == "" {
		return nil
	}

	return json.Unmarshal([]byte(property.Value), target)
}

// Set 设置属性（接收对象，自动序列化）
func (s *PropertyService) Set(ctx context.Context, id string, name string, value interface{}) error {
	jsonValue, err := json.Marshal(value)
	if err != nil {
		return err
	}

	property := &models.Property{
		ID:        id,
		Name:      name,
		Value:     string(jsonValue),
		CreatedAt: time.Now().UnixMilli(),
		UpdatedAt: time.Now().UnixMilli(),
	}

	err = s.repo.Save(ctx, property)
	if err != nil {
		return err
	}

	// 清空缓存中的该项，下次读取时会重新从数据库加载
	s.cache.Delete(id)

	return nil
}

func (s *PropertyService) GetNotificationChannelConfigs(ctx context.Context) ([]models.NotificationChannelConfig, error) {
	var allChannels []models.NotificationChannelConfig
	err := s.GetValue(ctx, PropertyIDNotificationChannels, &allChannels)
	if err != nil {
		return nil, fmt.Errorf("获取通知渠道配置失败: %w", err)
	}
	return NormalizeNotificationChannelConfigs(allChannels), nil
}

func NormalizeNotificationChannelConfigs(channels []models.NotificationChannelConfig) []models.NotificationChannelConfig {
	usedIDs := make(map[string]struct{}, len(channels))
	typeCounts := make(map[string]int, len(channels))
	normalized := make([]models.NotificationChannelConfig, 0, len(channels))

	for _, channel := range channels {
		channel.Type = strings.TrimSpace(channel.Type)
		if channel.Type == "" {
			continue
		}
		channel.Config = normalizeNotificationChannelConfig(channel.Type, channel.Config)
		channel.DeviceIDs = normalizeNotificationDeviceIDs(channel.DeviceIDs)

		baseID := sanitizeNotificationChannelID(channel.ID)
		if baseID == "" {
			typeCounts[channel.Type]++
			baseID = sanitizeNotificationChannelID(channel.Type)
			if typeCounts[channel.Type] > 1 {
				baseID = fmt.Sprintf("%s-%d", baseID, typeCounts[channel.Type])
			}
		}
		channel.ID = uniqueNotificationChannelID(baseID, usedIDs)

		if strings.TrimSpace(channel.Name) == "" {
			channel.Name = defaultNotificationChannelName(channel.Type)
			if typeCounts[channel.Type] > 1 {
				channel.Name = fmt.Sprintf("%s %d", channel.Name, typeCounts[channel.Type])
			}
		} else {
			channel.Name = strings.TrimSpace(channel.Name)
		}

		normalized = append(normalized, channel)
	}

	return normalized
}

func normalizeNotificationDeviceIDs(deviceIDs []string) []string {
	seen := make(map[string]struct{}, len(deviceIDs))
	normalized := make([]string, 0, len(deviceIDs))
	for _, id := range deviceIDs {
		id = strings.TrimSpace(id)
		if id == "" {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		normalized = append(normalized, id)
	}
	return normalized
}

func sanitizeNotificationChannelID(id string) string {
	id = strings.ToLower(strings.TrimSpace(id))
	if id == "" {
		return ""
	}
	var b strings.Builder
	lastDash := false
	for _, r := range id {
		switch {
		case r >= 'a' && r <= 'z', r >= '0' && r <= '9':
			b.WriteRune(r)
			lastDash = false
		case r == '-' || r == '_' || r == ' ' || r == '.':
			if !lastDash {
				b.WriteByte('-')
				lastDash = true
			}
		}
	}
	return strings.Trim(b.String(), "-")
}

func uniqueNotificationChannelID(base string, used map[string]struct{}) string {
	if base == "" {
		base = "channel"
	}
	id := base
	for i := 2; ; i++ {
		if _, ok := used[id]; !ok {
			used[id] = struct{}{}
			return id
		}
		id = fmt.Sprintf("%s-%d", base, i)
	}
}

func normalizeNotificationChannelConfig(channelType string, config map[string]interface{}) map[string]interface{} {
	if config == nil {
		config = map[string]interface{}{}
	}
	normalized := make(map[string]interface{}, len(config)+2)
	for k, v := range config {
		normalized[k] = v
	}

	switch channelType {
	case "dingtalk", "feishu", "wecom":
		if stringConfigValue(normalized, "secretKey") == "" {
			if value := firstStringConfigValue(normalized, "accessToken", "access_token", "token", "key", "webhookKey"); value != "" {
				normalized["secretKey"] = value
			}
		}
		if stringConfigValue(normalized, "signSecret") == "" {
			if value := firstStringConfigValue(normalized, "sign_secret", "secret", "sign", "signKey", "sign_key"); value != "" {
				normalized["signSecret"] = value
			}
		}
	}

	return normalized
}

func firstStringConfigValue(config map[string]interface{}, keys ...string) string {
	for _, key := range keys {
		if value := stringConfigValue(config, key); value != "" {
			return value
		}
	}
	return ""
}

func stringConfigValue(config map[string]interface{}, key string) string {
	value, ok := config[key]
	if !ok {
		return ""
	}
	text, ok := value.(string)
	if !ok {
		return ""
	}
	return strings.TrimSpace(text)
}

func defaultNotificationChannelName(channelType string) string {
	switch channelType {
	case "dingtalk":
		return "DingTalk"
	case "feishu":
		return "Feishu"
	case "wecom":
		return "WeCom"
	case "webhook":
		return "Webhook"
	case "email":
		return "Email"
	case "telegram":
		return "Telegram"
	default:
		return strings.ToUpper(channelType)
	}
}

// defaultPropertyConfig 默认配置项定义
type defaultPropertyConfig struct {
	ID    string
	Name  string
	Value interface{}
}

// InitializeDefaultConfigs 初始化默认配置（如果数据库中不存在）
func (s *PropertyService) InitializeDefaultConfigs(ctx context.Context) error {
	// 定义所有需要初始化的默认配置
	defaultConfigs := []defaultPropertyConfig{
		{
			ID:    PropertyIDNotificationChannels,
			Name:  "通知渠道配置",
			Value: []models.NotificationChannelConfig{},
		},
		{
			ID:    PropertyIDStatusPushConfig,
			Name:  "设备状态推送配置",
			Value: DefaultStatusPushConfig(),
		},
		{
			ID:    PropertyIDCallNotificationConfig,
			Name:  "来电通知配置",
			Value: DefaultCallNotificationConfig(),
		},
	}

	// 遍历并初始化每个配置
	for _, config := range defaultConfigs {
		if err := s.initializeProperty(ctx, config); err != nil {
			return fmt.Errorf("初始化 %s 失败: %w", config.Name, err)
		}
	}

	s.logger.Info("默认配置初始化完成")
	return nil
}

// initializeProperty 初始化单个配置项
func (s *PropertyService) initializeProperty(ctx context.Context, config defaultPropertyConfig) error {
	// 检查配置是否已存在
	exists, err := s.repo.ExistsById(ctx, config.ID)
	if err != nil {
		return err
	}

	if exists {
		// 配置已存在，无需初始化
		s.logger.Info("配置已存在，跳过初始化", zap.String("name", config.Name))
		return nil
	}

	// 配置不存在，创建默认配置
	if err := s.Set(ctx, config.ID, config.Name, config.Value); err != nil {
		return err
	}
	s.logger.Info("配置默认值已初始化", zap.String("name", config.Name))
	return nil
}
