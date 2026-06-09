// Stub xil_printf — no UART output, just return immediately
// Link before libxil.a to override the real xil_printf
void xil_printf(const char *fmt, ...) {
    (void)fmt;
}
void print(const char *fmt, ...) {
    (void)fmt;
}
void puts(const char *s) {
    (void)s;
}
void putnum(unsigned long num) {
    (void)num;
}
