//
//  main.mm

// c
#include <stdlib.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
// sys
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <dlfcn.h>

// function
// #include <mach-o/loader.h>
#include "MachoMemLoader.h"

// objc
#import <Foundation/Foundation.h>

void *
map_file(const char *filename, size_t *out_size)
{
    int fd, rv;
    size_t len;
    void *mem;
    
    if ((fd = open(filename, O_RDWR | O_CREAT)) < 0) {
        return NULL;
    }
    
    struct stat st;
    if ((rv = fstat(fd, &st)) < 0) {
        close(fd);
        return NULL;
    }
    len = st.st_size;
    if (!len) {
        close(fd);
        return NULL;
    }
    mem = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    
    if (mem == MAP_FAILED) {
        close(fd);
        return NULL;
    }
    
    *out_size = len;
    close(fd);
    return mem;
}

int main(int argc, const char *argv[]) {
        
#ifdef DEBUG
    const char* v[] = {
        "kext-extract",
        "/Users/k/home/re/kernelcache/BootKernelCollection.kc",
        "/Users/k/home/re/kernelcache/test"};
    argc = 3;
    argv = v;
#endif
    
/*#ifdef DEBUG
    mmacho_t mml0;
    size_t mm0_size;
    void *mm0 = map_file("/Users/k/home/re/kernelcache/kernel.release.t6000-orig", &mm0_size);
    mmacho_load(&mml0, (adr)mm0, (adr)mm0);
    mmacho_dump(&mml0, "/Users/k/home/re/kernelcache/kernel.release.t6000-test");
    return 0;
#endif*/
    
    if (argc >= 3) {
        const char *filename = argv[1];
        const char *ofilepath = argv[2];
        
        void *mem;
        size_t size;
        mem = map_file(filename, &size);
        
        if (!mem) {
            printf("cloud not map file: %s\n", filename);
            return -1;
        }
        
        mach_header_64_t *hdr = (mach_header_64_t *)mem;
        
        forEachCommand(hdr, ^(load_command_t *lc) {
            if (lc->cmd == LC_FILESET_ENTRY) {
                struct fileset_entry_command *fileset_entry = \
                (struct fileset_entry_command *)lc;
                
                const char *kext_name = (const char *)((adr)fileset_entry + fileset_entry->entry_id.offset);
                adr kext_hdr = (adr)mem + fileset_entry->fileoff;
                
                //if (strcmp(kext_name, "com.apple.kernel") == 0) {
                    
                    printf("kext_name: %s\n", kext_name);
                    printf("kext header: 0x%zx\n", kext_hdr);
                    printf("found\n");
                    
                    mmacho_t mm;
                    mmacho_load(&mm, kext_hdr, (adr)mem);
                    
                    char kext_path[PATH_MAX];
                    snprintf(kext_path, PATH_MAX, "%s/%s", ofilepath, kext_name);
                    
                    printf("will dump at %s\n", kext_path);
                    mmacho_dump(&mm, kext_path);
                //}
                
            }
            //# printf("cmd:%d, %d\n", lc->cmd, lc->cmdsize);
        });
        
        printf("done.\n");
    }

    return 0;
}
