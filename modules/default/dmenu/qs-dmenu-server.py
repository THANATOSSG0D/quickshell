#!/usr/bin/env python3
"""
qs-dmenu-server.py — bridge entre unix socket e QML via stdout / FIFOs exclusivos.

Mudanças em relação à versão anterior:
  • FIFOs por request: cada conexão recebe um FIFO exclusivo (qs-dmenu-out-<id>).
    O path é injetado no JSON enviado ao QML como campo "_fifo".
    Isso elimina contaminação entre requests (stale data do FIFO global).
  • Threading: srv.accept() roda no loop principal; _handle() roda em threads
    daemon com um Lock — garante processamento sequencial sem bloquear accept().
  • Backlog aumentado (8): suporta submenus aninhados sem "connection refused".
  • Timeout com cancelamento: _read_fifo() abre o FIFO bloqueante em thread
    separada; ao expirar o timeout, abre o write-end para desbloquear o leitor.

Protocolo:
  Cliente → servidor (socket):
    <JSON>\n          ex: {"prompt":"Manager","entries":["A","B"],...}

  Servidor → QML (stdout):
    <JSON com _fifo>\n  ex: {"prompt":"Manager","entries":[...],"preview_image":"/tmp/ss.png","_fifo":"/run/user/1000/qs-dmenu-out-3"}

  QML → servidor (FIFO exclusivo):
    <JSON>\n          ex: {"selected":"A"}

  Servidor → cliente (socket):
    <JSON>\n          ex: {"selected":"A"}
"""

import sys, os, socket, json, threading

RD        = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
SOCK_PATH = os.path.join(RD, "qs-dmenu.sock")

_counter_lock = threading.Lock()
_counter      = 0

def _next_id():
    global _counter
    with _counter_lock:
        _counter += 1
        return _counter

# ── Setup ──────────────────────────────────────────────────────────────────────
def setup():
    try:
        os.unlink(SOCK_PATH)
    except FileNotFoundError:
        pass

    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(SOCK_PATH)
    os.chmod(SOCK_PATH, 0o600)
    srv.listen(8)   # backlog maior — suporta submenus aninhados
    return srv

# ── Loop principal ─────────────────────────────────────────────────────────────
def main():
    srv = setup()

    # Sinaliza QML que o servidor está pronto
    print(json.dumps({"ready": True, "sock": SOCK_PATH}), flush=True)

    # Lock garante que apenas um request é processado por vez (painel serial).
    # Accept() continua disponível enquanto _handle() está rodando em outra thread.
    lock = threading.Lock()

    while True:
        try:
            conn, _ = srv.accept()
        except OSError:
            break
        t = threading.Thread(target=_handle_locked, args=(conn, lock), daemon=True)
        t.start()

def _handle_locked(conn, lock):
    with lock:
        _handle(conn)

# ── Tratamento de um request ───────────────────────────────────────────────────
def _handle(conn):
    with conn:
        # Lê o JSON do cliente (até \n)
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
            req = json.loads(line)
        except json.JSONDecodeError:
            conn.sendall(b'{"selected":null}\n')
            return

        # preview_image é passado adiante transparentemente (se presente)

        # Cria FIFO exclusivo para este request
        req_id    = _next_id()
        fifo_path = os.path.join(RD, f"qs-dmenu-out-{req_id}")
        _make_fifo(fifo_path)

        # Injeta o path do FIFO no request → QML saberá onde escrever a resposta
        req["_fifo"] = fifo_path

        # Envia request aumentado ao QML via stdout
        sys.stdout.write(json.dumps(req) + "\n")
        sys.stdout.flush()
        print(f"[dmenu-server] req {req_id}: enviado ao QML, aguardando FIFO {fifo_path}", file=sys.stderr, flush=True)

        # Aguarda resposta do QML via FIFO exclusivo (com timeout de 60s)
        response = _read_fifo(fifo_path, timeout=60)
        print(f"[dmenu-server] req {req_id}: resposta={response!r}", file=sys.stderr, flush=True)

        # Limpa o FIFO (seja qual for o resultado)
        try:
            os.unlink(fifo_path)
        except OSError:
            pass

        conn.sendall(((response or '{"selected":null}') + "\n").encode())

# ── FIFO helpers ───────────────────────────────────────────────────────────────
def _make_fifo(path):
    """Cria um FIFO no path dado, removendo se já existir."""
    for _ in range(2):
        try:
            os.mkfifo(path, 0o600)
            return
        except FileExistsError:
            try:
                os.unlink(path)
            except OSError:
                pass

def _read_fifo(path, timeout=60):
    """
    Lê uma linha do FIFO com timeout.

    Abre o FIFO em modo bloqueante dentro de uma thread separada.
    Se o timeout expirar, abre o write-end para desbloquear o leitor
    e aguarda mais 2 segundos para a thread encerrar.

    Retorna a linha lida (string) ou None em caso de timeout/erro.
    """
    result = [None]
    done   = threading.Event()

    def _reader():
        try:
            with open(path, "r") as f:
                line = f.readline().strip()
            result[0] = line if line else None
        except OSError:
            pass
        done.set()

    t = threading.Thread(target=_reader, daemon=True)
    t.start()

    if not done.wait(timeout):
        # Timeout: desbloqueia o leitor abrindo o write-end e escrevendo \n
        try:
            with open(path, "w") as fw:
                fw.write("\n")
        except OSError:
            pass
        done.wait(2)   # aguarda a thread encerrar após o desbloqueio

    return result[0]

if __name__ == "__main__":
    main()
