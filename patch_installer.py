"""把小米超级小爱安装包里 support_tm_list 机型白名单替换成本机机型。
用法: python patch_installer.py <原安装包> <输出安装包> <机型1> [机型2] ...
保持 JSON 合法且总字节长度不变（容器内有固定偏移，长度不能变）。
"""
import sys, json, shutil

KEY = b'"support_tm_list"'


def patch(src, dst, models):
    shutil.copyfile(src, dst)
    b = bytearray(open(dst, 'rb').read())

    # 定位 JSON 里的 "support_tm_list"
    p = b.find(KEY)
    hits = []
    while p != -1:
        # 后面紧跟可选空白再跟 ':' 和 '[' 才算
        q = p + len(KEY)
        while q < len(b) and b[q:q + 1] in (b' ', b'\t', b'\r', b'\n'):
            q += 1
        if b[q:q + 1] == b':':
            q += 1
            while q < len(b) and b[q:q + 1] in (b' ', b'\t', b'\r', b'\n'):
                q += 1
            if b[q:q + 1] == b'[':
                hits.append(q)
        p = b.find(KEY, p + 1)
    if not hits:
        raise SystemExit('未找到 support_tm_list 数组')

    start = hits[0]
    end = b.find(b']', start)
    if end == -1:
        raise SystemExit('数组未闭合')
    end += 1
    L = end - start

    body = '[\n    ' + ',\n    '.join('"%s"' % m for m in models) + '\n  '
    pad = L - len(body) - 1
    if pad < 0:
        raise SystemExit('机型名太长，空间不足 (需要 %d, 可用 %d)'
                         % (len(body) + 1, L))
    rep = (body + ' ' * pad + ']').encode('utf-8')
    assert len(rep) == L

    b[start:end] = rep
    open(dst, 'wb').write(bytes(b))

    # 校验：把该数组抠出来解析
    seg = bytes(b[start:end]).decode('utf-8')
    arr = json.loads(seg)
    print('  原数组长度 %d 字节 -> 新数组 %d 字节' % (L, len(rep)))
    print('  新白名单:', arr)
    print('  文件大小不变:', len(b) == len(open(src, 'rb').read()))
    return arr


if __name__ == '__main__':
    if len(sys.argv) < 4:
        raise SystemExit(__doc__)
    patch(sys.argv[1], sys.argv[2], sys.argv[3:])
