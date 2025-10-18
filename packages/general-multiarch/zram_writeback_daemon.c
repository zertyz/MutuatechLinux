// Compile with `gcc -o zram_writeback_daemon zram_writeback_daemon.c -O3 -s`

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <time.h>

#define DEFAULT_POOLING_TIME_SECS 30  // Default pooling time -- the loop iteration period will be `DEFAULT_POOLING_TIME_SECS * (DEFAULT_HUGE_PAGES_WEIGHT + 1)` -- 5 minutes with these defaults
#define DEFAULT_HUGE_PAGES_WEIGHT 9  // Default huge pages weight
#define DEFAULT_ZRAM_DEV "zram0"  // Default ZRAM device
#define BUFFER_SIZE 256

void print_usage(const char *progname) {
    printf("Usage: %s [options]\n", progname);
    printf("Options:\n");
    printf("  -p <seconds>   Set the polling time (default: %d seconds)\n", DEFAULT_POOLING_TIME_SECS);
    printf("  -w <weight>    Set the huge pages weight (default: %d)\n", DEFAULT_HUGE_PAGES_WEIGHT);
    printf("  -z <device>    Set the ZRAM device (default: %s)\n", DEFAULT_ZRAM_DEV);
    printf("  -v             Enable verbose output\n");
    printf("  -s             Show statistics after each loop\n");
    printf("  -h             Show this help message\n");
    printf("\nExamples:\n");
    printf("  %s -p 600 -w 10 -z zram1 -v -s\n", progname);
    printf("\nZRAM setup suggestion:\n");
    printf("  PARTUUID=\"xxxx\"; swapon -s; swapoff /dev/zram0; rmmod zram; sleep 1;\n");
    printf("  modprobe zram; echo 1 >/sys/block/zram0/reset; sleep 1;\n");
    printf("  echo /dev/disk/by-partuuid/$PARTUUID >/sys/block/zram0/backing_dev;\n");
    printf("  echo zstd >/sys/block/zram0/comp_algorithm; echo 32g >/sys/block/zram0/disksize;\n");
    printf("  echo 14g >/sys/block/zram0/mem_limit;\n");
    printf("  echo all >/sys/block/zram0/writeback; mkswap /dev/zram0; swapon /dev/zram0; swapon -s\n");
    printf("\nObjective:\n");
    printf("  To squeeze the most performance possible in scenarios where workloads far exceed the available RAM memory.\n");
    printf("  This approach is superior to ZSWAP as data is written back asynchronously, allowing processes to continue\n");
    printf("  while data is offloaded from RAM to the writeback device.\n");
    printf("  Due to the nature of ZRAM, an active service is needed to coordinate the writeback activity.\n");
    printf("  This executable offers just the smallest possible solution.\n");
    printf("\nReference:\n");
    printf("  https://docs.kernel.org/admin-guide/blockdev/zram.html\n");
}

void write_to_file(const char *path, const char *value, int verbose) {
    int fd = open(path, O_WRONLY);
    if (fd < 0) {
        perror("Error opening file");
        exit(EXIT_FAILURE);
    }
    if (write(fd, value, strlen(value)) < 0) {
        if (errno == EIO || errno == ENOSPC) {
            // Transient errors, handle silently
        } else {
            perror("Error writing to file");
            close(fd);
            exit(EXIT_FAILURE);
        }
    }
    close(fd);
}

void print_stats(const char *zram_dev) {
    FILE *file;
    char buffer[BUFFER_SIZE];
    long swap_total = 0, swap_used = 0;
    long orig_data_size = 0, compr_data_size = 0, mem_used_total = 0, mem_limit = 0, mem_used_max = 0, same_pages = 0, pages_compacted = 0, huge_pages = 0, huge_pages_since = 0;
    long bd_count = 0, bd_reads = 0, bd_writes = 0;
    char zram_stat_path[BUFFER_SIZE];

    // Parse swap usage
    file = fopen("/proc/swaps", "r");
    if (file == NULL) {
        perror("Error opening /proc/swaps");
        exit(EXIT_FAILURE);
    }
    fgets(buffer, BUFFER_SIZE, file); // Skip header line
    while (fgets(buffer, BUFFER_SIZE, file) != NULL) {
        long size, used;
        sscanf(buffer, "%*s %*s %ld %ld", &size, &used);
        swap_total += size;
        swap_used += used;
    }
    fclose(file);

    // Parse ZRAM statistics
    snprintf(zram_stat_path, BUFFER_SIZE, "/sys/block/%s/mm_stat", zram_dev);
    file = fopen(zram_stat_path, "r");
    if (file == NULL) {
        perror("Error opening ZRAM mm statistics file");
        exit(EXIT_FAILURE);
    }
    if (fgets(buffer, BUFFER_SIZE, file) != NULL) {
        sscanf(buffer, "%ld %ld %ld %ld %ld %ld %ld %ld %ld", &orig_data_size, &compr_data_size, &mem_used_total, &mem_limit, &mem_used_max, &same_pages, &pages_compacted, &huge_pages, &huge_pages_since);
    }
    fclose(file);

    // Parse the backing device statistics
    snprintf(zram_stat_path, BUFFER_SIZE, "/sys/block/%s/bd_stat", zram_dev);
    file = fopen(zram_stat_path, "r");
    if (file == NULL) {
        perror("Error opening ZRAM backing device statistics file");
        exit(EXIT_FAILURE);
    }
    if (fgets(buffer, BUFFER_SIZE, file) != NULL) {
        sscanf(buffer, "%ld %ld %ld", &bd_count, &bd_reads, &bd_writes);
    }
    fclose(file);

    // Print parsed statistics in a single line
    printf("Swap: %.2lf% (%.2lfg/%.2lfg) | ZRAM: Compression: %.2lfx (%.2lfg/%.2lfg); SamePages=%ld; PagesCompacted=%ld; HugePages=%ld, HugeSince=%.2lfg | Backing Dev blocks: Used=%.2lfg; Reads=%.2lfg; Writes=%.2lfg\n",
           100.0*((float)swap_used/(float)swap_total), (float)swap_used/(1024.0*1024.0), (float)swap_total/(1024.0*1024.0),
	   (float)orig_data_size/(float)compr_data_size, (float)orig_data_size/(1024.0*1024.0*1024.0), (float)compr_data_size/(1024.0*1024.0*1024.0),
	   same_pages,
	   pages_compacted,
	   huge_pages,
	   (float)huge_pages_since*4.0/(1024.0*1024.0),
           (float)bd_count*4.0/(1024.0*1024.0),
	   (float)bd_reads*4.0/(1024.0*1024.0),
	   (float)bd_writes*4.0/(1024.0*1024.0));
}

int main(int argc, char *argv[]) {
    int pooling_time_secs = DEFAULT_POOLING_TIME_SECS;
    int huge_pages_weight = DEFAULT_HUGE_PAGES_WEIGHT;
    int verbose = 0;
    int show_stats = 0;
    const char *zram_dev = DEFAULT_ZRAM_DEV;
    int opt;

    while ((opt = getopt(argc, argv, "p:w:z:vsh")) != -1) {
        switch (opt) {
            case 'p':
                pooling_time_secs = atoi(optarg);
                break;
            case 'w':
                huge_pages_weight = atoi(optarg);
                break;
            case 'z':
                zram_dev = optarg;
                break;
            case 'v':
                verbose = 1;
                break;
            case 's':
                show_stats = 1;
                break;
            case 'h':
            default:
                print_usage(argv[0]);
                exit(EXIT_SUCCESS);
        }
    }

    char idle_path[BUFFER_SIZE];
    char writeback_path[BUFFER_SIZE];
    char compact_path[BUFFER_SIZE];
    snprintf(idle_path, BUFFER_SIZE, "/sys/block/%s/idle", zram_dev);
    snprintf(writeback_path, BUFFER_SIZE, "/sys/block/%s/writeback", zram_dev);
    snprintf(compact_path, BUFFER_SIZE, "/sys/block/%s/compact", zram_dev);

    struct timespec start, end;
    while (1) {
        // mark current pages as "idle" -- they will be offloaded at the end of the loop if they are still around
        write_to_file(idle_path, "all", verbose);
        if (verbose) {
            printf("Writing out huge pages: ");
            fflush(stdout);
        }
        for (int i = 1; i <= huge_pages_weight; i++) {
            write_to_file(compact_path, "y", verbose);
            if (verbose) {
                printf("<%d:", i);
                fflush(stdout);
                clock_gettime(CLOCK_MONOTONIC, &start);
            }
            // offline huge pages
            write_to_file(writeback_path, "huge", verbose);
            if (verbose) {
		clock_gettime(CLOCK_MONOTONIC, &end);
		double elapsed = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) * 1e-9;
                printf("%.2lfs>", elapsed);
                fflush(stdout);
            }
            sleep(pooling_time_secs);
        }
        write_to_file(compact_path, "y", verbose);
        if (verbose) {
            printf("\nWriting out all idle pages: <1:");
            fflush(stdout);
            clock_gettime(CLOCK_MONOTONIC, &start);
        }
        // offload idle pages that are still around
        write_to_file(writeback_path, "idle", verbose);
        if (verbose) {
            clock_gettime(CLOCK_MONOTONIC, &end);
	    double elapsed = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) * 1e-9;
            printf("%.2lfs>\n", elapsed);
            fflush(stdout);
        }
        if (show_stats) {
            print_stats(zram_dev);
        }
        sleep(pooling_time_secs);
    }
    return 0;
}
