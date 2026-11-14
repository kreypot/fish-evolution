extends Control
## The room screen for Wi-Fi / hotspot battles. No internet is needed: everybody joins the same Wi-Fi network
## or the same phone hotspot. One phone HOSTS a room and shows a 4-digit code, the others type the code to join.
## (The host phone announces the code over the local network; if that does not work, type the host's
## address instead, for example 192.168.43.1 - it is shown on the host's screen.)

const UITheme = preload("res://scripts/ui_theme.gd")
const MenuBg = preload("res://scripts/menu_bg.gd")

const GAME_PORT := 47780
const DISCOVERY_PORT := 47781
const MAX_PLAYERS := 8
const ARENA_SCENE := "res://scenes/arena.tscn"

const P_MENU := 0
const P_HOST := 1
const P_ENTER := 2
const P_WAIT := 3

var _panels: Array = []
var _humans: Dictionary = {}   # network id -> {"name", "look"}
var _bots: Array = []          # roster entries of the bots
var _roster: Array = []        # everybody in the room, in order
var _code := ""
var _entry := ""
var _hosting := false
var _joined := false
var _searching := false
var _search_t := 0.0
var _connecting := false
var _connect_t := 0.0
var _bcast_t := 0.0
var _bcast := PacketPeerUDP.new()
var _listen := PacketPeerUDP.new()

var _menu_status: Label
var _host_code: Label
var _host_ip: Label
var _host_list: Label
var _start_btn: Button
var _add_bot_btn: Button
var _rem_bot_btn: Button
var _enter_display: Label
var _enter_status: Label
var _wait_list: Label


func _ready() -> void:
	theme = UITheme.make()
	var bg := MenuBg.new()
	add_child(bg)
	multiplayer.multiplayer_peer = null
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	multiplayer.peer_disconnected.connect(_on_peer_gone)
	_build_menu()
	_build_host()
	_build_enter()
	_build_wait()
	_show(P_MENU)


func _exit_tree() -> void:
	_bcast.close()
	_listen.close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _centered(content: Control) -> Control:
	if content is PanelContainer:
		UITheme.make_scrollable(content)   # scrolls when it does not fit on the screen
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(content)
	return center


func _show(which: int) -> void:
	for i in _panels.size():
		_panels[i].visible = (i == which)


func _small(text: String) -> Label:
	var l := UITheme.label(text, 24, Color(1, 1, 1, 0.85))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	return l


# --- The four panels ---------------------------------------------------------------------------------------------

func _build_menu() -> void:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	vb.add_child(UITheme.label("Wi-Fi Battle", 56, Color("#ffd23a")))
	vb.add_child(_small("Fight your friends with your own fish! Everybody joins the same Wi-Fi or the same phone hotspot. No internet needed."))
	vb.add_child(UITheme.button("Host a Room", _start_host, 460.0, 74.0))
	vb.add_child(UITheme.button("Join a Room", _open_enter, 460.0, 74.0))
	vb.add_child(UITheme.button("Practice vs Bots", _start_practice, 460.0, 74.0))
	vb.add_child(UITheme.button("Back", _on_back, 460.0, 74.0))
	_menu_status = UITheme.label("", 24, Color("#ff9a9a"))
	vb.add_child(_menu_status)
	var c := _centered(panel)
	_panels.append(c)


func _build_host() -> void:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	vb.add_child(UITheme.label("Your Room", 44, Color("#ffd23a")))
	_host_code = UITheme.label("", 64, Color.WHITE)
	vb.add_child(_host_code)
	_host_ip = _small("")
	vb.add_child(_host_ip)
	_host_list = UITheme.label("", 26)
	vb.add_child(_host_list)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_add_bot_btn = UITheme.button("Add Bot", _add_bot, 280.0, 68.0)
	_rem_bot_btn = UITheme.button("Remove Bot", _remove_bot, 280.0, 68.0)
	row.add_child(_add_bot_btn)
	row.add_child(_rem_bot_btn)
	vb.add_child(row)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 16)
	_start_btn = UITheme.button("Start Battle", _start_battle, 280.0, 74.0)
	row2.add_child(_start_btn)
	row2.add_child(UITheme.button("Leave", _leave_room, 280.0, 74.0))
	vb.add_child(row2)
	var c := _centered(panel)
	_panels.append(c)


func _build_enter() -> void:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	vb.add_child(UITheme.label("Join a Room", 44, Color("#ffd23a")))
	vb.add_child(_small("Type the 4-digit room code from the host's screen. If the room is not found, type the host's address instead (for example 192.168.43.1)."))
	_enter_display = UITheme.label("- - - -", 56, Color.WHITE)
	vb.add_child(_enter_display)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", ".", "<"]:
		grid.add_child(UITheme.button(k, _on_key.bind(k), 130.0, 66.0))
	vb.add_child(grid)
	_enter_status = UITheme.label("", 24, Color("#ff9a9a"))
	vb.add_child(_enter_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(UITheme.button("Join", _on_join, 280.0, 70.0))
	row.add_child(UITheme.button("Back", _on_enter_back, 280.0, 70.0))
	vb.add_child(row)
	var c := _centered(panel)
	_panels.append(c)


func _build_wait() -> void:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	vb.add_child(UITheme.label("Connected!", 48, Color("#7dff9a")))
	vb.add_child(_small("Waiting for the host to start the battle..."))
	_wait_list = UITheme.label("", 26)
	vb.add_child(_wait_list)
	vb.add_child(UITheme.button("Leave", _leave_room, 360.0, 70.0))
	var c := _centered(panel)
	_panels.append(c)


# --- Host a room ---------------------------------------------------------------------------------------------------

func _start_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_server(GAME_PORT, MAX_PLAYERS - 1)
	if err != OK:
		_menu_status.text = "Could not open the room (error %d). Close other games and try again." % err
		return
	multiplayer.multiplayer_peer = peer
	_menu_status.text = ""
	_code = "%04d" % randi_range(0, 9999)
	_humans = {1: {"name": GameState.my_species_name(), "look": GameState.get_look()}}
	_bots.clear()
	_hosting = true
	_bcast_t = 0.0
	var ips: Array = _local_ips()
	var ip_text := "Address: " + (str(ips[0]) if not ips.is_empty() else "not found - is Wi-Fi or the hotspot on?")
	_host_code.text = "Room code: " + _code
	_host_ip.text = "Everybody must be on this Wi-Fi or hotspot.   " + ip_text
	_rebuild_roster()
	_show(P_HOST)


func _local_ips() -> Array:
	var first: Array = []
	var other: Array = []
	for a in IP.get_local_addresses():
		var s: String = str(a)
		if s.count(".") != 3:
			continue
		if s.begins_with("192.168."):
			first.append(s)
		elif s.begins_with("10.") or s.begins_with("172."):
			other.append(s)
	return first + other


func _broadcast() -> void:
	var msg: PackedByteArray = ("FISHARENA|%s|%d" % [_code, GAME_PORT]).to_utf8_buffer()
	_bcast.set_broadcast_enabled(true)
	var dests: Array = ["255.255.255.255"]
	for ip in _local_ips():   # also the broadcast address of every network this phone is on (hotspot!)
		var p: PackedStringArray = str(ip).rsplit(".", true, 1)
		dests.append(p[0] + ".255")
	for d in dests:
		_bcast.set_dest_address(str(d), DISCOVERY_PORT)
		_bcast.put_packet(msg)


func _rebuild_roster() -> void:
	_roster.clear()
	var used: Dictionary = {}
	var ids: Array = _humans.keys()
	ids.sort()
	for id in ids:
		var h: Dictionary = _humans[id]
		_roster.append(_entry_for(int(id), str(h["name"]), h["look"], false, used))
	for b in _bots:
		_roster.append(_entry_for(int(b["id"]), str(b["name"]), b["look"], true, used))
	_refresh_host()
	if _hosting and not multiplayer.get_peers().is_empty():
		_rpc_roster.rpc(_roster, false, 0)


func _entry_for(id: int, base_name: String, look: Dictionary, bot: bool, used: Dictionary) -> Dictionary:
	var n: String = base_name
	var k := 2
	while used.has(n):
		n = "%s %d" % [base_name, k]
		k += 1
	used[n] = true
	return {"id": id, "name": n, "look": look, "bot": bot}


func _list_text(you_id: int) -> String:
	var t := ""
	for i in _roster.size():
		var r: Dictionary = _roster[i]
		t += "%d.  %s%s%s\n" % [i + 1, str(r["name"]), "  (you)" if int(r["id"]) == you_id else "", "  [bot]" if bool(r["bot"]) else ""]
	return t.strip_edges()


func _refresh_host() -> void:
	_host_list.text = _list_text(1)
	_start_btn.disabled = _roster.size() < 2
	_add_bot_btn.disabled = _roster.size() >= MAX_PLAYERS
	_rem_bot_btn.disabled = _bots.is_empty()


func _add_bot() -> void:
	if _roster.size() >= MAX_PLAYERS:
		return
	_bots.append(GameState.make_bot_entry(-1 - _bots.size()))
	_rebuild_roster()


func _remove_bot() -> void:
	if not _bots.is_empty():
		_bots.pop_back()
		_rebuild_roster()


func _start_battle() -> void:
	if _roster.size() < 2:
		return
	var map_seed: int = randi()
	GameState.mp_roster = _roster.duplicate(true)
	GameState.mp_seed = map_seed
	_hosting = false   # stop announcing the room
	if not multiplayer.get_peers().is_empty():
		_rpc_roster.rpc(_roster, true, map_seed)
	GameState.go_to(ARENA_SCENE)


func _start_practice() -> void:
	multiplayer.multiplayer_peer = null
	GameState.mp_roster = GameState.practice_roster()
	GameState.mp_seed = randi()
	GameState.go_to(ARENA_SCENE)


# --- Join a room ---------------------------------------------------------------------------------------------------

func _open_enter() -> void:
	_entry = ""
	_enter_display.text = "- - - -"
	_enter_status.text = ""
	_show(P_ENTER)


func _on_key(k: String) -> void:
	if k == "<":
		_entry = _entry.left(maxi(_entry.length() - 1, 0))
	elif _entry.length() < 15:
		_entry += k
	_enter_display.text = _entry if _entry != "" else "- - - -"


func _on_join() -> void:
	_enter_status.text = ""
	if _entry.count(".") == 3:
		_connect_to(_entry)
	elif _entry.length() == 4 and _entry.is_valid_int():
		_begin_search()
	else:
		_enter_status.text = "Type the 4-digit room code, or the host's address."


func _begin_search() -> void:
	_listen.close()
	var err: int = _listen.bind(DISCOVERY_PORT)
	if err != OK:
		_enter_status.text = "Could not listen on the network (error %d). Try the host's address." % err
		return
	_searching = true
	_search_t = 12.0
	_enter_status.text = "Looking for room %s ..." % _entry


func _connect_to(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_client(ip, GAME_PORT)
	if err != OK:
		_enter_status.text = "Could not connect (error %d)." % err
		return
	multiplayer.multiplayer_peer = peer
	_connecting = true
	_connect_t = 8.0
	_enter_status.text = "Connecting to %s ..." % ip


func _on_connected() -> void:
	_connecting = false
	_joined = true
	_rpc_register.rpc_id(1, GameState.my_species_name(), GameState.get_look())
	_wait_list.text = ""
	_show(P_WAIT)


func _on_connection_failed() -> void:
	_fail("Could not connect to the host. Same Wi-Fi or hotspot? Right code?")


func _fail(text: String) -> void:
	_connecting = false
	_searching = false
	_listen.close()
	multiplayer.multiplayer_peer = null
	_enter_status.text = text


func _on_server_gone() -> void:
	if _joined:
		_joined = false
		multiplayer.multiplayer_peer = null
		_menu_status.text = "The host closed the room."
		_show(P_MENU)


func _on_peer_gone(id: int) -> void:
	if _hosting:
		_humans.erase(id)
		_rebuild_roster()


# --- Messages between the phones ----------------------------------------------------------------------------------

## A phone that joined tells the host its name and how its fish looks.
@rpc("any_peer", "reliable")
func _rpc_register(player_name: String, look: Dictionary) -> void:
	if not multiplayer.is_server() or not _hosting:
		return
	var id: int = multiplayer.get_remote_sender_id()
	if _roster.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	_humans[id] = {"name": player_name, "look": look}
	_rebuild_roster()


## The host sends the list of players to everybody (start = true means: the battle begins now).
@rpc("authority", "reliable")
func _rpc_roster(roster: Array, start: bool, map_seed: int) -> void:
	GameState.mp_roster = roster
	GameState.mp_seed = map_seed
	_roster = roster
	_wait_list.text = _list_text(multiplayer.get_unique_id())
	if start:
		GameState.go_to(ARENA_SCENE)


# --- Leaving ------------------------------------------------------------------------------------------------------

func _leave_room() -> void:
	_hosting = false
	_joined = false
	_searching = false
	_connecting = false
	_bcast.close()
	_listen.close()
	multiplayer.multiplayer_peer = null
	_humans.clear()
	_bots.clear()
	_roster.clear()
	_menu_status.text = ""
	_show(P_MENU)


func _on_enter_back() -> void:
	_searching = false
	_connecting = false
	_listen.close()
	multiplayer.multiplayer_peer = null
	_show(P_MENU)


func _on_back() -> void:
	if _panels.size() > 0 and not _panels[P_MENU].visible:
		if _panels[P_ENTER].visible:
			_on_enter_back()
		else:
			_leave_room()
	else:
		GameState.go_to("res://scenes/main_menu.tscn")


func _process(delta: float) -> void:
	if _hosting:
		_bcast_t -= delta
		if _bcast_t <= 0.0:
			_bcast_t = 1.0
			_broadcast()
	if _searching:
		_search_t -= delta
		while _listen.get_available_packet_count() > 0:
			var data: PackedByteArray = _listen.get_packet()
			var ip: String = _listen.get_packet_ip()
			var parts: PackedStringArray = data.get_string_from_utf8().split("|")
			if parts.size() >= 3 and parts[0] == "FISHARENA" and parts[1] == _entry:
				_searching = false
				_listen.close()
				_connect_to(ip)
				break
		if _searching and _search_t <= 0.0:
			_searching = false
			_listen.close()
			_enter_status.text = "Room not found. Same Wi-Fi or hotspot? Or type the host's address."
	if _connecting:
		_connect_t -= delta
		if _connect_t <= 0.0:
			_fail("Could not connect. Check the address and the Wi-Fi.")
