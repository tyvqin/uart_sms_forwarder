#!/usr/bin/env bash
set -euo pipefail

REPO="tyvqin/uart_sms_forwarder"
TAG="v0.1.2-multisim-safe"
ASSET="/tmp/uart_sms_forwarder-linux-amd64-multisim-safe.tar.gz"

echo 'Applying multi-SIM notification routing fix...' 
mkdir -p '.'
cat > 'README.md' <<'CODEX_FILE_0'
# 鐭俊UART杞彂鍣?
鍩轰簬 鍚堝畽Air780 XXX 绯诲垪璁惧鐨勭煭淇¤浆鍙戠郴缁燂紝鏀寔鎺ユ敹鐭俊骞堕€氳繃涓插彛杞彂鍒颁笂浣嶆満銆?
[椤圭洰璇存槑](https://blog.typesafe.cn/posts/air780e-giffgaff/)

**宸叉祴璇曡澶?*

- Air780EHV
- Air780EHM
- Air780E (鍙互浣跨敤锛屼絾灞炰簬杩囨椂璁惧锛屼笉寤鸿璐拱)
- Air780EPV (鍙互浣跨敤锛屼絾灞炰簬杩囨椂璁惧锛屼笉寤鸿璐拱)


## 馃専 鍔熻兘鐗规€?
- 鐭俊杞彂
- 鐭俊璁板綍
- 鍙戦€佺煭淇?- 鏉ョ數閫氱煡
- 鏀寔閽夐拤銆佷紒涓氬井淇°€侀涔︺€佽嚜瀹氫箟 webhook銆侀偖绠遍€氱煡
- 璁″垝浠诲姟鍙戦€佺煭淇?
## 鎴浘

![screenshot1.png](screenshots/screenshot1.png)
![screenshot2.png](screenshots/screenshot2.png)

## 馃殌 蹇€熷紑濮?
### 1. 纭欢鍑嗗

**璁惧鍑嗗**锛?- 鎻掑叆鏈夋晥鐨凷IM鍗?- 閫氳繃USB杩炴帴鐢佃剳

### 2. 鐑у綍 Lua 鑴氭湰

浣跨敤 [**LuaTools**](https://docs.openluat.com/air780epm/common/Luatools/) 鐑у綍 `main.lua` 鑴氭湰锛岀涓€娆＄儳褰曢渶瑕佺偣鍑?銆屼笅杞藉簳灞傚拰鑴氭湰銆?
![write.png](screenshots/write.png)

### 3. 娴嬭瘯

![test.png](screenshots/test.png)

### 4. 鎶婅澶囨彃鍏ュ埌浣犵殑灏忎富鏈虹瓑 Linux USB涓?

### 5. 杩愯涓婁綅鏈虹▼搴?
#### docker 鏂瑰紡瀹夎

```shell
# 鍒涘缓绌虹洰褰?mkdir /opt/uart_sms_forwarder
# 涓嬭浇 docker-compose.yml 鏂囦欢
wget https://raw.githubusercontent.com/dushixiang/uart_sms_forwarder/main/docker-compose.yml -O /opt/uart_sms_forwarder/docker-compose.yml
# 涓嬭浇 config.example.yaml 鏂囦欢
wget https://raw.githubusercontent.com/dushixiang/uart_sms_forwarder/main/config.example.yaml -O /opt/uart_sms_forwarder/config.yaml
```

淇敼 `docker-compose.yml` 鍜?`config.yaml` 鏂囦欢锛屼富瑕佹槸鏄犲皠 USB 璺緞鍜屼慨鏀瑰瘑鐮併€?
鍚姩鏈嶅姟

```shell
docker-compose up -d
```

鎵撳紑娴忚鍣ㄨ闂?8080 绔彛銆?
----

#### 鍘熺敓鏂瑰紡瀹夎

涓嬭浇

```shell
wget https://github.com/dushixiang/uart_sms_forwarder/releases/latest/download/uart_sms_forwarder-linux-amd64.tar.gz
```

瑙ｅ帇
```bash
tar -zxvf uart_sms_forwarder-linux-amd64.tar.gz -C /opt/
mv /opt/uart_sms_forwarder-linux-amd64 /opt/uart_sms_forwarder
```

鍒涘缓绯荤粺鏈嶅姟

```shell
cat <<EOF > /etc/systemd/system/uart_sms_forwarder.service
[Unit]
Description=uart_sms_forwarder service
After=network.target

[Service]
User=root
WorkingDirectory=/opt/uart_sms_forwarder
ExecStart=/opt/uart_sms_forwarder/uart_sms_forwarder
TimeoutSec=0
RestartSec=10
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
```

鍒涘缓 sqllite 鐩綍

```shell
mkdir /opt/uart_sms_forwarder/data
```

鍚姩鏈嶅姟

```shell
systemctl daemon-reload
systemctl enable uart_sms_forwarder
systemctl start uart_sms_forwarder
```

鎵撳紑娴忚鍣ㄨ闂?8080 绔彛銆?
淇敼瀵嗙爜绛夐厤缃」锛岃鍙傝€?[config.example.yaml](config.example.yaml) 鏂囦欢銆?
## 澶氭ā鍧楅儴缃?
澶氫釜 Air780 妯″潡鍚屾椂鎺ュ叆鏃讹紝涓嶈渚濊禆 `/dev/ttyUSB0` 杩欑被浼氬彉鍖栫殑缂栧彿锛屼篃涓嶈璁╁涓繘绋嬭嚜鍔ㄦ娴嬩覆鍙ｃ€傛帹鑽愮粰姣忎釜 USB Hub 鐗╃悊鍙ｅ缓绔嬬ǔ瀹氳矾寰勶紝渚嬪 `/dev/serial/by-path/...` 鎴?udev 鍒悕锛?
```yaml
App:
  Serial:
    Devices:
      - ID: sim1
        Name: "SIM 1"
        Port: "/dev/air780/sim1"
        ExpectedICCID: ""
      - ID: sim2
        Name: "SIM 2"
        Port: "/dev/air780/sim2"
        ExpectedICCID: ""
```

閰嶇疆浜?`Devices` 鍚庯紝姣忎釜妯″潡浼氬惎鍔ㄧ嫭绔嬩覆鍙ｆ湇鍔★紝鐭俊鍙戦€併€侀琛屾ā寮忋€侀噸鍚€佺姸鎬佺紦瀛樺拰璁″垝浠诲姟閮戒細鎸?`deviceId` 鎸囧悜鎸囧畾妯″潡銆俙ExpectedICCID` 鍙€夛紝鐢ㄤ簬鍙戠幇 SIM 鍗℃彃閿欐垨 Hub 鍙ｇ粦瀹氶敊璇€?
### 鑷姩鍙戠幇

寮€鍚?`AutoDiscover` 鍚庯紝绋嬪簭鍚姩鏃朵細鎵弿 `/dev/serial/by-path/*`銆?`/dev/ttyACM*` 鍜?`/dev/ttyUSB*`锛屽彧淇濈暀鑳借繑鍥?`uart_sms_forwarder`
鍗忚鐨勪覆鍙ｏ紝骞舵寜 ICCID 缁戝畾妯″潡銆?
```yaml
App:
  Serial:
    AutoDiscover: true
    Devices:
      - ID: sim1
        Name: "SIM 1"
        ExpectedICCID: "ICCID_SAMPLE_1"
      - ID: sim2
        Name: "SIM 2"
        ExpectedICCID: "ICCID_SAMPLE_2"
```

寮€鍚?`AutoDiscover` 鍚庡彲浠ヤ笉鍐?`Port`銆傞厤缃鐨勬柊妯″潡浼氳嚜鍔ㄨ拷鍔犱负
`sim3`銆乣sim4` 绛夈€?
CODEX_FILE_0

mkdir -p '.'
cat > 'config.example.yaml' <<'CODEX_FILE_1'
database:
  enabled: true
  type: sqlite
  sqlite:
    path: "./data/app.db"
  show_sql: false

log:
  level: debug
  filename: ./logs/sms.log

server:
  addr: "0.0.0.0:8080"
  ip_extractor: "X-Real-IP"

App:
  JWT:
    Secret: ""
    ExpiresHours: 168
  Users:
    admin: "CHANGE_ME_BCRYPT_HASH"
  OIDC:
    Enabled: false
    Issuer: ""
    ClientID: ""
    ClientSecret: ""
    RedirectURL: "http://localhost:8080/oidc/callback"

  Serial:
    # Backward-compatible single-device mode. Empty means auto-detect.
    Port: ""

    # Auto-discover mode scans /dev/serial/by-path and ttyACM/ttyUSB ports,
    # probes the uart_sms_forwarder protocol, and binds modules by ICCID.
    AutoDiscover: false

    # Multi-device mode. With AutoDiscover enabled, Port can be omitted and the
    # app will fill it at startup. ExpectedICCID is recommended for stable SIM binding.
    # Devices:
    #   - ID: sim1
    #     Name: "SIM 1"
    #     ExpectedICCID: "ICCID_SAMPLE_1"
    #   - ID: sim2
    #     Name: "SIM 2"
    #     ExpectedICCID: "ICCID_SAMPLE_2"
CODEX_FILE_1

mkdir -p 'internal/models'
cat > 'internal/models/property.go' <<'CODEX_FILE_2'
package models

// Property 通用属性配置表
type Property struct {
	ID        string `gorm:"primaryKey" json:"id"`                  // 属性ID (如: notification_channels)
	Name      string `json:"name"`                                  // 可读名称
	Value     string `json:"value" gorm:"type:text"`                // JSON配置
	CreatedAt int64  `json:"createdAt"`                             // 创建时间（时间戳毫秒）
	UpdatedAt int64  `json:"updatedAt" gorm:"autoUpdateTime:milli"` // 更新时间（时间戳毫秒）
}

func (Property) TableName() string {
	return "properties"
}

// NotificationChannelConfig 通知渠道配置（存储在 Property 中）
type NotificationChannelConfig struct {
	ID        string                 `json:"id,omitempty"`        // unique channel ID
	Name      string                 `json:"name,omitempty"`      // display name
	Type      string                 `json:"type"`                // dingtalk, wecom, feishu, webhook, email, telegram
	Enabled   bool                   `json:"enabled"`             // enabled
	DeviceIDs []string               `json:"deviceIds,omitempty"` // empty means all SIM devices
	Config    map[string]interface{} `json:"config"`              // provider-specific config
}

// 配置格式说明：
// dingtalk: { "secretKey": "xxx", "signSecret": "xxx" }
// wecom:    { "secretKey": "xxx" }
// feishu:   { "secretKey": "xxx", "signSecret": "xxx" }
// webhook:  {
//   "url": "https://...",
//   "method": "POST",  // 可选：GET, POST, PUT, PATCH, DELETE，默认 POST
//   "headers": {"key": "value"},  // 可选：自定义请求头
//   "bodyTemplate": "json"  // 可选：json(默认), form, custom
//   "customBody": ""  // 当 bodyTemplate 为 custom 时使用，支持变量替换
// }

// WebhookConfig 自定义 Webhook 配置结构
type WebhookConfig struct {
	URL          string            `json:"url"`                    // Webhook URL
	Method       string            `json:"method,omitempty"`       // 请求方法，默认 POST
	Headers      map[string]string `json:"headers,omitempty"`      // 自定义请求头
	BodyTemplate string            `json:"bodyTemplate,omitempty"` // 请求体模板：json, form, custom
	CustomBody   string            `json:"customBody,omitempty"`   // 自定义请求体模板（支持变量）
}
CODEX_FILE_2

mkdir -p 'internal/service'
cat > 'internal/service/property_service.go' <<'CODEX_FILE_3'
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
CODEX_FILE_3

mkdir -p 'internal/handler'
cat > 'internal/handler/property_handler.go' <<'CODEX_FILE_4'
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
CODEX_FILE_4

mkdir -p 'internal/handler'
cat > 'internal/handler/property_handler_test.go' <<'CODEX_FILE_5'
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
CODEX_FILE_5

mkdir -p 'internal/service'
cat > 'internal/service/serial_handlers_sms.go' <<'CODEX_FILE_6'
package service

import (
	"context"
	"strings"
	"encoding/json"
	"fmt"
	"time"

	"github.com/dushixiang/uart_sms_forwarder/internal/models"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

// IncomingSMS 接收的短信消息结构
type IncomingSMS struct {
	Timestamp int64  `json:"timestamp"`
	From      string `json:"from"`
	Content   string `json:"content"`
	Type      string `json:"type"`
}

func (r IncomingSMS) String() string {
	timestamp := time.Unix(r.Timestamp, 0)
	message := fmt.Sprintf(`%s
----
来自: %s
%s
`,
		r.Content,
		r.From,
		timestamp.Format(time.DateTime),
	)
	return message
}

// handleIncomingSMS 处理接收到的短信
func (s *SerialService) handleIncomingSMS(msg *ParsedMessage) {
	var sms IncomingSMS
	if err := json.Unmarshal([]byte(msg.JSON), &sms); err != nil {
		s.logger.Error("短信消息解析失败", zap.Error(err))
		return
	}

	s.logger.Info("收到新短信",
		zap.String("device_id", s.deviceID),
		zap.String("from", sms.From),
		zap.String("content", sms.Content),
		zap.Int64("timestamp", sms.Timestamp))

	// 保存短信记录
	ctx := context.Background()
	record := &models.TextMessage{
		ID:        uuid.NewString(),
		DeviceID:  s.deviceID,
		From:      sms.From,
		To:        "", // 接收方是本机
		Content:   sms.Content,
		Type:      models.MessageTypeIncoming,
		Status:    models.MessageStatusReceived,
		CreatedAt: time.Now().UnixMilli(),
	}

	if err := s.textMsgService.Save(ctx, record); err != nil {
		s.logger.Error("保存短信记录失败", zap.Error(err))
	}

	// 异步发送通知
	go s.sendNotification(ctx, sms)
}

// sendNotification 发送通知
func (s *SerialService) sendNotification(ctx context.Context, sms IncomingSMS) {
	// 转换为通用通知消息
	msg := NotificationMessage{
		Type:       "sms",
		DeviceID:   s.deviceID,
		DeviceName: s.deviceName,
		From:       sms.From,
		Content:    sms.Content,
		Timestamp:  sms.Timestamp,
	}

	s.sendNotificationMessage(ctx, msg)
}

// sendNotificationMessage 发送通用通知消息
func (s *SerialService) sendNotificationMessage(ctx context.Context, msg NotificationMessage) {
	// 获取通知渠道配置
	channels, err := s.propertyService.GetNotificationChannelConfigs(ctx)
	if err != nil {
		s.logger.Error("获取通知渠道配置失败", zap.Error(err))
		return
	}

	// 格式化消息
	message := msg.String()

	// 发送到所有启用的渠道
	for _, channel := range channels {
		if !channel.Enabled || !notificationChannelMatchesDevice(channel.DeviceIDs, msg.DeviceID) {
			continue
		}

		var sendErr error
		switch channel.Type {
		case "dingtalk":
			sendErr = s.notifier.SendDingTalkByConfig(ctx, channel.Config, message)
		case "wecom":
			sendErr = s.notifier.SendWeComByConfig(ctx, channel.Config, message)
		case "feishu":
			sendErr = s.notifier.SendFeishuByConfig(ctx, channel.Config, message)
		case "webhook":
			sendErr = s.notifier.SendWebhookByConfig(ctx, channel.Config, msg)
		case "email":
			sendErr = s.notifier.SendEmail(ctx, channel.Config, msg)
		case "telegram":
			sendErr = s.notifier.sendTelegramByConfig(ctx, channel.Config, message)
		}

		if sendErr != nil {
			s.logger.Error("发送通知失败",
				zap.String("device_id", msg.DeviceID),
				zap.String("channel_id", channel.ID),
				zap.String("type", channel.Type),
				zap.Error(sendErr))
		} else {
			s.logger.Info("通知发送成功",
				zap.String("device_id", msg.DeviceID),
				zap.String("channel_id", channel.ID),
				zap.String("type", channel.Type))
		}
	}
}

// handleSMSSendResult 处理短信发送结果
func (s *SerialService) handleSMSSendResult(msg *ParsedMessage) {
	success, _ := msg.Payload["success"].(bool)
	to, _ := msg.Payload["to"].(string)
	requestID, _ := msg.Payload["request_id"].(string)

	if requestID == "" {
		s.logger.Warn("收到短信发送结果但缺少 request_id", zap.Any("msg", msg.Payload))
		return
	}

	ctx := context.Background()
	var status models.MessageStatus
	var lastRunStatus models.LastRunStatus
	if success {
		status = models.MessageStatusSent
		lastRunStatus = models.LastRunStatusSuccess
		s.logger.Info("短信发送成功",
			zap.String("device_id", s.deviceID),
			zap.String("to", to),
			zap.String("request_id", requestID))
	} else {
		status = models.MessageStatusFailed
		lastRunStatus = models.LastRunStatusFailed
		s.logger.Warn("短信发送失败",
			zap.String("device_id", s.deviceID),
			zap.String("to", to),
			zap.String("request_id", requestID))
		go s.sendNotificationMessage(context.Background(), NotificationMessage{
			Type:       "sms",
			DeviceID:   s.deviceID,
			DeviceName: s.deviceName,
			From:       "UART 短信转发器",
			Content:    fmt.Sprintf("短信发送失败: %s", to),
			Timestamp:  time.Now().Unix(),
		})
	}

	if err := s.textMsgService.UpdateStatusById(ctx, requestID, status); err != nil {
		s.logger.Error("更新短信状态失败",
			zap.String("request_id", requestID),
			zap.Error(err))
	}

	s.updateScheduledTaskStatus(ctx, requestID, lastRunStatus)
}

func (s *SerialService) updateScheduledTaskStatus(ctx context.Context, msgID string, status models.LastRunStatus) {
	if s.scheduledTaskStatusUpdater == nil {
		return
	}
	if err := s.scheduledTaskStatusUpdater(ctx, msgID, status); err != nil {
		s.logger.Error("更新定时任务状态失败",
			zap.String("request_id", msgID),
			zap.Error(err))
	}
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
CODEX_FILE_6

mkdir -p 'internal/service'
cat > 'internal/service/notifier.go' <<'CODEX_FILE_7'
package service

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/valyala/fasttemplate"
	"go.uber.org/zap"
	"gopkg.in/gomail.v2"
)

// Notifier 告警通知服务
type Notifier struct {
	logger *zap.Logger
}

func NewNotifier(logger *zap.Logger) *Notifier {
	return &Notifier{
		logger: logger,
	}
}

// NotificationMessage 通用通知消息（支持短信、来电等）
type NotificationMessage struct {
	Type       string `json:"type"`                 // "sms" 或 "call"
	DeviceID   string `json:"deviceId,omitempty"`   // 串口模块 ID
	DeviceName string `json:"deviceName,omitempty"` // 串口模块名称
	From       string `json:"from"`
	Content    string `json:"content"` // 短信内容（来电时为空）
	Timestamp  int64  `json:"timestamp"`
}

func (m NotificationMessage) String() string {
	timestamp := time.Unix(m.Timestamp, 0)
	deviceName := m.DeviceName
	if deviceName == "" {
		deviceName = m.DeviceID
	}
	switch m.Type {
	case "call":
		if deviceName != "" {
			return fmt.Sprintf(`来电通知
----
模块: %s
来电号码: %s
时间: %s
`,
				deviceName,
				m.From,
				timestamp.Format(time.DateTime),
			)
		}
		return fmt.Sprintf(`来电通知
----
来电号码: %s
时间: %s
`,
			m.From,
			timestamp.Format(time.DateTime),
		)
	default: // "sms"
		if deviceName != "" {
			return fmt.Sprintf(`%s
----
模块: %s
来自: %s
时间: %s
`,
				m.Content,
				deviceName,
				m.From,
				timestamp.Format(time.DateTime),
			)
		}
		return fmt.Sprintf(`%s
----
来自: %s
时间: %s
`,
			m.Content,
			m.From,
			timestamp.Format(time.DateTime),
		)
	}
}

// sendDingTalk 发送钉钉通知
func (n *Notifier) sendDingTalk(ctx context.Context, webhook, secret, message string) error {
	// 构造钉钉消息体
	body := map[string]interface{}{
		"msgtype": "text",
		"text": map[string]string{
			"content": message,
		},
	}

	// 如果有加签密钥，计算签名
	timestamp := time.Now().UnixMilli()
	if secret != "" {
		sign := n.calculateDingTalkSign(timestamp, secret)
		webhook = fmt.Sprintf("%s&timestamp=%d&sign=%s", webhook, timestamp, sign)
	}
	_, err := n.sendJSONRequest(ctx, webhook, body)
	if err != nil {
		return err
	}
	return nil
}

// calculateDingTalkSign 计算钉钉加签
func (n *Notifier) calculateDingTalkSign(timestamp int64, secret string) string {
	stringToSign := fmt.Sprintf("%d\n%s", timestamp, secret)
	h := hmac.New(sha256.New, []byte(secret))
	h.Write([]byte(stringToSign))
	return base64.StdEncoding.EncodeToString(h.Sum(nil))
}

type WeComResult struct {
	Errcode   int    `json:"errcode"`
	Errmsg    string `json:"errmsg"`
	Type      string `json:"type"`
	MediaId   string `json:"media_id"`
	CreatedAt string `json:"created_at"`
}

// sendWeCom 发送企业微信通知
func (n *Notifier) sendWeCom(ctx context.Context, webhook, message string) error {
	body := map[string]interface{}{
		"msgtype": "text",
		"text": map[string]string{
			"content": message,
		},
	}
	result, err := n.sendJSONRequest(ctx, webhook, body)
	if err != nil {
		return err
	}
	var weComResult WeComResult
	if err := json.Unmarshal(result, &weComResult); err != nil {
		return err
	}
	if weComResult.Errcode != 0 {
		return fmt.Errorf("%s", weComResult.Errmsg)
	}
	return nil
}

// sendFeishu 发送飞书通知
func (n *Notifier) sendFeishu(ctx context.Context, webhook, signSecret, message string) error {
	body := map[string]interface{}{
		"msg_type": "text",
		"content": map[string]string{
			"text": message,
		},
	}

	// 如果有加签密钥，计算签名
	if signSecret != "" {
		timestamp := time.Now().Unix()
		stringToSign := fmt.Sprintf("%v", timestamp) + "\n" + signSecret
		var data []byte
		h := hmac.New(sha256.New, []byte(stringToSign))
		_, err := h.Write(data)
		if err != nil {
			return err
		}
		signature := base64.StdEncoding.EncodeToString(h.Sum(nil))

		// 将签名和时间戳加入请求头
		body["timestamp"] = fmt.Sprintf("%v", timestamp)
		body["sign"] = signature
	}

	_, err := n.sendJSONRequest(ctx, webhook, body)
	if err != nil {
		return err
	}
	return nil
}

// 导出方法
func (n *Notifier) SendTelegramByConfig(ctx context.Context, config map[string]interface{}, message string) error {
	return n.sendTelegramByConfig(ctx, config, message)
}

func (n *Notifier) sendTelegramByConfig(ctx context.Context, config map[string]interface{}, message string) error {
	apitoken := stringConfigValue(config, "apiToken")
	if apitoken == "" {
		return fmt.Errorf("Telegram 配置缺少 apiToken")
	}
	userid := stringConfigValue(config, "userid")
	if userid == "" {
		return fmt.Errorf("Telegram 配置缺少 userid")
	}
	proxyEnabled, _ := config["proxyEnabled"].(bool)
	proxyUrl := stringConfigValue(config, "proxyUrl")
	proxyUsername := stringConfigValue(config, "proxyUsername")
	proxyPassword := stringConfigValue(config, "proxyPassword")

	// 构建发送消息的URL
	baseURL := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", apitoken)
	body := map[string]interface{}{
		"chat_id": userid,
		"text":    message,
		//"parse_mode": "markdown",
	}

	if proxyEnabled {
		proxyFullUrl, err := buildProxyURL(proxyUrl, proxyUsername, proxyPassword)
		if err != nil {
			n.logger.Error("代理配置错误", zap.Error(err))
			return err
		}
		_, err = n.sendJSONRequestWithProxy(ctx, baseURL, proxyFullUrl, body)
		if err != nil {
			return err
		}
	} else {
		_, err := n.sendJSONRequest(ctx, baseURL, body)
		if err != nil {
			return err
		}
	}
	return nil
}

// sendCustomWebhook 发送自定义Webhook
func (n *Notifier) sendCustomWebhook(ctx context.Context, config map[string]interface{}, msg NotificationMessage) error {
	// 解析配置
	webhookURL := stringConfigValue(config, "url")
	if webhookURL == "" {
		return fmt.Errorf("自定义Webhook配置缺少 url")
	}

	// 获取请求方法，默认 POST
	method := "POST"
	if m, ok := config["method"].(string); ok && m != "" {
		method = strings.ToUpper(m)
	}

	// 获取自定义请求头
	headers := make(map[string]string)
	if h, ok := config["headers"].(map[string]interface{}); ok {
		for k, v := range h {
			if strVal, ok := v.(string); ok {
				headers[k] = strVal
			}
		}
	}

	customBody := stringConfigValue(config, "body")
	if customBody == "" {
		return fmt.Errorf("自定义Webhook配置缺少 body")
	}

	// 使用 fasttemplate 进行变量替换
	t := fasttemplate.New(customBody, "{{", "}}")
	escape := func(s string) string {
		b, _ := json.Marshal(s)
		// json.Marshal 会返回带双引号的字符串，例如 "hello\nworld"
		// 模板中不需要外层双引号，所以去掉
		return string(b[1 : len(b)-1])
	}

	bodyStr := t.ExecuteFuncString(func(w io.Writer, tag string) (int, error) {
		var v string

		switch tag {
		case "from":
			v = msg.From
		case "content":
			v = msg.Content
		case "type":
			v = msg.Type
		case "deviceId":
			v = msg.DeviceID
		case "deviceName":
			v = msg.DeviceName
		case "timestamp":
			timestamp := time.Unix(msg.Timestamp, 0).Format(time.DateTime)
			v = timestamp
		default:
			return w.Write([]byte("{{" + tag + "}}"))
		}

		// 写入 JSON 安全转义后的值
		return w.Write([]byte(escape(v)))
	})
	n.logger.Sugar().Debugf("自定义Webhook请求体: %s", bodyStr)
	var reqBody = strings.NewReader(bodyStr)
	contentType := stringConfigValue(config, "contentType")
	if contentType == "" {
		contentType = "application/json; charset=utf-8"
	}

	// 创建请求
	req, err := http.NewRequestWithContext(ctx, method, webhookURL, reqBody)
	if err != nil {
		return fmt.Errorf("创建请求失败: %w", err)
	}

	// 设置 Content-Type
	req.Header.Set("Content-Type", contentType)

	// 设置自定义请求头
	for k, v := range headers {
		req.Header.Set(k, v)
	}

	// 发送请求
	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("发送请求失败: %w", err)
	}
	defer resp.Body.Close()

	// 读取响应
	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("请求失败，状态码: %d, 响应: %s", resp.StatusCode, string(respBody))
	}

	n.logger.Info("自定义Webhook发送成功",
		zap.String("url", sanitizeWebhookURLForLog(webhookURL)),
		zap.String("method", method),
		zap.String("response", string(respBody)),
	)

	return nil
}

// sendJSONRequest 发送JSON请求
func (n *Notifier) sendJSONRequest(ctx context.Context, url string, body interface{}) ([]byte, error) {
	data, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("序列化请求体失败: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("创建请求失败: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("发送请求失败: %w", err)
	}
	defer resp.Body.Close()

	// 读取响应
	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("请求失败，状态码: %d, 响应: %s", resp.StatusCode, string(respBody))
	}

	n.logger.Info("通知发送成功", zap.String("url", sanitizeWebhookURLForLog(url)), zap.String("response", string(respBody)))
	return respBody, nil
}

func (n *Notifier) sendJSONRequestWithProxy(ctx context.Context, url string, proxyUrl *url.URL, body interface{}) ([]byte, error) {
	data, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("序列化请求体失败: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("创建请求失败: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	transport := &http.Transport{}
	transport.Proxy = http.ProxyURL(proxyUrl)

	client := &http.Client{
		Timeout:   10 * time.Second,
		Transport: transport,
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("发送请求失败: %w", err)
	}
	defer resp.Body.Close()

	// 读取响应
	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("请求失败，状态码: %d, 响应: %s", resp.StatusCode, string(respBody))
	}

	n.logger.Info("通知发送成功", zap.String("url", sanitizeWebhookURLForLog(url)), zap.String("response", string(respBody)))
	return respBody, nil
}

func sanitizeWebhookURLForLog(rawURL string) string {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "<invalid-url>"
	}
	query := parsed.Query()
	for _, key := range []string{"access_token", "key", "token", "sign"} {
		if query.Has(key) {
			query.Set(key, "***")
		}
	}
	parsed.RawQuery = query.Encode()
	return parsed.String()
}

// sendDingTalkByConfig 根据配置发送钉钉通知
func (n *Notifier) sendDingTalkByConfig(ctx context.Context, config map[string]interface{}, message string) error {
	secretKey, ok := config["secretKey"].(string)
	if !ok || secretKey == "" {
		return fmt.Errorf("钉钉配置缺少 secretKey")
	}

	// 构造 Webhook URL
	webhook := fmt.Sprintf("https://oapi.dingtalk.com/robot/send?access_token=%s", secretKey)

	// 检查是否有加签密钥
	signSecret, _ := config["signSecret"].(string)

	return n.sendDingTalk(ctx, webhook, signSecret, message)
}

// sendWeComByConfig 根据配置发送企业微信通知
func (n *Notifier) sendWeComByConfig(ctx context.Context, config map[string]interface{}, message string) error {
	secretKey, ok := config["secretKey"].(string)
	if !ok || secretKey == "" {
		return fmt.Errorf("企业微信配置缺少 secretKey")
	}

	// 构造 Webhook URL
	webhook := fmt.Sprintf("https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=%s", secretKey)

	return n.sendWeCom(ctx, webhook, message)
}

// sendFeishuByConfig 根据配置发送飞书通知
func (n *Notifier) sendFeishuByConfig(ctx context.Context, config map[string]interface{}, message string) error {
	secretKey, ok := config["secretKey"].(string)
	if !ok || secretKey == "" {
		return fmt.Errorf("飞书配置缺少 secretKey")
	}

	// 构造 Webhook URL
	webhook := fmt.Sprintf("https://open.feishu.cn/open-apis/bot/v2/hook/%s", secretKey)

	// 检查是否有加签密钥
	signSecret, _ := config["signSecret"].(string)

	return n.sendFeishu(ctx, webhook, signSecret, message)
}

// SendDingTalkByConfig 导出方法供外部调用
func (n *Notifier) SendDingTalkByConfig(ctx context.Context, config map[string]interface{}, message string) error {
	return n.sendDingTalkByConfig(ctx, config, message)
}

// SendWeComByConfig 导出方法供外部调用
func (n *Notifier) SendWeComByConfig(ctx context.Context, config map[string]interface{}, message string) error {
	return n.sendWeComByConfig(ctx, config, message)
}

// SendFeishuByConfig 导出方法供外部调用
func (n *Notifier) SendFeishuByConfig(ctx context.Context, config map[string]interface{}, message string) error {
	return n.sendFeishuByConfig(ctx, config, message)
}

// SendWebhookByConfig 导出方法供外部调用
func (n *Notifier) SendWebhookByConfig(ctx context.Context, config map[string]interface{}, msg NotificationMessage) error {
	return n.sendCustomWebhook(ctx, config, msg)
}

// sendEmail 发送邮件通知
func (n *Notifier) sendEmail(ctx context.Context, config map[string]interface{}, msg NotificationMessage) error {
	// 解析配置
	smtpHost, ok := config["smtpHost"].(string)
	if !ok || smtpHost == "" {
		return fmt.Errorf("邮件配置缺少 smtpHost")
	}

	smtpPortStr, ok := config["smtpPort"].(string)
	if !ok || smtpPortStr == "" {
		smtpPortStr = "587"
	}

	// 转换端口为整数
	smtpPort, err := strconv.Atoi(smtpPortStr)
	if err != nil {
		return fmt.Errorf("无效的 SMTP 端口: %s", smtpPortStr)
	}

	username, ok := config["username"].(string)
	if !ok || username == "" {
		return fmt.Errorf("邮件配置缺少 username")
	}

	password, ok := config["password"].(string)
	if !ok || password == "" {
		return fmt.Errorf("邮件配置缺少 password")
	}

	from, ok := config["from"].(string)
	if !ok || from == "" {
		return fmt.Errorf("邮件配置缺少 from")
	}

	to, ok := config["to"].(string)
	if !ok || to == "" {
		return fmt.Errorf("邮件配置缺少 to")
	}

	subject, ok := config["subject"].(string)
	if !ok || subject == "" {
		if msg.Type == "call" {
			subject = "来电通知 - {{from}}"
		} else {
			subject = "收到新短信 - {{from}}"
		}
	}

	// 模板变量替换函数
	replaceVars := func(template string) string {
		t := fasttemplate.New(template, "{{", "}}")
		return t.ExecuteFuncString(func(w io.Writer, tag string) (int, error) {
			var v string
			switch tag {
			case "from":
				v = msg.From
			case "content":
				v = msg.Content
			case "type":
				v = msg.Type
			case "deviceId":
				v = msg.DeviceID
			case "deviceName":
				v = msg.DeviceName
			case "timestamp":
				v = time.Unix(msg.Timestamp, 0).Format(time.DateTime)
			default:
				return w.Write([]byte("{{" + tag + "}}"))
			}
			return w.Write([]byte(v))
		})
	}

	// 替换主题中的变量
	subject = replaceVars(subject)

	// 构造邮件内容
	body := msg.String()

	// 分隔多个收件人
	toList := strings.Split(to, ",")
	for i, addr := range toList {
		toList[i] = strings.TrimSpace(addr)
	}

	// 使用 gomail 创建邮件
	m := gomail.NewMessage()
	m.SetHeader("From", from)
	m.SetHeader("To", toList...)
	m.SetHeader("Subject", subject)
	m.SetBody("text/plain", body)

	// 创建 SMTP 拨号器
	d := gomail.NewDialer(smtpHost, smtpPort, username, password)

	// 发送邮件
	if err := d.DialAndSend(m); err != nil {
		return fmt.Errorf("发送邮件失败: %w", err)
	}

	n.logger.Info("邮件发送成功",
		zap.String("from", from),
		zap.String("to", to),
		zap.String("subject", subject),
	)

	return nil
}

// sendEmailByConfig 根据配置发送邮件通知（用于测试）
func (n *Notifier) sendEmailByConfig(ctx context.Context, config map[string]interface{}, message string) error {
	// 构造一个临时的 NotificationMessage 对象用于测试
	msg := NotificationMessage{
		Type:      "sms",
		From:      "测试发送方",
		Content:   message,
		Timestamp: time.Now().Unix(),
	}
	return n.sendEmail(ctx, config, msg)
}

// SendEmailByConfig 导出方法供外部调用（用于测试）
func (n *Notifier) SendEmailByConfig(ctx context.Context, config map[string]interface{}, message string) error {
	return n.sendEmailByConfig(ctx, config, message)
}

// SendEmail 发送邮件通知（通用方法）
func (n *Notifier) SendEmail(ctx context.Context, config map[string]interface{}, msg NotificationMessage) error {
	return n.sendEmail(ctx, config, msg)
}

func buildProxyURL(rawProxyURL string, username string, password string) (*url.URL, error) {
	u, err := url.Parse(rawProxyURL)
	if err != nil {
		return nil, err
	}

	if username != "" {
		u.User = url.UserPassword(username, password)
	}
	return u, nil
}
CODEX_FILE_7

mkdir -p 'internal/service'
cat > 'internal/service/serial_service.go' <<'CODEX_FILE_8'
package service

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/dushixiang/uart_sms_forwarder/config"
	"github.com/dushixiang/uart_sms_forwarder/internal/models"
	"github.com/go-orz/cache"
	"github.com/google/uuid"
	"github.com/jpillora/backoff"
	"go.bug.st/serial"
	"go.uber.org/zap"
)

const (
	// 缓存键
	CacheKeyDeviceStatus = "device_status"
	// 缓存刷新间隔
	CacheRefreshInterval = 10 * time.Second
	// 缓存过期时间
	CacheTTL = 5 * time.Minute
)

type ScheduledTaskStatusUpdater func(ctx context.Context, msgID string, status models.LastRunStatus) error

// SerialService 串口管理服务
type SerialService struct {
	logger                     *zap.Logger
	config                     config.SerialConfig
	deviceID                   string
	deviceName                 string
	expectedICCID              string
	port                       serial.Port
	textMsgService             *TextMessageService
	notifier                   *Notifier
	propertyService            *PropertyService
	handlers                   map[string]messageHandler
	scheduledTaskStatusUpdater ScheduledTaskStatusUpdater
	wg                         sync.WaitGroup
	writeMu                    sync.Mutex
	// 设备信息缓存
	deviceCache cache.Cache[string, *StatusData]
	// 连接状态管理
	mu        sync.RWMutex
	portName  string // 当前使用的串口名称
	connected bool   // 连接状态

	// 设备的飞行模式查询永远返回 false，无奈只能在应用层处理
	flyMode atomic.Bool
}

// NewSerialService 创建串口服务实例
func NewSerialService(
	logger *zap.Logger,
	config config.SerialConfig,
	textMsgService *TextMessageService,
	notifier *Notifier,
	propertyService *PropertyService,
) *SerialService {
	return NewSerialDeviceService(logger, config.SerialDeviceConfig{
		ID:   "default",
		Name: "默认模块",
		Port: config.Port,
	}, textMsgService, notifier, propertyService)
}

// NewSerialDeviceService 创建指定设备的串口服务实例。
func NewSerialDeviceService(
	logger *zap.Logger,
	device config.SerialDeviceConfig,
	textMsgService *TextMessageService,
	notifier *Notifier,
	propertyService *PropertyService,
) *SerialService {
	if device.ID == "" {
		device.ID = "default"
	}
	if device.Name == "" {
		device.Name = device.ID
	}

	service := &SerialService{
		logger:        logger.With(zap.String("device_id", device.ID), zap.String("device_name", device.Name)),
		config:        config.SerialConfig{Port: device.Port},
		deviceID:      device.ID,
		deviceName:    device.Name,
		expectedICCID: device.ExpectedICCID,
		textMsgService:  textMsgService,
		notifier:        notifier,
		propertyService: propertyService,
		deviceCache:     cache.New[string, *StatusData](CacheTTL),
	}
	service.initMessageHandlers()
	return service
}

func (s *SerialService) DeviceID() string {
	return s.deviceID
}

func (s *SerialService) DeviceName() string {
	return s.deviceName
}

func (s *SerialService) ConfiguredPort() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.config.Port
}

func (s *SerialService) ExpectedICCID() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.expectedICCID
}

func (s *SerialService) UpdateDiscoveredBinding(portName, expectedICCID string) {
	portName = strings.TrimSpace(portName)
	expectedICCID = strings.TrimSpace(expectedICCID)

	s.mu.Lock()
	portChanged := portName != "" && s.config.Port != portName
	if portName != "" {
		s.config.Port = portName
	}
	if expectedICCID != "" {
		s.expectedICCID = expectedICCID
	}
	currentPort := s.port
	s.mu.Unlock()

	if portChanged {
		s.deviceCache.Delete(CacheKeyDeviceStatus)
		if currentPort != nil {
			_ = currentPort.Close()
		}
	}
}

func (s *SerialService) DeviceInfo() SerialDeviceInfo {
	configuredPort := s.ConfiguredPort()
	expectedICCID := s.ExpectedICCID()
	portName, connected := s.getConnectionInfo()
	if portName == "" {
		portName = configuredPort
	}
	return SerialDeviceInfo{
		ID:            s.deviceID,
		Name:          s.deviceName,
		Port:          configuredPort,
		PortName:      portName,
		ExpectedICCID: expectedICCID,
		Connected:     connected,
	}
}

func (s *SerialService) SetScheduledTaskStatusUpdater(updater ScheduledTaskStatusUpdater) {
	s.scheduledTaskStatusUpdater = updater
}

// Start 启动串口服务（使用 backoff 重连机制）
func (s *SerialService) Start() {

	// 启动主循环
	b := &backoff.Backoff{
		Min:    5 * time.Second,
		Max:    1 * time.Minute,
		Factor: 2,
		Jitter: true,
	}

	for {
		err := s.runOnce(b.Reset)

		// 连接失败或断开，使用 backoff 重试
		if err != nil {
			s.setConnected(false)
			retryAfter := b.Duration()
			s.logger.Warn("串口连接异常，将重试",
				zap.Error(err),
				zap.Duration("retry_after", retryAfter))
			s.deviceCache.Delete(CacheKeyDeviceStatus)

			time.Sleep(retryAfter)
		}
	}
}

// setConnected 设置连接状态
func (s *SerialService) setConnected(connected bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.connected = connected
}

// setPortName 设置串口名称
func (s *SerialService) setPortName(portName string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.portName = portName
}

// getConnectionInfo 获取连接信息
func (s *SerialService) getConnectionInfo() (portName string, connected bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.portName, s.connected
}

// runOnce 执行一次连接尝试
func (s *SerialService) runOnce(resetBackoff func()) error {
	// 确定使用的串口
	var selectedPort string
	if configuredPort := s.ConfiguredPort(); configuredPort != "" {
		selectedPort = configuredPort
		s.logger.Info("使用配置的串口", zap.String("port", selectedPort))
	} else {
		// 获取串口列表
		ports, err := serial.GetPortsList()
		if err != nil {
			return fmt.Errorf("获取串口列表失败: %w", err)
		}

		if len(ports) == 0 {
			return fmt.Errorf("未发现可用串口")
		}

		s.logger.Debug("发现可用串口", zap.Strings("ports", ports))

		// 自动检测
		s.logger.Info("开始自动检测串口...")
		selectedPort, err = s.autoDetectPort(ports)
		if err != nil {
			return fmt.Errorf("自动检测串口失败: %w", err)
		}
		s.logger.Info("自动检测到可用串口", zap.String("port", selectedPort))
	}

	// 连接串口
	if err := s.connectSerial(selectedPort); err != nil {
		return fmt.Errorf("连接串口失败: %w", err)
	}

	// 设置连接状态和串口名称
	s.setPortName(selectedPort)
	s.setConnected(true)

	// 重置 backoff（连接成功）
	resetBackoff()

	s.logger.Info("串口连接成功", zap.String("port", selectedPort))

	// 为本次连接创建独立的 context，用于管理连接的生命周期
	connCtx, connCancel := context.WithCancel(context.Background())
	defer connCancel() // 确保退出时取消 context

	// 启动监听 goroutine
	s.wg.Add(1)
	go s.listenSerialData(connCtx, connCancel)

	// 启动定时更新缓存的 goroutine
	s.wg.Add(1)
	go s.periodicCacheUpdate(connCtx)

	// 首次立即发送缓存更新请求
	go s.RequestCacheUpdate()

	// 等待连接断开
	s.wg.Wait()

	// 连接已断开，更新状态
	s.setConnected(false)

	return nil
}

// connectSerial 连接串口
func (s *SerialService) connectSerial(portName string) error {
	mode := &serial.Mode{
		BaudRate: 115200,
		DataBits: 8,
		StopBits: serial.OneStopBit,
		Parity:   serial.NoParity,
	}

	port, err := serial.Open(portName, mode)
	if err != nil {
		return err
	}

	s.port = port
	return nil
}

// autoDetectPort 自动检测可用串口
func (s *SerialService) autoDetectPort(ports []string) (string, error) {
	for _, portName := range ports {
		s.logger.Debug("测试串口", zap.String("port", portName))

		mode := &serial.Mode{
			BaudRate: 115200,
			DataBits: 8,
			StopBits: serial.OneStopBit,
			Parity:   serial.NoParity,
		}

		port, err := serial.Open(portName, mode)
		if err != nil {
			s.logger.Debug("打开串口失败", zap.String("port", portName), zap.Error(err))
			continue
		}

		// 设置读取超时
		port.SetReadTimeout(1 * time.Second)

		// 发送测试命令（使用正确的协议格式）
		testCmd := map[string]string{"action": "get_status"}
		jsonData, _ := json.Marshal(testCmd)
		// 添加协议包围标志
		message := fmt.Sprintf("CMD_START:%s:CMD_END\r\n", string(jsonData))

		_, err = port.Write([]byte(message))
		if err != nil {
			port.Close()
			continue
		}

		// 等待响应
		time.Sleep(500 * time.Millisecond)

		buffer := make([]byte, 4096)
		n, err := port.Read(buffer)
		port.Close()

		if err == nil && n > 0 {
			response := string(buffer[:n])
			if isValidResponse(response) {
				s.logger.Debug("检测到可用串口", zap.String("port", portName))
				return portName, nil
			}
		}
	}

	return "", fmt.Errorf("未检测到可用串口")
}

// listenSerialData 监听串口数据（在独立 goroutine 中运行）
func (s *SerialService) listenSerialData(connCtx context.Context, connCancel context.CancelFunc) {
	defer s.wg.Done()
	defer func() {
		if r := recover(); r != nil {
			s.logger.Error("串口监听 goroutine panic", zap.Any("recover", r))
		}
		// 关闭串口
		if s.port != nil {
			s.port.Close()
			s.port = nil
		}
		// 取消连接 context，通知其他 goroutine 连接已断开
		connCancel()
	}()

	reader := bufio.NewReader(s.port)

	for {
		select {
		case <-connCtx.Done():
			s.logger.Info("串口监听停止")
			return
		default:
			line, err := reader.ReadString('\n')
			if err != nil {
				if err == io.EOF {
					// EOF 可能表示设备断开
					s.logger.Warn("串口读取 EOF，设备可能已断开")
					return
				}
				// 检查 context 是否已取消
				if connCtx.Err() != nil {
					return
				}
				// 其他错误，可能是设备断开或硬件错误
				s.logger.Error("读取串口数据错误，退出监听", zap.Error(err))
				return
			}

			s.processReceivedData(strings.TrimSpace(line))
		}
	}
}

// periodicCacheUpdate 定时更新缓存
func (s *SerialService) periodicCacheUpdate(connCtx context.Context) {
	defer s.wg.Done()
	defer func() {
		if r := recover(); r != nil {
			s.logger.Error("定时更新缓存 goroutine panic", zap.Any("recover", r))
		}
	}()

	ticker := time.NewTicker(CacheRefreshInterval)
	defer ticker.Stop()

	for {
		select {
		case <-connCtx.Done():
			s.logger.Info("停止定时更新缓存")
			return
		case <-ticker.C:
			s.RequestCacheUpdate()
		}
	}
}

// RequestCacheUpdate 请求更新缓存（只发送命令，不等待响应）
func (s *SerialService) RequestCacheUpdate() {
	s.logger.Debug("发送缓存更新请求")

	// 发送获取设备状态命令（包含移动网络信息）
	if err := s.sendJSONCommand(map[string]string{"action": "get_status"}); err != nil {
		s.logger.Error("发送设备状态请求失败", zap.Error(err))
	}
}

// processReceivedData 处理接收到的数据
func (s *SerialService) processReceivedData(data string) {
	s.logger.Sugar().Debugf("received data: %s", data)
	msg, err := parseSMSFrame(data)
	if err != nil {
		if errors.Is(err, errNotSMSFrame) {
			return
		}
		if errors.Is(err, errMissingType) {
			s.logger.Warn("消息类型缺失", zap.String("data", data))
			return
		}
		s.logger.Error("解析串口消息失败", zap.Error(err), zap.String("data", data))
		return
	}

	s.routeMessage(msg)
}

// SendSMS 发送短信
func (s *SerialService) SendSMS(to, content string) (string, error) {
	// 先保存发送记录，状态为 "sending"
	ctx := context.Background()
	msgID := uuid.NewString()
	msg := &models.TextMessage{
		ID:        msgID,
		DeviceID:  s.deviceID,
		From:      "", // 发送方是本机
		To:        to,
		Content:   content,
		Type:      models.MessageTypeOutgoing,
		Status:    models.MessageStatusSending, // 初始状态为发送中
		CreatedAt: time.Now().UnixMilli(),
	}

	if err := s.textMsgService.Save(ctx, msg); err != nil {
		s.logger.Error("保存短信发送记录失败", zap.Error(err))
		return "", err
	}

	// 发送命令，使用消息 ID 作为 request_id
	cmd := map[string]any{
		"action":     "send_sms",
		"to":         to,
		"content":    content,
		"request_id": msgID,
	}

	if err := s.sendJSONCommand(cmd); err != nil {
		s.logger.Error("发送短信命令失败", zap.Error(err))
		// 更新状态为失败
		// 更新状态为失败
		_ = s.textMsgService.UpdateStatusById(ctx, msgID, models.MessageStatusFailed)
		return "", err
	}

	s.logger.Info("发送短信命令成功", zap.String("to", to), zap.String("request_id", msgID))

	return msgID, nil
}

// GetStatus 获取设备状态（从缓存读取，包含 mobile 信息和串口连接状态）
func (s *SerialService) GetStatus() (*StatusData, error) {
	// 获取连接信息
	portName, connected := s.getConnectionInfo()

	// 从缓存读取
	if status, ok := s.deviceCache.Get(CacheKeyDeviceStatus); ok {
		// 更新串口连接信息
		status.DeviceID = s.deviceID
		status.DeviceName = s.deviceName
		status.ExpectedICCID = s.expectedICCID
		status.PortName = portName
		status.Connected = connected

		// 更新飞行模式状态
		status.Flymode = s.FlyMode()
		return status, nil
	}

	// 缓存未命中，但仍然返回连接状态
	status := &StatusData{
		DeviceID:      s.deviceID,
		DeviceName:    s.deviceName,
		ExpectedICCID: s.expectedICCID,
		PortName:      portName,
		Connected:     connected,
	}
	return status, nil
}

func (s *SerialService) FlyMode() bool {
	// 返回当前飞行模式状态
	return s.flyMode.Load()
}

// SetFlymode 设置飞行模式
// enabled: true 表示启用飞行模式，false 表示禁用飞行模式
func (s *SerialService) SetFlymode(enabled bool) error {
	cmd := map[string]any{
		"action":  "set_flymode",
		"enabled": enabled,
	}
	if err := s.sendJSONCommand(cmd); err != nil {
		return err
	}
	// 更新飞行模式状态
	s.flyMode.Store(enabled)
	return nil
}

// RebootMcu 重启模块
func (s *SerialService) RebootMcu() error {
	cmd := map[string]string{"action": "reboot_mcu"}
	if err := s.sendJSONCommand(cmd); err != nil {
		return err
	}
	// 重启后，飞行模式默认关闭
	s.flyMode.Store(false)
	return nil
}

// sendJSONCommand 发送JSON命令到设备
func (s *SerialService) sendJSONCommand(cmd any) error {
	s.writeMu.Lock()
	defer s.writeMu.Unlock()

	if s.port == nil {
		return fmt.Errorf("串口未连接")
	}

	message, jsonData, err := buildCommandMessage(cmd)
	if err != nil {
		return err
	}

	_, err = s.port.Write(message)
	if err != nil {
		return fmt.Errorf("串口写入失败: %w", err)
	}
	s.logger.Sugar().Debugf("send command: %s", jsonData)

	return nil
}
CODEX_FILE_8

mkdir -p 'internal/service'
cat > 'internal/service/serial_manager.go' <<'CODEX_FILE_9'
package service

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/dushixiang/uart_sms_forwarder/config"
	"go.uber.org/zap"
)

// SerialDeviceInfo 是前端和 API 使用的模块摘要。
type SerialDeviceInfo struct {
	ID            string `json:"id"`
	Name          string `json:"name"`
	Port          string `json:"port"`
	PortName      string `json:"portName"`
	ExpectedICCID string `json:"expectedIccid"`
	Connected     bool   `json:"connected"`
}

// SerialManager 管理一个或多个串口模块。
type SerialManager struct {
	logger                     *zap.Logger
	devices                    map[string]*SerialService
	order                      []string
	defaultID                  string
	autoDiscover               bool
	discoveryInterval          time.Duration
	textMsgService             *TextMessageService
	notifier                   *Notifier
	propertyService            *PropertyService
	scheduledTaskStatusUpdater ScheduledTaskStatusUpdater
	mu                         sync.RWMutex
}

const serialAutoDiscoveryInterval = 30 * time.Second

func NewSerialManager(
	logger *zap.Logger,
	serialConfig config.SerialConfig,
	textMsgService *TextMessageService,
	notifier *Notifier,
	propertyService *PropertyService,
) (*SerialManager, error) {
	configuredDevices := serialConfig.NormalizedDevices()
	if serialConfig.AutoDiscover {
		var err error
		configuredDevices, err = discoverSerialDevices(logger, configuredDevices)
		if err != nil {
			return nil, err
		}
	}
	if len(configuredDevices) == 0 {
		return nil, fmt.Errorf("未配置串口模块")
	}

	manager := &SerialManager{
		logger:            logger,
		devices:           make(map[string]*SerialService, len(configuredDevices)),
		order:             make([]string, 0, len(configuredDevices)),
		autoDiscover:      serialConfig.AutoDiscover,
		discoveryInterval: serialAutoDiscoveryInterval,
		textMsgService:    textMsgService,
		notifier:          notifier,
		propertyService:   propertyService,
	}

	seenIDs := make(map[string]struct{}, len(configuredDevices))
	seenPorts := make(map[string]string, len(configuredDevices))
	multiDeviceMode := len(serialConfig.Devices) > 0 || serialConfig.AutoDiscover

	for _, device := range configuredDevices {
		device.ID = strings.TrimSpace(device.ID)
		device.Name = strings.TrimSpace(device.Name)
		device.Port = strings.TrimSpace(device.Port)
		device.ExpectedICCID = strings.TrimSpace(device.ExpectedICCID)

		if device.ID == "" {
			return nil, fmt.Errorf("串口模块 ID 不能为空")
		}
		if _, ok := seenIDs[device.ID]; ok {
			return nil, fmt.Errorf("串口模块 ID 重复: %s", device.ID)
		}
		if multiDeviceMode && device.Port == "" {
			return nil, fmt.Errorf("多模块模式下必须为 %s 配置固定 Port", device.ID)
		}
		if device.Port != "" {
			if owner, ok := seenPorts[device.Port]; ok {
				return nil, fmt.Errorf("串口 %s 同时绑定到 %s 和 %s", device.Port, owner, device.ID)
			}
			seenPorts[device.Port] = device.ID
		}
		if device.Name == "" {
			device.Name = device.ID
		}

		seenIDs[device.ID] = struct{}{}
		if manager.defaultID == "" {
			manager.defaultID = device.ID
		}
		manager.order = append(manager.order, device.ID)
		manager.devices[device.ID] = NewSerialDeviceService(
			logger,
			device,
			textMsgService,
			notifier,
			propertyService,
		)
	}

	return manager, nil
}

func (m *SerialManager) Start() {
	m.mu.RLock()
	services := make([]*SerialService, 0, len(m.order))
	ids := append([]string(nil), m.order...)
	for _, id := range ids {
		services = append(services, m.devices[id])
	}
	autoDiscover := m.autoDiscover
	m.mu.RUnlock()

	for i, service := range services {
		go service.Start()
		m.logger.Info("串口模块服务已启动",
			zap.String("device_id", ids[i]),
			zap.String("port", service.ConfiguredPort()))
	}

	if autoDiscover {
		go m.autoDiscoveryLoop()
	}
}

func (m *SerialManager) SetScheduledTaskStatusUpdater(updater ScheduledTaskStatusUpdater) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.scheduledTaskStatusUpdater = updater
	for _, service := range m.devices {
		service.SetScheduledTaskStatusUpdater(updater)
	}
}

func (m *SerialManager) DefaultDeviceID() string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.defaultID
}

func (m *SerialManager) ResolveDeviceID(deviceID string) string {
	if strings.TrimSpace(deviceID) != "" {
		return strings.TrimSpace(deviceID)
	}
	return m.DefaultDeviceID()
}

func (m *SerialManager) Device(deviceID string) (*SerialService, error) {
	deviceID = m.ResolveDeviceID(deviceID)

	m.mu.RLock()
	defer m.mu.RUnlock()

	service, ok := m.devices[deviceID]
	if !ok {
		return nil, fmt.Errorf("串口模块不存在: %s", deviceID)
	}
	return service, nil
}

func (m *SerialManager) ListDevices() []SerialDeviceInfo {
	m.mu.RLock()
	defer m.mu.RUnlock()

	devices := make([]SerialDeviceInfo, 0, len(m.order))
	for _, id := range m.order {
		devices = append(devices, m.devices[id].DeviceInfo())
	}
	return devices
}

func (m *SerialManager) GetStatus(deviceID string) (*StatusData, error) {
	service, err := m.Device(deviceID)
	if err != nil {
		return nil, err
	}
	return service.GetStatus()
}

func (m *SerialManager) GetAllStatus() ([]*StatusData, error) {
	m.mu.RLock()
	ids := append([]string(nil), m.order...)
	m.mu.RUnlock()

	statuses := make([]*StatusData, 0, len(ids))
	for _, id := range ids {
		status, err := m.GetStatus(id)
		if err != nil {
			return nil, err
		}
		statuses = append(statuses, status)
	}
	return statuses, nil
}

func (m *SerialManager) SendSMS(deviceID, to, content string) (string, error) {
	service, err := m.Device(deviceID)
	if err != nil {
		return "", err
	}
	return service.SendSMS(to, content)
}

func (m *SerialManager) FlyMode(deviceID string) (bool, error) {
	service, err := m.Device(deviceID)
	if err != nil {
		return false, err
	}
	return service.FlyMode(), nil
}

func (m *SerialManager) SetFlymode(deviceID string, enabled bool) error {
	service, err := m.Device(deviceID)
	if err != nil {
		return err
	}
	return service.SetFlymode(enabled)
}

func (m *SerialManager) RebootMcu(deviceID string) error {
	service, err := m.Device(deviceID)
	if err != nil {
		return err
	}
	return service.RebootMcu()
}

func (m *SerialManager) RequestCacheUpdate(deviceID string) error {
	service, err := m.Device(deviceID)
	if err != nil {
		return err
	}
	service.RequestCacheUpdate()
	return nil
}

func (m *SerialManager) RequestAllCacheUpdate(ctx context.Context) {
	m.mu.RLock()
	services := make([]*SerialService, 0, len(m.order))
	for _, id := range m.order {
		services = append(services, m.devices[id])
	}
	m.mu.RUnlock()

	for _, service := range services {
		select {
		case <-ctx.Done():
			return
		default:
			service.RequestCacheUpdate()
		}
	}
}

func (m *SerialManager) autoDiscoveryLoop() {
	ticker := time.NewTicker(m.discoveryInterval)
	defer ticker.Stop()

	for range ticker.C {
		if err := m.refreshDiscoveredDevices(); err != nil {
			m.logger.Warn("serial hotplug discovery failed", zap.Error(err))
		}
	}
}

func (m *SerialManager) refreshDiscoveredDevices() error {
	configured, excludedPorts := m.discoverySnapshot()
	devices, err := discoverSerialDevicesExcluding(m.logger, configured, excludedPorts)
	if err != nil {
		return err
	}
	m.applyDiscoveredDevices(devices)
	return nil
}

func (m *SerialManager) discoverySnapshot() ([]config.SerialDeviceConfig, map[string]struct{}) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	configured := make([]config.SerialDeviceConfig, 0, len(m.order))
	excludedPorts := make(map[string]struct{}, len(m.order))
	for _, id := range m.order {
		service := m.devices[id]
		info := service.DeviceInfo()
		configured = append(configured, config.SerialDeviceConfig{
			ID:            info.ID,
			Name:          info.Name,
			Port:          info.Port,
			ExpectedICCID: info.ExpectedICCID,
		})
		if info.Connected {
			if info.Port != "" {
				excludedPorts[info.Port] = struct{}{}
			}
			if info.PortName != "" {
				excludedPorts[info.PortName] = struct{}{}
			}
		}
	}
	return configured, excludedPorts
}

func (m *SerialManager) applyDiscoveredDevices(configs []config.SerialDeviceConfig) {
	m.mu.Lock()
	defer m.mu.Unlock()

	for _, device := range configs {
		device.ID = strings.TrimSpace(device.ID)
		device.Name = strings.TrimSpace(device.Name)
		device.Port = strings.TrimSpace(device.Port)
		device.ExpectedICCID = strings.TrimSpace(device.ExpectedICCID)
		if device.ID == "" || device.Port == "" {
			continue
		}
		if device.Name == "" {
			device.Name = displaySerialDeviceName(device.ID)
		}

		if service, ok := m.devices[device.ID]; ok {
			service.UpdateDiscoveredBinding(device.Port, device.ExpectedICCID)
			continue
		}

		service := NewSerialDeviceService(
			m.logger,
			device,
			m.textMsgService,
			m.notifier,
			m.propertyService,
		)
		service.SetScheduledTaskStatusUpdater(m.scheduledTaskStatusUpdater)
		m.devices[device.ID] = service
		m.order = append(m.order, device.ID)
		if m.defaultID == "" {
			m.defaultID = device.ID
		}
		go service.Start()
		m.logger.Info("serial hotplug module added",
			zap.String("device_id", device.ID),
			zap.String("port", device.Port))
	}
}
CODEX_FILE_9

mkdir -p 'internal/service'
cat > 'internal/service/serial_discovery.go' <<'CODEX_FILE_10'
package service

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/dushixiang/uart_sms_forwarder/config"
	"go.bug.st/serial"
	"go.uber.org/zap"
)

const (
	serialProbeTimeout = 5 * time.Second
	serialReadTimeout  = 250 * time.Millisecond
	serialProbeMaxRead = 8192
)

type discoveredSerialDevice struct {
	Port   string
	ICCID  string
	IMSI   string
	Number string
}

func discoverSerialDevices(logger *zap.Logger, configured []config.SerialDeviceConfig) ([]config.SerialDeviceConfig, error) {
	discovered, err := probeDiscoveredSerialDevices(logger, nil)
	if err != nil {
		return nil, err
	}

	return assignDiscoveredSerialDevices(logger, configured, discovered), nil
}

func discoverSerialDevicesExcluding(logger *zap.Logger, configured []config.SerialDeviceConfig, excludedPorts map[string]struct{}) ([]config.SerialDeviceConfig, error) {
	discovered, err := probeDiscoveredSerialDevices(logger, excludedPorts)
	if err != nil {
		if len(configured) > 0 {
			return configured, nil
		}
		return nil, err
	}

	return assignDiscoveredSerialDevices(logger, configured, discovered), nil
}

func probeDiscoveredSerialDevices(logger *zap.Logger, excludedPorts map[string]struct{}) ([]discoveredSerialDevice, error) {
	candidates, err := serialDiscoveryCandidates()
	if err != nil {
		return nil, err
	}
	if len(candidates) == 0 {
		return nil, fmt.Errorf("no serial ports found for auto discovery")
	}

	discovered := make([]discoveredSerialDevice, 0, len(candidates))
	for _, portName := range candidates {
		if serialPortExcluded(portName, excludedPorts) {
			continue
		}
		device, err := probeSerialDevice(portName)
		if err != nil {
			logger.Debug("serial auto discovery skipped port",
				zap.String("port", portName),
				zap.Error(err))
			continue
		}
		logger.Info("serial auto discovery found module",
			zap.String("port", device.Port),
			zap.String("iccid", device.ICCID),
			zap.String("number", device.Number))
		discovered = append(discovered, device)
	}

	if len(discovered) == 0 {
		return nil, fmt.Errorf("auto discovery did not find any uart_sms_forwarder modules")
	}

	return discovered, nil
}

func serialPortExcluded(portName string, excludedPorts map[string]struct{}) bool {
	if len(excludedPorts) == 0 {
		return false
	}
	if _, ok := excludedPorts[portName]; ok {
		return true
	}
	resolved, err := filepath.EvalSymlinks(portName)
	if err != nil {
		return false
	}
	if _, ok := excludedPorts[resolved]; ok {
		return true
	}
	for excluded := range excludedPorts {
		if resolvedExcluded, err := filepath.EvalSymlinks(excluded); err == nil && resolvedExcluded == resolved {
			return true
		}
	}
	return false
}

func serialDiscoveryCandidates() ([]string, error) {
	var candidates []string
	seenTargets := make(map[string]struct{})

	add := func(portName string) {
		target := portName
		if resolved, err := filepath.EvalSymlinks(portName); err == nil {
			target = resolved
		}
		if !isUSBSerialPort(target) {
			return
		}
		if _, ok := seenTargets[target]; ok {
			return
		}
		seenTargets[target] = struct{}{}
		candidates = append(candidates, portName)
	}

	byPathPorts, _ := filepath.Glob("/dev/serial/by-path/*")
	sort.Strings(byPathPorts)
	for _, portName := range byPathPorts {
		add(portName)
	}

	ports, err := serial.GetPortsList()
	if err != nil && len(candidates) == 0 {
		return nil, fmt.Errorf("list serial ports: %w", err)
	}
	sort.Strings(ports)
	for _, portName := range ports {
		add(portName)
	}

	return candidates, nil
}

func isUSBSerialPort(portName string) bool {
	base := filepath.Base(portName)
	return strings.HasPrefix(base, "ttyACM") || strings.HasPrefix(base, "ttyUSB") || strings.HasPrefix(base, "COM")
}

func probeSerialDevice(portName string) (discoveredSerialDevice, error) {
	mode := &serial.Mode{
		BaudRate: 115200,
		DataBits: 8,
		StopBits: serial.OneStopBit,
		Parity:   serial.NoParity,
	}

	port, err := serial.Open(portName, mode)
	if err != nil {
		return discoveredSerialDevice{}, err
	}
	defer port.Close()

	_ = port.SetReadTimeout(serialReadTimeout)

	message, _, err := buildCommandMessage(map[string]string{"action": "get_status"})
	if err != nil {
		return discoveredSerialDevice{}, err
	}
	if _, err := port.Write(message); err != nil {
		return discoveredSerialDevice{}, fmt.Errorf("write probe command: %w", err)
	}

	var response strings.Builder
	buf := make([]byte, 1024)
	deadline := time.Now().Add(serialProbeTimeout)
	for time.Now().Before(deadline) && response.Len() < serialProbeMaxRead {
		n, err := port.Read(buf)
		if n > 0 {
			response.Write(buf[:n])
			if status, ok := parseStatusResponseFromBuffer(response.String()); ok {
				return discoveredSerialDevice{
					Port:   portName,
					ICCID:  normalizeICCID(status.Mobile.Iccid),
					IMSI:   strings.TrimSpace(status.Mobile.Imsi),
					Number: strings.TrimSpace(status.Mobile.Number),
				}, nil
			}
		}
		if err != nil && !isReadTimeout(err) {
			return discoveredSerialDevice{}, fmt.Errorf("read probe response: %w", err)
		}
	}

	return discoveredSerialDevice{}, fmt.Errorf("no status response")
}

func isReadTimeout(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "timeout") || strings.Contains(msg, "timed out")
}

func parseStatusResponseFromBuffer(data string) (*StatusData, bool) {
	rest := data
	for {
		start := strings.Index(rest, smsPrefix)
		if start < 0 {
			return nil, false
		}
		rest = rest[start:]
		end := strings.Index(rest, smsSuffix)
		if end < 0 {
			return nil, false
		}

		frame := rest[:end+len(smsSuffix)]
		msg, err := parseSMSFrame(frame)
		if err == nil && msg.Type == "status_response" {
			var status StatusData
			if err := json.Unmarshal([]byte(msg.JSON), &status); err == nil {
				return &status, true
			}
		}
		rest = rest[end+len(smsSuffix):]
	}
}

func normalizeICCID(iccid string) string {
	iccid = strings.TrimSpace(iccid)
	if strings.EqualFold(iccid, "unknown") {
		return ""
	}
	return iccid
}

func assignDiscoveredSerialDevices(
	logger *zap.Logger,
	configured []config.SerialDeviceConfig,
	discovered []discoveredSerialDevice,
) []config.SerialDeviceConfig {
	byICCID := make(map[string]discoveredSerialDevice, len(discovered))
	for _, device := range discovered {
		if device.ICCID != "" {
			byICCID[device.ICCID] = device
		}
	}

	usedPorts := make(map[string]struct{}, len(discovered))
	usedIDs := make(map[string]struct{}, len(configured)+len(discovered))
	devices := make([]config.SerialDeviceConfig, 0, len(configured)+len(discovered))

	for _, device := range configured {
		device.ID = strings.TrimSpace(device.ID)
		device.Name = strings.TrimSpace(device.Name)
		device.Port = strings.TrimSpace(device.Port)
		device.ExpectedICCID = strings.TrimSpace(device.ExpectedICCID)
		if device.ID == "" {
			device.ID = nextSerialDeviceID(usedIDs)
		}
		if device.Name == "" {
			device.Name = device.ID
		}
		usedIDs[device.ID] = struct{}{}

		if device.ExpectedICCID != "" {
			if found, ok := byICCID[device.ExpectedICCID]; ok {
				device.Port = found.Port
				usedPorts[found.Port] = struct{}{}
				devices = append(devices, device)
				continue
			}
			if device.Port == "" {
				logger.Warn("configured serial module not found during auto discovery",
					zap.String("device_id", device.ID),
					zap.String("expected_iccid", device.ExpectedICCID))
				continue
			}
		}

		if device.Port == "" {
			if found, ok := firstUnusedDiscovered(discovered, usedPorts); ok {
				device.Port = found.Port
				device.ExpectedICCID = found.ICCID
				usedPorts[found.Port] = struct{}{}
			}
		} else {
			usedPorts[device.Port] = struct{}{}
		}

		if device.Port != "" {
			devices = append(devices, device)
		}
	}

	for _, found := range discovered {
		if _, ok := usedPorts[found.Port]; ok {
			continue
		}
		id := nextSerialDeviceID(usedIDs)
		usedIDs[id] = struct{}{}
		usedPorts[found.Port] = struct{}{}
		devices = append(devices, config.SerialDeviceConfig{
			ID:            id,
			Name:          displaySerialDeviceName(id),
			Port:          found.Port,
			ExpectedICCID: found.ICCID,
		})
	}

	return devices
}

func firstUnusedDiscovered(discovered []discoveredSerialDevice, usedPorts map[string]struct{}) (discoveredSerialDevice, bool) {
	for _, device := range discovered {
		if _, ok := usedPorts[device.Port]; !ok {
			return device, true
		}
	}
	return discoveredSerialDevice{}, false
}

func nextSerialDeviceID(used map[string]struct{}) string {
	for i := 1; ; i++ {
		id := config.DefaultSerialDeviceID(i - 1)
		if _, ok := used[id]; !ok {
			return id
		}
	}
}


func displaySerialDeviceName(id string) string {
	if strings.HasPrefix(strings.ToLower(id), "sim") {
		suffix := strings.TrimSpace(id[3:])
		if suffix != "" {
			return "SIM " + suffix
		}
	}
	return strings.ToUpper(id)
}
CODEX_FILE_10

mkdir -p 'internal/service'
cat > 'internal/service/serial_discovery_test.go' <<'CODEX_FILE_11'
package service

import (
	"testing"

	"github.com/dushixiang/uart_sms_forwarder/config"
	"go.uber.org/zap"
)

func TestParseStatusResponseFromBuffer(t *testing.T) {
	status, ok := parseStatusResponseFromBuffer(`noise SMS_START:{"type":"status_response","mobile":{"iccid":"ICCID_SAMPLE_1","imsi":"460000000000001","number":"TEST_NUMBER_1"}}:SMS_END tail`)
	if !ok {
		t.Fatal("expected status response")
	}
	if status.Mobile.Iccid != "ICCID_SAMPLE_1" {
		t.Fatalf("unexpected iccid: %s", status.Mobile.Iccid)
	}
}

func TestAssignDiscoveredSerialDevicesByICCID(t *testing.T) {
	devices := assignDiscoveredSerialDevices(zap.NewNop(), []config.SerialDeviceConfig{
		{ID: "sim1", Name: "SIM 1", ExpectedICCID: "iccid-1"},
		{ID: "sim2", Name: "SIM 2", ExpectedICCID: "iccid-2"},
	}, []discoveredSerialDevice{
		{Port: "/dev/serial/by-path/modem-b", ICCID: "iccid-2"},
		{Port: "/dev/serial/by-path/modem-a", ICCID: "iccid-1"},
	})

	if len(devices) != 2 {
		t.Fatalf("expected 2 devices, got %d", len(devices))
	}
	if devices[0].ID != "sim1" || devices[0].Port != "/dev/serial/by-path/modem-a" {
		t.Fatalf("sim1 was not bound by ICCID: %+v", devices[0])
	}
	if devices[1].ID != "sim2" || devices[1].Port != "/dev/serial/by-path/modem-b" {
		t.Fatalf("sim2 was not bound by ICCID: %+v", devices[1])
	}
}

func TestAssignDiscoveredSerialDevicesAppendsNewModules(t *testing.T) {
	devices := assignDiscoveredSerialDevices(zap.NewNop(), []config.SerialDeviceConfig{
		{ID: "sim1", Name: "SIM 1", ExpectedICCID: "iccid-1"},
	}, []discoveredSerialDevice{
		{Port: "/dev/serial/by-path/modem-a", ICCID: "iccid-1"},
		{Port: "/dev/serial/by-path/modem-b", ICCID: "iccid-2"},
	})

	if len(devices) != 2 {
		t.Fatalf("expected 2 devices, got %d", len(devices))
	}
	if devices[1].ID != "sim2" || devices[1].ExpectedICCID != "iccid-2" {
		t.Fatalf("new module was not appended as sim2: %+v", devices[1])
	}
}

func TestNormalizeICCID(t *testing.T) {
	if got := normalizeICCID(" unknown "); got != "" {
		t.Fatalf("expected unknown ICCID to be empty, got %q", got)
	}
	if got := normalizeICCID("ICCID_SAMPLE_1"); got != "ICCID_SAMPLE_1" {
		t.Fatalf("unexpected normalized ICCID: %q", got)
	}
}

func TestDisplaySerialDeviceName(t *testing.T) {
	if got := displaySerialDeviceName("sim12"); got != "SIM 12" {
		t.Fatalf("unexpected device name: %q", got)
	}
}
CODEX_FILE_11

mkdir -p 'internal/service'
cat > 'internal/service/notification_filter_test.go' <<'CODEX_FILE_12'
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
CODEX_FILE_12

mkdir -p 'web/src/api'
cat > 'web/src/api/property.ts' <<'CODEX_FILE_13'
// ==================== 通用 Property 接口 ====================

// 通用的 Property 响应类型
import apiClient from "@/api/client.ts";

export interface PropertyResponse<T> {
    id: string;
    name: string;
    value: T;
}

// 通用的获取 Property 方法
export const getProperty = async <T>(propertyId: string): Promise<T> => {
    const response = await apiClient.get<PropertyResponse<T>>(`/properties/${propertyId}`);
    return response.value;
};

// 通用的保存 Property 方法
export const saveProperty = async <T>(propertyId: string, name: string, value: T): Promise<void> => {
    await apiClient.put(`/properties/${propertyId}`, {
        name,
        value,
    });
};

// ==================== 通知渠道配置 ====================

const PROPERTY_ID_NOTIFICATION_CHANNELS = 'notification_channels';

// 通知渠道配置（通过 type 标识，不再使用独立ID）
export interface NotificationChannel {
    id?: string;
    name?: string;
    type: 'dingtalk' | 'wecom' | 'feishu' | 'email' | 'webhook' | 'telegram'; // 渠道类型，作为唯一标识
    enabled: boolean; // 是否启用
    deviceIds?: string[]; // 适用模块；为空表示全部 SIM
    config: Record<string, any>; // JSON配置，根据type不同而不同
}

// 获取通知渠道列表
export const getNotificationChannels = async (): Promise<NotificationChannel[]> => {
    const channels = await getProperty<NotificationChannel[]>(PROPERTY_ID_NOTIFICATION_CHANNELS);
    return channels || [];
};

// 保存通知渠道列表
export const saveNotificationChannels = async (channels: NotificationChannel[]): Promise<void> => {
    return saveProperty(PROPERTY_ID_NOTIFICATION_CHANNELS, '通知渠道配置', channels);
};

// 测试通知渠道（从数据库读取配置）
export const testNotificationChannel = async (channel: Pick<NotificationChannel, 'id' | 'type'>): Promise<{ message: string }> => {
    return await apiClient.post<{ message: string }>(`/notifications/${channel.type}/test`, null, {
        params: channel.id ? {channelId: channel.id} : undefined,
    });
};

export interface Version {
    version: string;
}

export const getVersion = () => {
    return apiClient.get<Version>('/version');
}
CODEX_FILE_13

mkdir -p 'web/src/pages'
cat > 'web/src/pages/NotificationChannels.tsx' <<'CODEX_FILE_14'
import {useEffect, useMemo, useState} from 'react';
import {Bell, Loader2, Plus, Save, TestTube, Trash2} from 'lucide-react';
import {useMutation, useQuery, useQueryClient} from '@tanstack/react-query';
import {toast} from 'sonner';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Textarea} from '@/components/ui/textarea';
import {Card, CardContent, CardDescription, CardHeader, CardTitle} from '@/components/ui/card';
import {getDevices} from '@/api/serial.ts';
import {
    getNotificationChannels,
    type NotificationChannel,
    saveNotificationChannels,
    testNotificationChannel,
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
            return {smtpHost: '', smtpPort: '587', username: '', password: '', from: '', to: '', subject: '收到新短信 - {{from}}'};
        case 'telegram':
            return {apiToken: '', userid: '', proxyEnabled: false, proxyUrl: '', proxyUsername: '', proxyPassword: ''};
        default:
            return {secretKey: '', signSecret: ''};
    }
}

function makeChannel(type: ChannelType): NotificationChannel {
    const suffix = Date.now().toString(36);
    return {
        id: `${type}-${suffix}`,
        name: channelLabel(type),
        type,
        enabled: true,
        deviceIds: [],
        config: defaultConfig(type),
    };
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
        if (typeof value === 'boolean') return value;
        if (value && typeof value === 'object') return Object.keys(value).length > 0;
        return value !== undefined && value !== null;
    });
}

function requiredMissing(channel: NotificationChannel) {
    const cfg = channel.config || {};
    switch (channel.type) {
        case 'dingtalk':
        case 'feishu':
        case 'wecom':
            return !String(cfg.secretKey || '').trim();
        case 'webhook':
            return !String(cfg.url || '').trim() || !String(cfg.body || '').trim();
        case 'email':
            return !String(cfg.smtpHost || '').trim() || !String(cfg.to || '').trim();
        case 'telegram':
            return !String(cfg.apiToken || '').trim() || !String(cfg.userid || '').trim();
        default:
            return false;
    }
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

export default function NotificationChannels() {
    const queryClient = useQueryClient();
    const [draft, setDraft] = useState<NotificationChannel[]>([]);
    const [newType, setNewType] = useState<ChannelType>('dingtalk');

    const {data: channels = [], isLoading} = useQuery({
        queryKey: ['notificationChannels'],
        queryFn: getNotificationChannels,
    });

    const {data: devices = []} = useQuery({
        queryKey: ['serialDevicesForNotifications'],
        queryFn: getDevices,
        refetchInterval: 10000,
    });

    useEffect(() => {
        setDraft(channels.map(withClientDefaults));
    }, [channels]);

    const saveMutation = useMutation({
        mutationFn: saveNotificationChannels,
        onSuccess: () => {
            toast.success('保存成功');
            queryClient.invalidateQueries({queryKey: ['notificationChannels']});
        },
        onError: (error: unknown) => {
            console.error('保存失败:', error);
            toast.error('保存失败');
        },
    });

    const testMutation = useMutation({
        mutationFn: testNotificationChannel,
        onSuccess: () => toast.success('测试通知已发送'),
        onError: (error: unknown) => {
            console.error('测试失败:', error);
            toast.error('测试失败，请检查该渠道配置');
        },
    });

    const deviceOptions = useMemo(() => devices.map((device) => ({
        id: device.id,
        label: device.name || device.id.toUpperCase(),
    })), [devices]);

    const updateChannel = (index: number, patch: Partial<NotificationChannel>) => {
        setDraft((prev) => prev.map((channel, i) => i === index ? {...channel, ...patch} : channel));
    };

    const updateConfig = (index: number, key: string, value: any) => {
        setDraft((prev) => prev.map((channel, i) => {
            if (i !== index) return channel;
            return {...channel, config: {...(channel.config || {}), [key]: value}};
        }));
    };

    const removeChannel = (index: number) => {
        setDraft((prev) => prev.filter((_, i) => i !== index));
    };

    const addChannel = () => {
        setDraft((prev) => [...prev, makeChannel(newType)]);
    };

    const toggleDevice = (index: number, deviceId: string) => {
        setDraft((prev) => prev.map((channel, i) => {
            if (i !== index) return channel;
            const current = channel.deviceIds || [];
            const effective = current.length === 0 ? deviceOptions.map((device) => device.id) : current;
            const next = effective.includes(deviceId)
                ? effective.filter((id) => id !== deviceId)
                : Array.from(new Set([...effective, deviceId]));
            return {...channel, deviceIds: next};
        }));
    };

    const testChannel = (channel: NotificationChannel) => {
        const normalized = withClientDefaults(channel, 0);
        if (requiredMissing(normalized)) {
            toast.error(`${channelLabel(normalized.type)} 缺少必填配置`);
            return;
        }
        testMutation.mutate({id: normalized.id, type: normalized.type});
    };

    const save = () => {
        const next = normalizeForSave(draft);
        const invalid = next.find((channel) => channel.enabled && requiredMissing(channel));
        if (invalid) {
            toast.error(`${invalid.name || channelLabel(invalid.type)} 缺少必填配置`);
            return;
        }
        saveMutation.mutate(next);
    };

    const renderDeviceScope = (channel: NotificationChannel, index: number) => {
        if (deviceOptions.length === 0) return null;
        const selected = channel.deviceIds || [];
        const allDevices = selected.length === 0;

        return (
            <div className="rounded-md border border-gray-200 bg-gray-50 p-3">
                <div className="mb-2 flex items-center justify-between gap-3">
                    <div>
                        <div className="text-xs font-semibold text-gray-700">适用 SIM 卡</div>
                        <div className="text-xs text-gray-400">不选择表示所有 SIM 都推送到这个渠道</div>
                    </div>
                    <Button type="button" variant="outline" size="sm" className="h-8" onClick={() => updateChannel(index, {deviceIds: []})}>
                        全部
                    </Button>
                </div>
                <div className="flex flex-wrap gap-2">
                    {deviceOptions.map((device) => {
                        const checked = allDevices || selected.includes(device.id);
                        return (
                            <label
                                key={device.id}
                                className={`flex cursor-pointer items-center gap-2 rounded-md border px-3 py-1.5 text-sm ${checked ? 'border-blue-200 bg-blue-50 text-blue-700' : 'border-gray-200 bg-white text-gray-600'}`}
                            >
                                <input
                                    type="checkbox"
                                    className="h-4 w-4"
                                    checked={checked}
                                    onChange={() => toggleDevice(index, device.id)}
                                />
                                <span>{device.label}</span>
                            </label>
                        );
                    })}
                </div>
            </div>
        );
    };

    const renderConfig = (channel: NotificationChannel, index: number) => {
        const cfg = channel.config || {};

        if (channel.type === 'dingtalk' || channel.type === 'feishu' || channel.type === 'wecom') {
            return (
                <div className="grid gap-4 md:grid-cols-2">
                    <div>
                        <label className="mb-2 block text-xs font-semibold text-gray-600">访问令牌</label>
                        <Input
                            value={String(cfg.secretKey || '')}
                            onChange={(e) => updateConfig(index, 'secretKey', e.target.value)}
                            placeholder={channel.type === 'dingtalk' ? 'access_token' : 'webhook key'}
                            className="font-mono"
                        />
                    </div>
                    {channel.type !== 'wecom' && (
                        <div>
                            <label className="mb-2 block text-xs font-semibold text-gray-600">加签密钥</label>
                            <Input
                                value={String(cfg.signSecret || '')}
                                onChange={(e) => updateConfig(index, 'signSecret', e.target.value)}
                                placeholder="可选"
                                className="font-mono"
                            />
                        </div>
                    )}
                </div>
            );
        }

        if (channel.type === 'webhook') {
            return (
                <div className="space-y-4">
                    <div className="grid gap-4 md:grid-cols-[1fr_160px]">
                        <div>
                            <label className="mb-2 block text-xs font-semibold text-gray-600">URL</label>
                            <Input value={String(cfg.url || '')} onChange={(e) => updateConfig(index, 'url', e.target.value)} className="font-mono"/>
                        </div>
                        <div>
                            <label className="mb-2 block text-xs font-semibold text-gray-600">方法</label>
                            <select
                                value={String(cfg.method || 'POST')}
                                onChange={(e) => updateConfig(index, 'method', e.target.value)}
                                className="h-10 w-full rounded-md border border-gray-200 bg-white px-3 text-sm"
                            >
                                {['POST', 'PUT', 'PATCH', 'GET', 'DELETE'].map((method) => <option key={method} value={method}>{method}</option>)}
                            </select>
                        </div>
                    </div>
                    <div>
                        <label className="mb-2 block text-xs font-semibold text-gray-600">Content-Type</label>
                        <Input value={String(cfg.contentType || 'application/json; charset=utf-8')} onChange={(e) => updateConfig(index, 'contentType', e.target.value)} className="font-mono"/>
                    </div>
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
                    <input
                        type="checkbox"
                        checked={Boolean(cfg.proxyEnabled)}
                        onChange={(e) => updateConfig(index, 'proxyEnabled', e.target.checked)}
                    />
                    启用 HTTP 代理
                </label>
                <InputField label="代理地址" value={cfg.proxyUrl} onChange={(value) => updateConfig(index, 'proxyUrl', value)}/>
                <InputField label="代理用户名" value={cfg.proxyUsername} onChange={(value) => updateConfig(index, 'proxyUsername', value)}/>
                <InputField label="代理密码" value={cfg.proxyPassword} onChange={(value) => updateConfig(index, 'proxyPassword', value)} type="password"/>
            </div>
        );
    };

    if (isLoading) {
        return (
            <div className="flex items-center justify-center py-20">
                <div className="h-12 w-12 animate-spin rounded-full border-b-2 border-blue-600"/>
            </div>
        );
    }

    return (
        <div className="space-y-6">
            <div className="border-b border-gray-200 pb-5">
                <h1 className="text-2xl font-bold text-gray-900">通知渠道管理</h1>
                <p className="mt-3 text-sm text-gray-500">每条渠道独立配置，可以绑定到指定 SIM 卡。</p>
            </div>

            <div className="flex flex-wrap items-center gap-3">
                <select
                    value={newType}
                    onChange={(e) => setNewType(e.target.value as ChannelType)}
                    className="h-10 rounded-md border border-gray-200 bg-white px-3 text-sm"
                >
                    {CHANNEL_TYPES.map((item) => <option key={item.type} value={item.type}>{item.label}</option>)}
                </select>
                <Button type="button" onClick={addChannel}>
                    <Plus className="mr-2 h-4 w-4"/>
                    新增渠道
                </Button>
            </div>

            <div className="grid gap-5">
                {draft.length === 0 && (
                    <div className="rounded-md border border-dashed border-gray-300 p-8 text-center text-sm text-gray-500">
                        还没有通知渠道
                    </div>
                )}

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
                                            <CardDescription className="mt-1">
                                                {meta?.description} · {selected.length === 0 ? '全部 SIM' : selected.join(', ')}
                                            </CardDescription>
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-2">
                                        <Button type="button" variant="outline" size="sm" disabled={testMutation.isPending || !channel.enabled} onClick={() => testChannel(channel)}>
                                            <TestTube className="mr-2 h-4 w-4"/>
                                            测试
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
                                    <div>
                                        <label className="mb-2 block text-xs font-semibold text-gray-600">渠道名称</label>
                                        <Input value={channel.name || ''} onChange={(e) => updateChannel(index, {name: e.target.value})}/>
                                    </div>
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
            <Input
                type={type}
                value={String(value || '')}
                onChange={(e) => onChange(e.target.value)}
                className="font-mono"
            />
        </div>
    );
}
CODEX_FILE_14

echo 'Formatting Go files...' 
gofmt -w internal/models/property.go internal/service/property_service.go internal/handler/property_handler.go internal/handler/property_handler_test.go internal/service/serial_handlers_sms.go internal/service/notifier.go internal/service/serial_service.go internal/service/serial_manager.go internal/service/serial_discovery.go internal/service/serial_discovery_test.go internal/service/notification_filter_test.go

echo 'Checking for obvious private-looking values in source/docs...' 
if rg -n '\+86(13|14|15|16|17|18|19)[0-9]{9}|ExpectedICCID: \"[0-9A-Fa-f]{18,22}\"|Secret: \"[0-9a-f]{32,}\"|admin: .*[\$]2[aby][\$]' internal web README.md config.example.yaml 2>/dev/null; then echo 'Found private-looking value, aborting.'; exit 1; fi

echo 'Running Go tests...' 
go test ./...

echo 'Building web frontend...' 
cd web
npm install
npm run build
cd ..

echo 'Building Linux amd64 binary...' 
mkdir -p bin /tmp/uart_sms_forwarder-release
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags='-s -w' -o bin/uart_sms_forwarder-linux-amd64 cmd/serv/main.go
cp bin/uart_sms_forwarder-linux-amd64 /tmp/uart_sms_forwarder-release/uart_sms_forwarder
tar -czf "$ASSET" -C /tmp/uart_sms_forwarder-release uart_sms_forwarder

echo 'Committing and publishing GitHub Release...' 
git add README.md config.example.yaml internal/models/property.go internal/service/property_service.go internal/handler/property_handler.go internal/handler/property_handler_test.go internal/service/serial_handlers_sms.go internal/service/notifier.go internal/service/serial_service.go internal/service/serial_manager.go internal/service/serial_discovery.go internal/service/serial_discovery_test.go internal/service/notification_filter_test.go web/src/api/property.ts web/src/pages/NotificationChannels.tsx web/dist web/assets.go
git commit -m 'Fix multi-SIM notification routing isolation' || true
git push origin HEAD:main
gh release delete "$TAG" --repo "$REPO" -y --cleanup-tag 2>/dev/null || true
gh release create "$TAG" "$ASSET" --repo "$REPO" --target main --title 'Multi-SIM notification routing safe test' --notes 'Fixes per-channel IDs, exact channel testing, per-SIM notification routing, hotplug discovery stability, and removes private test values.'
echo
echo 'Release ready:'
echo "https://github.com/$REPO/releases/tag/$TAG"
