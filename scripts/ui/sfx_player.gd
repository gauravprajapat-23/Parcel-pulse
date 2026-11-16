extends Node
class_name SfxPlayer

# Short original sine-wave cues; no external audio assets or network.
# Optional by default, moderate volume, controlled with a visible SFX toggle.
const SAMPLE_RATE: int = 22050
const MASTER_AMPLITUDE: float = 0.19

var enabled: bool = true
var _players: Dictionary = {}


func _ready() -> void:
	for event_name in ["tap", "success", "mistake", "win", "pause"]:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx_" + event_name
		player.volume_db = -13.0
		player.stream = _generate_tone(event_name)
		add_child(player)
		_players[event_name] = player


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		for event_name in _players:
			var player: AudioStreamPlayer = _players[event_name]
			player.stop()


func play_event(event_name: String) -> void:
	if not enabled or not _players.has(event_name):
		return
	var player: AudioStreamPlayer = _players[event_name]
	if is_instance_valid(player):
		player.play()


func _generate_tone(event_name: String) -> AudioStreamWAV:
	var duration: float = 0.14
	match event_name:
		"tap": duration = 0.10
		"success": duration = 0.18
		"mistake": duration = 0.23
		"win": duration = 0.34
		"pause": duration = 0.08
	var samples: int = int(ceil(duration * float(SAMPLE_RATE)))
	var pcm := PackedByteArray()
	pcm.resize(samples * 2)
	var wave_phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var frequency: float = 440.0
		match event_name:
			"tap": frequency = 540.0 + 190.0 * t / duration
			"success": frequency = 690.0 if t < duration * 0.45 else 940.0
			"mistake": frequency = 390.0 - 200.0 * t / duration
			"win":
				if t < duration / 3.0:
					frequency = 523.25
				elif t < duration * 2.0 / 3.0:
					frequency = 659.25
				else:
					frequency = 783.99
			"pause": frequency = 430.0
		wave_phase += TAU * frequency / float(SAMPLE_RATE)
		var envelope: float = minf(1.0, t / 0.012) * pow(maxf(0.0, 1.0 - t / duration), 1.7)
		var sample: int = roundi(sin(wave_phase) * MASTER_AMPLITUDE * envelope * 32767.0)
		pcm.encode_s16(i * 2, clampi(sample, -32768, 32767))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = SAMPLE_RATE
	result.stereo = false
	result.loop_mode = AudioStreamWAV.LOOP_DISABLED
	result.data = pcm
	return result
