package config

import "fmt"

type AppConfig struct {
	JWT    JWTConfig         `json:"JWT" mapstructure:"JWT"`
	Users  map[string]string `json:"Users" mapstructure:"Users"`   // 用户名 -> bcrypt加密的密码
	Serial SerialConfig      `json:"Serial" mapstructure:"Serial"` // 串口配置
	OIDC   *OIDCConfig       `json:"OIDC" mapstructure:"OIDC"`     // OIDC配置（可选）
}

// JWTConfig JWT配置
type JWTConfig struct {
	Secret       string `json:"Secret" mapstructure:"Secret"`
	ExpiresHours int    `json:"ExpiresHours" mapstructure:"ExpiresHours"`
}

// SerialConfig 串口配置
type SerialConfig struct {
	Port    string               `json:"Port" mapstructure:"Port"`       // 兼容旧配置：串口路径，为空则自动检测
	Devices []SerialDeviceConfig `json:"Devices" mapstructure:"Devices"` // 多模块配置
}

// SerialDeviceConfig 单个串口模块配置
type SerialDeviceConfig struct {
	ID            string `json:"ID" mapstructure:"ID"`                       // 设备唯一 ID，例如 sim1
	Name          string `json:"Name" mapstructure:"Name"`                   // 显示名称
	Port          string `json:"Port" mapstructure:"Port"`                   // 固定串口路径，建议使用 /dev/serial/by-path 或 udev 别名
	ExpectedICCID string `json:"ExpectedICCID" mapstructure:"ExpectedICCID"` // 可选：绑定 SIM 卡 ICCID，发现错卡时提示
}

// NormalizedDevices 返回兼容旧配置后的设备列表。
func (c SerialConfig) NormalizedDevices() []SerialDeviceConfig {
	if len(c.Devices) > 0 {
		devices := make([]SerialDeviceConfig, 0, len(c.Devices))
		for i, device := range c.Devices {
			if device.ID == "" {
				device.ID = defaultSerialDeviceID(i)
			}
			if device.Name == "" {
				device.Name = device.ID
			}
			devices = append(devices, device)
		}
		return devices
	}

	return []SerialDeviceConfig{{
		ID:   "default",
		Name: "默认模块",
		Port: c.Port,
	}}
}

func defaultSerialDeviceID(index int) string {
	return fmt.Sprintf("sim%d", index+1)
}

// OIDCConfig OIDC认证配置
type OIDCConfig struct {
	Enabled      bool   `json:"Enabled" mapstructure:"Enabled"`           // 是否启用OIDC
	Issuer       string `json:"Issuer" mapstructure:"Issuer"`             // OIDC Provider的Issuer URL
	ClientID     string `json:"ClientID" mapstructure:"ClientID"`         // Client ID
	ClientSecret string `json:"ClientSecret" mapstructure:"ClientSecret"` // Client Secret
	RedirectURL  string `json:"RedirectURL" mapstructure:"RedirectURL"`   // 回调URL
}
