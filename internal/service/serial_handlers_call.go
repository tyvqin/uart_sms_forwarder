package service

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
