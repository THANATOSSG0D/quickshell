#!/usr/bin/env python3
"""
qs-dmenu-server.py — bridge entre unix socket e QML via stdout/fifo_out.

Protocolo:
  Entrada (cliente → servidor → QML stdout):
    cliente conecta no socket, envia: <JSON>\n
    servidor escreve no stdout: <JSON>\n   ← QML lê via SplitParser

  Saída (QML → fifo_out → servidor → cliente):
    QML escreve em FIFO_OUT: <JSON>\n
    servidor lê FIFO_OUT, encaminha para o cliente, fecha conexão

FIFOs criados pelo servidor em $XDG_RUNTIME_DIR/:
  qs-dmenu.sock    — unix socket para clientes
  qs-dmenu-out     — fifo que o QML escreve a resposta
"""

import sys, os, socket, json, threading

RD = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
SOCK_PATH = os.path.join(RD, "qs-dmenu.sock")
FIFO_OUT  = os.path.join(RD, "qs-dmenu-out")

def setup():
    # Socket
    try: os.unlink(SOCK_PATH)
    except FileNotFoundError: pass

    # FIFO de saída
    try: os.unlink(FIFO_OUT)
    except FileNotFoundError: pass
    os.mkfifo(FIFO_OUT, 0o600)

    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(SOCK_PATH)
    os.chmod(SOCK_PATH, 0o600)
    srv.listen(1)
    return srv

def main():
    srv = setup()

    # Sinaliza QML que está pronto (inclui paths)
    info = json.dumps({"ready": True, "sock": SOCK_PATH, "fifo_out": FIFO_OUT})
    print(info, flush=True)

    # Mutex: só um request ativo por vez
    lock = threading.Lock()

    while True:
        try:
            conn, _ = srv.accept()
        except OSError:
            break

        with lock:
            _handle(conn)

def _handle(conn):
    with conn:
        # Lê request do cliente
        data = b""
        while b"\n" not in data:
            chunk = conn.recv(65536)
            if not chunk:
                break
            data += chunk

        if not data:
            return

        line = data.split(b"\n")[0].decode().strip()
        try:
            json.loads(line)  # valida
        except json.JSONDecodeError:
            conn.sendall(b'{"selected":null}\n')
            return

        # Encaminha para QML via stdout
        sys.stdout.write(line + "\n")
        sys.stdout.flush()

        # Aguarda resposta do QML via FIFO_OUT (bloqueante, abre em modo leitura)
        # O QML escreve uma linha JSON e fecha — o open() desbloqueará aqui
        try:
            with open(FIFO_OUT, "r") as f:
                response = f.readline().strip()
        except OSError:
            response = '{"selected":null}'

        if not response:
            response = '{"selected":null}'

        conn.sendall((response + "\n").encode())

if __name__ == "__main__":
    main()
