#!/bin/bash

DEVICE="./testfile"
OUTPUT_DIR="./results"
mkdir -p $OUTPUT_DIR

IO_SIZES=(4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304 8388608 16777216 33554432 67108864 100663296)
STRIDES=(4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304 8388608 16777216 33554432 67108864 100663296)
NUM_OPS=256

# Function to calculate NUM_OPS based on IO_SIZE to cover 1GB
calculate_num_ops() {
    local io_size=$1
    echo $(( (1 * 1024 * 1024 * 1024) / io_size ))
}

# I/O Size Test
for OP in read write; do
    OUTPUT_FILE="$OUTPUT_DIR/io_size_${OP}.txt"
    echo "IO_SIZE(Bytes),ElapsedTime(s),Throughput(MB/s)" > $OUTPUT_FILE
    for IO_SIZE in "${IO_SIZES[@]}"; do
        NUM_OPS=$(calculate_num_ops $IO_SIZE)
        echo "Running ${OP} test with IO_SIZE=${IO_SIZE}"
        OUTPUT=$(./disk_benchmark -d $DEVICE -s $IO_SIZE -n $NUM_OPS -o $OP)
        ELAPSED=$(echo "$OUTPUT" | grep "Elapsed" | awk '{print $2}')
        THROUGHPUT=$(echo "$OUTPUT" | grep "Throughput" | awk '{print $2}')
        echo "${IO_SIZE},${ELAPSED},${THROUGHPUT}" >> $OUTPUT_FILE
    done
done

# I/O Stride Test
for OP in read write; do
    if [ "$OP" == "read" ]; then
        OUTPUT_FILE="$OUTPUT_DIR/io_stride_read_operations.txt"
        echo "IO_Size(Bytes),Stride(Bytes),ElapsedTime(s),Throughput(MB/s)" > $OUTPUT_FILE
    else
        OUTPUT_FILE="$OUTPUT_DIR/io_stride_write_operations.txt"
        echo "IO_Size(Bytes),Stride(Bytes),ElapsedTime(s),Throughput(MB/s)" > $OUTPUT_FILE
    fi
    
    for IO_SIZE in 4096 16384 65536 262144 1048576; do
        NUM_OPS=$(calculate_num_ops $IO_SIZE)
        for STRIDE in "${STRIDES[@]}"; do
            echo "Running ${OP} test with IO_SIZE=${IO_SIZE} and STRIDE=${STRIDE}"
            OUTPUT=$(./disk_benchmark -d $DEVICE -s $IO_SIZE -t $STRIDE -n $NUM_OPS -o $OP)
            ELAPSED=$(echo "$OUTPUT" | grep "Elapsed" | awk '{print $2}')
            THROUGHPUT=$(echo "$OUTPUT" | grep "Throughput" | awk '{print $2}')
            echo "${IO_SIZE},${STRIDE},${ELAPSED},${THROUGHPUT}" >> $OUTPUT_FILE
        done
    done
done


# Random I/O Test
for OP in read write; do
    OUTPUT_FILE="$OUTPUT_DIR/random_io_${OP}.txt"
    echo "IO_SIZE(Bytes),ElapsedTime(s),Throughput(MB/s)" > $OUTPUT_FILE
    for IO_SIZE in "${IO_SIZES[@]}"; do
        NUM_OPS=$(calculate_num_ops $IO_SIZE)
        echo "Running random ${OP} test with IO_SIZE=${IO_SIZE}"
        OUTPUT=$(./disk_benchmark -d $DEVICE -s $IO_SIZE -n $NUM_OPS -o $OP -r)
        ELAPSED=$(echo "$OUTPUT" | grep "Elapsed" | awk '{print $2}')
        THROUGHPUT=$(echo "$OUTPUT" | grep "Throughput" | awk '{print $2}')
        echo "${IO_SIZE},${ELAPSED},${THROUGHPUT}" >> $OUTPUT_FILE
    done
done
