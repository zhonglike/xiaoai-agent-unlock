"""给小米超级小爱安装包打两个等长补丁（不改文件总长度）：
  1. pf64            -> 把安装根目录从 C 盘改到指定盘（默认 E 盘）
  2. support_tm_list -> 换成本机真实机型，绕过机型校验（通用，任意品牌）
用法: python patch_installer2.py <原安装包> <输出安装包> [安装盘符] [机型1 机型2 ...]
"""
import sys, shutil, json

src, dst = sys.argv[1], sys.argv[2]
drive = sys.argv[3] if len(sys.argv) > 3 else 'E'
models = sys.argv[4:] or ['LNVNB161216']

shutil.copyfile(src, dst)
data = bytearray(open(dst, 'rb').read())
orig_len = len(data)

# ---- 1. 安装根目录 ----
old = b'"pf64": "C:\\\\Program Files"'
new = b'"pf64": "%s:\\\\Program Files"' % drive.encode()
assert len(old) == len(new), 'pf64 补丁长度不一致'
i = data.find(old)
assert i > 0, '未找到 pf64 配置'
data[i:i + len(old)] = new
print('[1] 安装目录已改为 %s:\\Program Files  (offset %d)' % (drive, i))

# ---- 2. 机型白名单 ----
key = b'"support_tm_list": ['
p = data.find(key)
assert p > 0, '未找到 support_tm_list'
start = p + len(key) - 1              # 指向 '['
end = data.find(b']', start)
assert end > start, '数组未闭合'
end += 1
L = end - start

body = '[\n    ' + ',\n    '.join('"%s"' % m for m in models) + '\n  '
pad = L - len(body) - 1
assert pad >= 0, '机型名过长，空间不足'
rep = (body + ' ' * pad + ']').encode('utf-8')
assert len(rep) == L

data[start:end] = rep
print('[2] 白名单已替换为', json.loads(rep.decode()))

open(dst, 'wb').write(bytes(data))
assert len(data) == orig_len, '文件总长度被改变！'
print('[+] 总长度保持不变: %d 字节' % orig_len)
