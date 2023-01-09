//
//  MachoMemDumper.hpp
//  kext-extract
//
//  Created by k on 2022/12/29.
//

#ifndef MachoMemDumper_h
#define MachoMemDumper_h

//# c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

//# sys
#include <mach-o/loader.h>

//# self
#include "mach-o.h"
#include "array.h"
#include "xtypedef.h"


// typedef
typedef unsigned long adr;
typedef unsigned long siz;

struct s_reoff {
    adr srcoff;
    adr dstoff;
    siz size;
};

struct s_mmacho {
    mach_header_64_t *hdr;
    adr filebase;
    siz hdr_size;
};

typedef struct s_reoff reoff_t;
typedef struct s_mmacho mmacho_t;

bool mmacho_load(mmacho_t *mmacho, adr address, adr filebase);
void mmacho_dump(mmacho_t *mmacho, const char* filename);

#endif /* MachoMemDumper_h */
