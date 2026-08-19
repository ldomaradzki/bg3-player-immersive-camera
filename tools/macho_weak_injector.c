#include <errno.h>
#include <fcntl.h>
#include <libkern/OSByteOrder.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

static const char *load_path = "@loader_path/libbg3se.dylib";

static bool range_ok(size_t offset, size_t length, size_t size)
{
    return offset <= size && length <= size - offset;
}

static bool patch_slice(uint8_t *base, size_t size, const char *architecture)
{
    if (!range_ok(0, sizeof(struct mach_header_64), size)) {
        fprintf(stderr, "%s slice is truncated\n", architecture);
        return false;
    }

    struct mach_header_64 *header = (struct mach_header_64 *)base;
    if (header->magic != MH_MAGIC_64) {
        fprintf(stderr, "%s slice is not a little-endian 64-bit Mach-O\n", architecture);
        return false;
    }

    size_t commands_start = sizeof(*header);
    if (!range_ok(commands_start, header->sizeofcmds, size)) {
        fprintf(stderr, "%s load commands are invalid\n", architecture);
        return false;
    }

    uint8_t *cursor = base + commands_start;
    uint8_t *commands_end = cursor + header->sizeofcmds;
    uint32_t first_data_offset = UINT32_MAX;

    for (uint32_t index = 0; index < header->ncmds; index++) {
        if (!range_ok((size_t)(cursor - base), sizeof(struct load_command), size)) {
            fprintf(stderr, "%s load command is truncated\n", architecture);
            return false;
        }

        struct load_command *command = (struct load_command *)cursor;
        if (command->cmdsize < sizeof(*command) || cursor + command->cmdsize > commands_end) {
            fprintf(stderr, "%s load command size is invalid\n", architecture);
            return false;
        }

        if (command->cmd == LC_LOAD_DYLIB || command->cmd == LC_LOAD_WEAK_DYLIB) {
            struct dylib_command *dylib = (struct dylib_command *)command;
            if (dylib->dylib.name.offset < command->cmdsize) {
                const char *name = (const char *)command + dylib->dylib.name.offset;
                size_t available = command->cmdsize - dylib->dylib.name.offset;
                if (strnlen(name, available) < available && strcmp(name, load_path) == 0) {
                    return true;
                }
            }
        }

        if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64)) {
            struct segment_command_64 *segment = (struct segment_command_64 *)command;
            size_t sections_size = (size_t)segment->nsects * sizeof(struct section_64);
            if (sizeof(*segment) + sections_size > command->cmdsize) {
                fprintf(stderr, "%s segment sections are invalid\n", architecture);
                return false;
            }
            struct section_64 *sections = (struct section_64 *)(segment + 1);
            for (uint32_t section_index = 0; section_index < segment->nsects; section_index++) {
                if (sections[section_index].offset != 0 && sections[section_index].offset < first_data_offset) {
                    first_data_offset = sections[section_index].offset;
                }
            }
        }

        cursor += command->cmdsize;
    }

    if (cursor != commands_end || first_data_offset == UINT32_MAX) {
        fprintf(stderr, "%s Mach-O layout is unsupported\n", architecture);
        return false;
    }

    size_t name_size = strlen(load_path) + 1;
    size_t command_size = (sizeof(struct dylib_command) + name_size + 7u) & ~7u;
    size_t command_offset = commands_start + header->sizeofcmds;
    if (command_offset > first_data_offset || command_size > first_data_offset - command_offset) {
        fprintf(stderr, "%s has no room for the BG3SE load command\n", architecture);
        return false;
    }

    struct dylib_command *new_command = (struct dylib_command *)(base + command_offset);
    memset(new_command, 0, command_size);
    new_command->cmd = LC_LOAD_WEAK_DYLIB;
    new_command->cmdsize = (uint32_t)command_size;
    new_command->dylib.name.offset = sizeof(*new_command);
    new_command->dylib.timestamp = 2;
    memcpy((uint8_t *)new_command + sizeof(*new_command), load_path, name_size);

    header->ncmds += 1;
    header->sizeofcmds += (uint32_t)command_size;
    return true;
}

static bool patch_file(uint8_t *data, size_t size)
{
    if (!range_ok(0, sizeof(uint32_t), size)) {
        return false;
    }

    uint32_t magic = *(uint32_t *)data;
    if (magic == MH_MAGIC_64) {
        return patch_slice(data, size, "native");
    }
    if (magic != FAT_CIGAM) {
        fprintf(stderr, "Input is not a supported universal Mach-O\n");
        return false;
    }

    if (!range_ok(0, sizeof(struct fat_header), size)) {
        return false;
    }
    struct fat_header *fat = (struct fat_header *)data;
    uint32_t count = OSSwapBigToHostInt32(fat->nfat_arch);
    size_t table_size = (size_t)count * sizeof(struct fat_arch);
    if (!range_ok(sizeof(*fat), table_size, size)) {
        fprintf(stderr, "Universal architecture table is invalid\n");
        return false;
    }

    struct fat_arch *architectures = (struct fat_arch *)(fat + 1);
    for (uint32_t index = 0; index < count; index++) {
        uint32_t offset = OSSwapBigToHostInt32(architectures[index].offset);
        uint32_t slice_size = OSSwapBigToHostInt32(architectures[index].size);
        cpu_type_t cpu = (cpu_type_t)OSSwapBigToHostInt32(architectures[index].cputype);
        const char *name = cpu == CPU_TYPE_ARM64 ? "arm64" :
            (cpu == CPU_TYPE_X86_64 ? "x86_64" : "unknown");
        if (!range_ok(offset, slice_size, size) || !patch_slice(data + offset, slice_size, name)) {
            return false;
        }
    }
    return true;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <Mach-O executable>\n", argv[0]);
        return 64;
    }

    int fd = open(argv[1], O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "Cannot open %s: %s\n", argv[1], strerror(errno));
        return 1;
    }

    struct stat info;
    if (fstat(fd, &info) != 0 || info.st_size <= 0) {
        fprintf(stderr, "Cannot inspect %s\n", argv[1]);
        close(fd);
        return 1;
    }

    size_t size = (size_t)info.st_size;
    uint8_t *data = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (data == MAP_FAILED) {
        fprintf(stderr, "Cannot map %s: %s\n", argv[1], strerror(errno));
        close(fd);
        return 1;
    }

    bool success = patch_file(data, size);
    if (success && msync(data, size, MS_SYNC) != 0) {
        fprintf(stderr, "Cannot save %s: %s\n", argv[1], strerror(errno));
        success = false;
    }
    munmap(data, size);
    close(fd);
    return success ? 0 : 1;
}
