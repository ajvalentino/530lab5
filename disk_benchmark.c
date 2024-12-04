#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <getopt.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>

// Define maximum offset (1GB)
#define MAX_OFFSET (1 << 30)

// Function to get current time in microseconds
unsigned long get_time_us() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (unsigned long)(tv.tv_sec * 1000000 + tv.tv_usec);
}

int main(int argc, char *argv[]) {
    // Default parameters
    char *device = NULL;
    size_t io_size = 4096; // 4KB
    size_t stride = 0;
    size_t num_ops = 256; // Default number of operations
    int random_io = 0;
    char *operation = "write";

    // Parse command-line arguments
    int opt;
    while ((opt = getopt(argc, argv, "d:s:t:n:ro:")) != -1) {
        switch (opt) {
            case 'd':
                device = optarg;
                break;
            case 's':
                io_size = atoi(optarg);
                break;
            case 't':
                stride = atoi(optarg);
                break;
            case 'n':
                num_ops = atoi(optarg);
                break;
            case 'r':
                random_io = 1;
                break;
            case 'o':
                operation = optarg;
                break;
            default:
                fprintf(stderr, "Usage: %s -d device -s io_size -t stride -n num_ops -r -o operation\n", argv[0]);
                exit(EXIT_FAILURE);
        }
    }

    if (device == NULL) {
        fprintf(stderr, "Device not specified. Use -d to specify the device.\n");
        exit(EXIT_FAILURE);
    }

    // Open the device with O_DIRECT to bypass OS caching
    int fd = open(device, O_RDWR | O_DIRECT);
    if (fd == -1) {
        perror("open");
        exit(EXIT_FAILURE);
    }

    // Allocate aligned buffer
    void *buffer;
    if (posix_memalign(&buffer, 4096, io_size)) {
        perror("posix_memalign");
        exit(EXIT_FAILURE);
    }
    memset(buffer, 0, io_size); // Initialize buffer

    unsigned long start_time = get_time_us();

    off_t offset = 0;
    size_t total_bytes = 0;
    for (size_t i = 0; i < num_ops; i++) {
        if (random_io) {
            // Generate random offset within the first 1GB
            offset = (off_t)(rand() % ((1 << 30) / io_size)) * io_size;
        }

        // Ensure the offset doesn't exceed the MAX_OFFSET (1GB)
        if (offset >= MAX_OFFSET) {
            offset = 0;  // Reset the offset to 0 if it exceeds MAX_OFFSET
        }

        // Seek to the desired offset
        if (lseek(fd, offset, SEEK_SET) == -1) {
            perror("lseek");
            exit(EXIT_FAILURE);
        }

        ssize_t ret;
        if (strcmp(operation, "write") == 0) {
            ret = write(fd, buffer, io_size);
        } else {
            ret = read(fd, buffer, io_size);
        }

        if (ret != io_size) {
            fprintf(stderr, "I/O operation failed\n");
            exit(EXIT_FAILURE);
        }

        total_bytes += ret;

        // Update the offset with both io_size and stride for spaced-out writes/reads
        offset += io_size + stride;
    }

    // Flush to disk if writing
    if (strcmp(operation, "write") == 0) {
        if (fsync(fd) == -1) {
            perror("fsync");
            exit(EXIT_FAILURE);
        }
    }

    unsigned long end_time = get_time_us();
    double elapsed_time_sec = (end_time - start_time) / 1e6;

    double throughput = total_bytes / elapsed_time_sec / (1 << 20); // MB/s

    printf("Total bytes %s: %zu\n", operation, total_bytes);
    printf("Elapsed: %.6f seconds\n", elapsed_time_sec);
    printf("Throughput: %.2f MB/s\n", throughput);

    // Clean up
    free(buffer);
    close(fd);

    return 0;
}
