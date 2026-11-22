"""Fcitx5 Kimpanel D-Bus <-> JSON Lines stdio bridge.

stdout: one JSON state object per line ({"v": 1, ...}) whenever state changes.
stdin:  "select <index>" | "page_up" | "page_down".
"""

import ctypes
import json
import os
import select
import sys

# [Libsystemd]
lib = ctypes.CDLL(os.environ.get("KIMPANEL_LIBSYSTEMD", "libsystemd.so.0"))

MSG_METHOD_CALL = 1
MSG_SIGNAL = 4
NAME_REPLACE_EXISTING = 1 << 2
PANEL_PATH = b"/org/kde/impanel"
DEBUG = os.environ.get("KIMPANEL_DEBUG") == "1"

bus_p = ctypes.c_void_p
msg_p = ctypes.c_void_p


def _sig(name, restype, *argtypes):
    fn = getattr(lib, name)
    fn.restype = restype
    fn.argtypes = list(argtypes)
    return fn


sd_bus_open_user = _sig("sd_bus_open_user", ctypes.c_int, ctypes.POINTER(bus_p))
sd_bus_request_name = _sig("sd_bus_request_name", ctypes.c_int, bus_p, ctypes.c_char_p, ctypes.c_uint64)
sd_bus_add_match = _sig("sd_bus_add_match", ctypes.c_int, bus_p, ctypes.c_void_p, ctypes.c_char_p, ctypes.c_void_p, ctypes.c_void_p)
sd_bus_get_fd = _sig("sd_bus_get_fd", ctypes.c_int, bus_p)
sd_bus_process = _sig("sd_bus_process", ctypes.c_int, bus_p, ctypes.POINTER(msg_p))
sd_bus_flush = _sig("sd_bus_flush", ctypes.c_int, bus_p)
sd_bus_message_unref = _sig("sd_bus_message_unref", msg_p, msg_p)
sd_bus_message_get_type = _sig("sd_bus_message_get_type", ctypes.c_int, msg_p, ctypes.POINTER(ctypes.c_uint8))
sd_bus_message_get_path = _sig("sd_bus_message_get_path", ctypes.c_char_p, msg_p)
sd_bus_message_get_interface = _sig("sd_bus_message_get_interface", ctypes.c_char_p, msg_p)
sd_bus_message_get_member = _sig("sd_bus_message_get_member", ctypes.c_char_p, msg_p)
sd_bus_message_read_basic = _sig("sd_bus_message_read_basic", ctypes.c_int, msg_p, ctypes.c_char, ctypes.c_void_p)
sd_bus_message_enter_container = _sig("sd_bus_message_enter_container", ctypes.c_int, msg_p, ctypes.c_char, ctypes.c_char_p)
sd_bus_message_exit_container = _sig("sd_bus_message_exit_container", ctypes.c_int, msg_p)
# Variadic: argtypes left unset on purpose.
sd_bus_emit_signal = lib.sd_bus_emit_signal
sd_bus_emit_signal.restype = ctypes.c_int
sd_bus_reply_method_return = lib.sd_bus_reply_method_return
sd_bus_reply_method_return.restype = ctypes.c_int

INTROSPECT_XML = b"""<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node>
  <interface name="org.freedesktop.DBus.Introspectable">
    <method name="Introspect"><arg name="xml" type="s" direction="out"/></method>
  </interface>
  <interface name="org.kde.impanel">
    <signal name="PanelCreated"/>
    <signal name="SelectCandidate"><arg name="index" type="i"/></signal>
    <signal name="LookupTablePageUp"/>
    <signal name="LookupTablePageDown"/>
  </interface>
  <interface name="org.kde.impanel2">
    <signal name="PanelCreated2"/>
    <method name="SetLookupTable">
      <arg type="as" direction="in"/><arg type="as" direction="in"/><arg type="as" direction="in"/>
      <arg type="b" direction="in"/><arg type="b" direction="in"/>
      <arg type="i" direction="in"/><arg type="i" direction="in"/>
    </method>
    <method name="SetSpotRect">
      <arg type="i" direction="in"/><arg type="i" direction="in"/><arg type="i" direction="in"/><arg type="i" direction="in"/>
    </method>
    <method name="SetRelativeSpotRect">
      <arg type="i" direction="in"/><arg type="i" direction="in"/><arg type="i" direction="in"/><arg type="i" direction="in"/>
    </method>
    <method name="SetRelativeSpotRectV2">
      <arg type="i" direction="in"/><arg type="i" direction="in"/><arg type="i" direction="in"/><arg type="i" direction="in"/>
      <arg type="d" direction="in"/>
    </method>
  </interface>
</node>"""


# [Readers]
def _read(msg, code, ctype):
    val = ctype()
    sd_bus_message_read_basic(msg, code, ctypes.byref(val))
    return val.value


def read_str(msg):
    raw = _read(msg, b"s", ctypes.c_char_p)
    return raw.decode("utf-8", "replace") if raw else ""


def read_int(msg):
    return int(_read(msg, b"i", ctypes.c_int32))


def read_bool(msg):
    return bool(_read(msg, b"b", ctypes.c_int32))


def read_double(msg):
    return float(_read(msg, b"d", ctypes.c_double))


def read_str_array(msg):
    items = []
    if sd_bus_message_enter_container(msg, b"a", b"s") > 0:
        while True:
            raw = ctypes.c_char_p()
            if sd_bus_message_read_basic(msg, b"s", ctypes.byref(raw)) <= 0:
                break
            items.append(raw.value.decode("utf-8", "replace") if raw.value else "")
        sd_bus_message_exit_container(msg)
    return items


def debug(*args):
    if DEBUG:
        print("[kimpanel]", *args, file=sys.stderr, flush=True)


# [State]
class Panel:
    def __init__(self):
        self.enabled = True
        self.show_preedit = self.show_aux = self.show_lookup = False
        self.preedit = self.aux = ""
        self.caret = 0
        self.candidates = []
        self.cursor = -1
        self.has_prev = self.has_next = False
        self.layout = 0
        self.spot = {"relative": False, "x": 0, "y": 0, "w": 0, "h": 0, "scale": 1.0}
        self._last = ""

    def snapshot(self):
        cands = self.candidates if self.show_lookup else []
        preedit = self.preedit if self.show_preedit else ""
        aux = self.aux if self.show_aux else ""
        return {
            "v": 1,
            "visible": self.enabled and bool(preedit or aux or cands),
            "preedit": preedit,
            "caret": self.caret,
            "aux": aux,
            "candidates": cands,
            "cursor": self.cursor,
            "hasPrev": self.has_prev,
            "hasNext": self.has_next,
            "layout": self.layout,
            "spot": self.spot,
        }

    def publish(self):
        payload = json.dumps(self.snapshot(), ensure_ascii=False, separators=(",", ":"))
        if payload != self._last:
            self._last = payload
            sys.stdout.write(payload + "\n")
            sys.stdout.flush()

    def on_signal(self, member, msg):
        if member == "Enable":
            self.enabled = read_bool(msg)
        elif member == "ShowPreedit":
            self.show_preedit = read_bool(msg)
        elif member == "ShowAux":
            self.show_aux = read_bool(msg)
        elif member == "ShowLookupTable":
            self.show_lookup = read_bool(msg)
        elif member == "UpdatePreeditText":
            self.preedit = read_str(msg)
        elif member == "UpdatePreeditCaret":
            self.caret = read_int(msg)
        elif member == "UpdateAux":
            self.aux = read_str(msg)
        elif member == "UpdateLookupTableCursor":
            self.cursor = read_int(msg)
        elif member == "UpdateSpotLocation":
            x, y = read_int(msg), read_int(msg)
            self.spot = {"relative": False, "x": x, "y": y, "w": 0, "h": 0, "scale": 1.0}

    def on_call(self, member, msg):
        if member == "SetLookupTable":
            labels, texts, _attrs = read_str_array(msg), read_str_array(msg), read_str_array(msg)
            self.has_prev, self.has_next = read_bool(msg), read_bool(msg)
            self.cursor, self.layout = read_int(msg), read_int(msg)
            self.candidates = [
                {"label": (labels[i].strip() if i < len(labels) else str(i + 1)), "text": text}
                for i, text in enumerate(texts)
            ]
        elif member in ("SetSpotRect", "SetRelativeSpotRect", "SetRelativeSpotRectV2"):
            x, y, w, h = read_int(msg), read_int(msg), read_int(msg), read_int(msg)
            scale = read_double(msg) if member == "SetRelativeSpotRectV2" else 1.0
            self.spot = {
                "relative": member != "SetSpotRect",
                "x": x, "y": y, "w": w, "h": h,
                "scale": scale if scale > 0 else 1.0,
            }
            debug(member, self.spot)


# [Main]
def main():
    bus = bus_p()
    r = sd_bus_open_user(ctypes.byref(bus))
    if r < 0:
        print(f"sd_bus_open_user failed: {r}", file=sys.stderr)
        return 1
    r = sd_bus_request_name(bus, b"org.kde.impanel", NAME_REPLACE_EXISTING)
    if r < 0:
        print(f"sd_bus_request_name failed: {r}", file=sys.stderr)
        return 1
    sd_bus_add_match(bus, None, b"type='signal',interface='org.kde.kimpanel.inputmethod'", None, None)

    def emit(iface, member, sig=b"", *args):
        sd_bus_emit_signal(bus, PANEL_PATH, iface, member, sig, *args)
        sd_bus_flush(bus)

    emit(b"org.kde.impanel", b"PanelCreated")
    emit(b"org.kde.impanel2", b"PanelCreated2")

    panel = Panel()

    def dispatch(msg):
        mtype = ctypes.c_uint8()
        sd_bus_message_get_type(msg, ctypes.byref(mtype))
        iface = (sd_bus_message_get_interface(msg) or b"").decode()
        member = (sd_bus_message_get_member(msg) or b"").decode()
        if mtype.value == MSG_SIGNAL and iface == "org.kde.kimpanel.inputmethod":
            panel.on_signal(member, msg)
        elif mtype.value == MSG_METHOD_CALL and sd_bus_message_get_path(msg) == PANEL_PATH:
            if member == "Introspect":
                sd_bus_reply_method_return(msg, b"s", ctypes.c_char_p(INTROSPECT_XML))
                return
            if iface == "org.kde.impanel2":
                panel.on_call(member, msg)
            sd_bus_reply_method_return(msg, b"")

    def handle_command(line):
        cmd = line.split()
        if len(cmd) == 2 and cmd[0] == "select" and cmd[1].isdigit():
            emit(b"org.kde.impanel", b"SelectCandidate", b"i", ctypes.c_int32(int(cmd[1])))
        elif cmd == ["page_up"]:
            emit(b"org.kde.impanel", b"LookupTablePageUp")
        elif cmd == ["page_down"]:
            emit(b"org.kde.impanel", b"LookupTablePageDown")

    stdin_fd = sys.stdin.fileno()
    poller = select.poll()
    poller.register(sd_bus_get_fd(bus), select.POLLIN)
    poller.register(stdin_fd, select.POLLIN)
    pending = b""

    while True:
        while True:
            msg = msg_p()
            r = sd_bus_process(bus, ctypes.byref(msg))
            if msg.value:
                dispatch(msg)
                sd_bus_message_unref(msg)
            if r <= 0:
                break
        if r < 0:
            print(f"sd_bus_process failed: {r}", file=sys.stderr)
            return 1
        sd_bus_flush(bus)
        panel.publish()

        for fd, _ev in poller.poll():
            if fd != stdin_fd:
                continue
            chunk = os.read(stdin_fd, 4096)
            if not chunk:
                return 0
            pending += chunk
            *lines, pending = pending.split(b"\n")
            for line in lines:
                handle_command(line.decode("utf-8", "replace"))


if __name__ == "__main__":
    sys.exit(main())
