#include "logger.h"

#include <stdio.h>
#include <stdarg.h>

void ks_log(const char *fmt, ...)
{
    static FILE *f = NULL;

    if (!f)
        f = fopen("killswitch.log", "w");

    if (!f)
        return;

    va_list args;
    va_start(args, fmt);
    vfprintf(f, fmt, args);
    va_end(args);

    fputc('\n', f);
    fflush(f);
}