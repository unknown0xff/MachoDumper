//
//  MachoMemDumper.mm
//  kext-extract
//
//  Created by k on 2022/12/29.
//

#include "MachoMemLoader.h"

reoff_t *
new_reoff(adr src, adr dst, siz size)
{
    reoff_t *reoff = (reoff_t *)malloc(sizeof(reoff_t));
    reoff->srcoff = src;
    reoff->dstoff = dst;
    reoff->size = size;
    return reoff;
}


void
forEachArray(void *array, void(^handler)(void *data))
{
    void **list = (void **)array;
    for (int i = 0; i < array_count(array); ++i) {
        handler(list[i]);
    }
}


bool
mmacho_load(mmacho_t *mmacho, adr address, adr filebase)
{
    mach_header_64_t *hdr = (mach_header_64_t *)address;

    mmacho->hdr = hdr;
    mmacho->hdr_size = sizeof(*hdr) + hdr->sizeofcmds;
    mmacho->filebase = filebase;
    return true;
}


void
mmacho_dump(mmacho_t *mmacho, const char* filename)
{
    __block FILE *f;
    f = fopen(filename, "wb");
    if (!f) {
        return;
    }
        
    __block mach_header_64_t *hdr = (mach_header_64_t *)malloc(mmacho->hdr_size);
    __block reoff_t **remap_list = (reoff_t **)array_alloc(0);
    
    //# symtab_command_t
    __block symtab_command_t *symtab = NULL;
    __block dysymtab_command_t *dy_symtab = NULL;
    
    __block u32 linkedit_old_base = 0;
    __block u32 linkedit_new_base = 0;
    __block siz new_offset = 0;
    
    // init new header
    memcpy(hdr, mmacho->hdr, mmacho->hdr_size);
    
    forEachCommand(hdr, ^(load_command_t *lc) {
        // fixup LC SYMTAB
        if (lc->cmd == LC_SEGMENT_64) {
            segment_command_64_t *segment = (segment_command_64_t *)lc;
            
            u32 old_base = (u32)segment->fileoff;
            u32 new_base = (u32)new_offset;
            u32 data_size = (u32)segment->filesize;

            segment->fileoff = new_base;
            new_offset += data_size;
            
            section_64_t *section_list = (section_64_t *)((adr)segment + sizeof(*segment));
            
            for (u32 i = 0; i < segment->nsects; ++i) {
                if (section_list[i].offset) {
                    if (section_list[i].size) {
                        array_addptr(&remap_list,
                                     new_reoff(section_list[i].offset,
                                               section_list[i].offset - old_base + new_base,
                                               section_list[i].size));
                    }
                                 
                    section_list[i].offset = section_list[i].offset - old_base + new_base;
                }
            }
            
            if (strcmp(segment->segname, "__LINKEDIT") == 0) {
                linkedit_old_base = old_base;
                linkedit_new_base = new_base;
            }
            
        } else if (lc->cmd == LC_SYMTAB) {
            symtab = (symtab_command_t *)lc;
            u32 old_base = (u32)linkedit_old_base;
            u32 new_base = (u32)linkedit_new_base;
            
            u32 old_offset = (u32)symtab->symoff;
            u32 data_size = (u32)symtab->nsyms * sizeof(nlist_64_t);
            
            // symoff
            if (old_offset) {
                if (data_size) {
                    array_addptr(&remap_list,
                                 new_reoff(old_offset,
                                           old_offset - old_base + new_base,
                                           data_size));
                }
                symtab->symoff = old_offset - old_base + new_base;
            }
            
            // stroff
            old_offset = (u32)symtab->stroff;
            data_size = (u32)symtab->strsize;
            
            if (old_offset) {
                if (data_size) {
                    array_addptr(&remap_list,
                                 new_reoff(old_offset,
                                           old_offset - old_base + new_base,
                                           data_size));
                }
                symtab->stroff = old_offset - old_base + new_base;
            }
            
        } else if (lc->cmd == LC_DYSYMTAB) {
            dy_symtab = (dysymtab_command_t *)lc;
            
        } else if (lc->cmd == LC_SEGMENT_SPLIT_INFO ||
                   lc->cmd == LC_CODE_SIGNATURE ||
                   lc->cmd == LC_FUNCTION_STARTS ||
                   lc->cmd == LC_DATA_IN_CODE ||
                   lc->cmd == LC_DYLIB_CODE_SIGN_DRS ||
                   lc->cmd == LC_LINKER_OPTIMIZATION_HINT ||
                   lc->cmd == LC_DYLD_EXPORTS_TRIE ||
                   lc->cmd == LC_DYLD_CHAINED_FIXUPS) {
            
            struct linkedit_data_command *linkedit_data = \
                (struct linkedit_data_command *)lc;
            
            u32 old_offset = (u32)linkedit_data->dataoff;
            u32 old_base = (u32)linkedit_old_base;
            u32 new_base = (u32)linkedit_new_base;
            u32 data_size = (u32)linkedit_data->datasize;
            
            if (old_offset) {
                if (data_size) {
                    array_addptr(&remap_list,
                                 new_reoff(old_offset,
                                           old_offset - old_base + new_base,
                                           data_size));
                }
            }
            linkedit_data->dataoff = old_offset - old_base + new_base;
        }
    });
        
    fwrite(hdr, mmacho->hdr_size, 1, f);

    int nreoff_list = array_count(remap_list);
    for (int i = 0; i < nreoff_list; ++i) {
        if (remap_list[i]) {
            fseek(f, remap_list[i]->dstoff, SEEK_SET);
            fwrite((u8 *)(mmacho->filebase + remap_list[i]->srcoff), remap_list[i]->size, 1, f);
        }
    }
    
    forEachArray(remap_list, ^(void *data) {
        free(data);
    });
    array_destroy(remap_list);
}
