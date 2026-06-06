"""
vivado/run_via_tcp.py — 通过 TCP 向 Vivado Tcl 服务器发送命令并捕获输出

使用 length-prefix framing 协议：
  -> [4 字节 big-endian 长度][UTF-8 payload]
  <- [4 字节 big-endian 长度][UTF-8 JSON: {"rc": int, "output": string}]
"""

import socket
import struct
import json
import sys
import os
import time

TCP_HOST = "127.0.0.1"
TCP_PORT = 9999
BUFFER_SIZE = 65536
TIMEOUT = 600  # 10 分钟


def send_tcl(tcl_command: str, timeout: float = TIMEOUT) -> str:
    """发送 Tcl 命令到 Vivado TCP server，返回输出文本"""
    payload = tcl_command.encode("utf-8")
    header = struct.pack(">I", len(payload))

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        sock.connect((TCP_HOST, TCP_PORT))
        sock.sendall(header + payload)

        # 读 4 字节响应头
        resp_hdr = _recv_exact(sock, 4)
        if resp_hdr is None:
            return "ERROR: No response header received (timeout)"
        resp_len = struct.unpack(">I", resp_hdr)[0]
        if resp_len <= 0 or resp_len > 10 * 1024 * 1024:
            return f"ERROR: Invalid response length {resp_len}"

        # 读响应体
        resp_body = _recv_exact(sock, resp_len)
        if resp_body is None:
            return f"ERROR: Only read {0} of {resp_len} response bytes"

        obj = json.loads(resp_body.decode("utf-8"))
        rc = obj.get("rc", -1)
        output = obj.get("output", "")
        if rc != 0:
            return f"ERROR(rc={rc}): {output}"
        return output
    except Exception as e:
        return f"ERROR: {e}"
    finally:
        sock.close()


def _recv_exact(sock: socket.socket, n: int) -> bytes | None:
    """精确接收 n 字节，失败返回 None"""
    buf = bytearray()
    while len(buf) < n:
        try:
            chunk = sock.recv(n - len(buf))
        except (OSError, socket.timeout):
            return None
        if not chunk:
            return None
        buf.extend(chunk)
    return bytes(buf)


def source_script(script_path: str) -> str:
    """加载并运行 Tcl 脚本文件"""
    abs_path = os.path.abspath(script_path).replace("\\", "/")
    # 读取脚本内容，逐块发送
    with open(script_path, "r", encoding="utf-8") as f:
        script = f.read()

    # source 命令让 Vivado 直接加载文件
    return send_tcl(f"source {{{abs_path}}}")


def send_tcl_multiline(tcl_script_path: str) -> str:
    """逐行发送多行 Tcl 脚本到 Vivado TCP server"""
    with open(tcl_script_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    output_lines = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        result = send_tcl(stripped, timeout=30)
        output_lines.append(result)
        # 如果结果包含错误信息，打印
        if result.startswith("ERROR"):
            print(f"  Tcl ERROR at line: {stripped}")
            print(f"  {result}")
    return "\n".join(output_lines)


def read_vivado_file(file_path: str) -> str:
    """通过 Vivado 的 cat 命令读取文件内容"""
    abs_path = os.path.abspath(file_path).replace("\\", "/")
    return send_tcl(f"set ch [open {{{abs_path}}} r]; set content [read \\$ch]; close \\$ch; puts $content")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "source":
        tcl_path = os.path.abspath(sys.argv[2]).replace("\\", "/")
        print(f"Sourcing Tcl script: {tcl_path}")
        result = source_script(tcl_path)
        print(result)
    elif len(sys.argv) > 1:
        result = send_tcl(" ".join(sys.argv[1:]))
        print(result)
    else:
        print("Usage:")
        print("  python run_via_tcp.py source <tcl_script>")
        print("  python run_via_tcp.py <tcl_command>")
        print("\nExample:")
        print('  python run_via_tcp.py "puts hello; version"')
