package models

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
