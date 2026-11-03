import ctypes, sys, os
la = ctypes.CDLL('libarchive.so.13')
la.archive_read_new.restype = ctypes.c_void_p
la.archive_entry_pathname.restype = ctypes.c_char_p
la.archive_entry_pathname.argtypes = [ctypes.c_void_p]
la.archive_read_support_format_zip_streamable.argtypes = [ctypes.c_void_p]
la.archive_read_support_filter_all.argtypes = [ctypes.c_void_p]
la.archive_read_open_filename.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t]
la.archive_read_next_header.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)]
la.archive_read_data.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t]
la.archive_read_data.restype = ctypes.c_ssize_t
src, dst = sys.argv[1], sys.argv[2]
a = la.archive_read_new()
la.archive_read_support_format_zip_streamable(a)
la.archive_read_support_filter_all(a)
assert la.archive_read_open_filename(a, src.encode(), 65536) == 0
e = ctypes.c_void_p(); n = 0
buf = ctypes.create_string_buffer(1 << 16)
while la.archive_read_next_header(a, ctypes.byref(e)) == 0:
    name = la.archive_entry_pathname(e).decode('utf-8', 'replace')
    out = os.path.normpath(os.path.join(dst, name))
    assert out.startswith(os.path.abspath(dst))
    data = bytearray()
    while True:
        r = la.archive_read_data(a, buf, len(buf))
        if r <= 0: break
        data += buf.raw[:r]
    if name.endswith('/'): continue
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, 'wb').write(data); n += 1
print(n, 'files')
