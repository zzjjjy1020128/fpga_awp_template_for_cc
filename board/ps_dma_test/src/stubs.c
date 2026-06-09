// Stubs for libc functions needed by BSP
void __libc_init_array(void) {}
void __libc_fini_array(void) {}
void exit(int code) { (void)code; while(1); }
void _exit(int code) { (void)code; while(1); }

void *malloc(unsigned long size) {
    (void)size;
    return (void*)0x00300000; // simple bump allocator — enough for DMA descriptors
}
void free(void *ptr) { (void)ptr; }
void *memset(void *s, int c, unsigned long n) {
    unsigned char *p = (unsigned char*)s;
    for (unsigned long i = 0; i < n; i++) p[i] = (unsigned char)c;
    return s;
}
void *memcpy(void *d, const void *s, unsigned long n) {
    unsigned char *dd = (unsigned char*)d;
    const unsigned char *ss = (const unsigned char*)s;
    for (unsigned long i = 0; i < n; i++) dd[i] = ss[i];
    return d;
}
