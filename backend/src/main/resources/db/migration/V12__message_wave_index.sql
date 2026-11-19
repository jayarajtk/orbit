CREATE INDEX message_wave_idx ON message (conversation_id, sender_id, created_at) WHERE kind = 'WAVE';
