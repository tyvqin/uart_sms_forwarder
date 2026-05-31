package service

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
