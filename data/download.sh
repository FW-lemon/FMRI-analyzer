python3 << 'PY'
import ftplib, os
from concurrent.futures import ThreadPoolExecutor

HOST, PORT = "ftp.scidb.cn", 2121
USER, PASS = "73maqy", "Mza6vi"
TARGET = "/home/project/fmri/data"
WORKERS = 8

def list_files(ftp, path=""):
    files, dirs = [], []
    def handle(line):
        parts = line.split()
        if len(parts) < 9: return
        name = parts[-1]
        if name in (".", ".."): return
        full = f"{path}/{name}" if path else name
        (dirs if line.startswith("d") else files).append((full, int(parts[4]) if parts[4].isdigit() else 0))
    ftp.cwd(f"/{path}" if path else "/")
    ftp.retrlines("LIST", handle)
    for d in dirs:
        files.extend(list_files(ftp, d))
    return files

def download(item):
    path, size = item
    local = os.path.join(TARGET, path)
    os.makedirs(os.path.dirname(local), exist_ok=True)
    if os.path.exists(local) and os.path.getsize(local) >= size:
        return True
    try:
        f = ftplib.FTP()
        f.connect(HOST, PORT, timeout=60); f.login(USER, PASS); f.set_pasv(True)
        with open(local, "wb") as fp:
            f.retrbinary(f"RETR {path}", fp.write)
        f.quit()
        return True
    except Exception as e:
        print(f"\n[失败] {path}: {e}")
        return False

ftp = ftplib.FTP()
ftp.connect(HOST, PORT, timeout=60); ftp.login(USER, PASS); ftp.set_pasv(True)
all_files = list_files(ftp)
ftp.quit()

print(f"发现 {len(all_files)} 个文件")
os.makedirs(TARGET, exist_ok=True)

ok = 0
with ThreadPoolExecutor(max_workers=WORKERS) as ex:
    for i, future in enumerate(ex.map(download, all_files)):
        if future: ok += 1
        print(f"\r进度: {i+1}/{len(all_files)}  成功: {ok}", end="")

print(f"\n下载完成！成功: {ok}/{len(all_files)}")
PY
