#!/bin/sh -ex

_gpu_configure(){
    # Set GPU driver persistence
    sudo nvidia-smi -pm 1 
    # Max GPU power
    power_limit=`nvidia-smi -q -d POWER | grep "Max Power Limit" | grep -o "[0-9\.]*" | head -1`
    sudo nvidia-smi -pl $power_limit
    # Max GPU freq
    sm_freq=`nvidia-smi -q -d SUPPORTED_CLOCKS | grep Graphics | head -1 | awk '{ print $3 }' | head -1`
    sudo nvidia-smi --mode=1 -lgc $sm_freq
    # Confirm both
    nvidia-smi --query-gpu=index,timestamp,power.max_limit,clocks.sm,clocks.mem,clocks.gr --format=csv
}

DBTAG=$1
SAMPLE=$2
BATCHSIZE=$3
ARCH_GPU=$4
NUM_THREADS=1
ITERATIONS=1
TOOL=MMSEQS-UNGAPPED-${ARCH_GPU}

WORKSPACE="/home/achacon/scratch.achacon_gpu/ACHACON/MSA_BENCH_MMSEQS_PAPER"
TMP_WORKSPACE="/tmp/achacon/"

QUERY_NAME=${SAMPLE}_sampled_query.fasta
QUERY_INPUT=${WORKSPACE}/data/${QUERY_NAME}
DB=${WORKSPACE}/data/${DBTAG}.targetdb.fasta

TAG=${DBTAG}.${TOOL}.IT-${ITERATIONS}.S-${SAMPLE}.B-${BATCHSIZE}
BENCHDIR=${TMP_WORKSPACE}/tmp/${TAG}

nvidia-smi
export CUDA_VISIBLE_DEVICES=0
_gpu_configure

rm -rf ${BENCHDIR}
mkdir -p ${TMP_WORKSPACE}
mkdir -p ${BENCHDIR}
cp ${QUERY_INPUT} ${BENCHDIR}

mkdir -p ${WORKSPACE}/logs
rm -f ${WORKSPACE}/logs/${TAG}.time.log

${WORKSPACE}/bin/seqkit split ${BENCHDIR}/${QUERY_NAME} -s "$BATCHSIZE"

mkdir ${BENCHDIR}/tmp
### MMseqs2 ungapped gpu: uses same db as CPU
${WORKSPACE}/bin/mmseqs-${ARCH_GPU} createdb $DB ${BENCHDIR}/tmp/targetdb
${WORKSPACE}/bin/mmseqs-${ARCH_GPU} makepaddedseqdb ${BENCHDIR}/tmp/targetdb /dev/shm/targetdb_mask_pad --mask 1
${WORKSPACE}/bin/mmseqs-${ARCH_GPU} createindex /dev/shm/targetdb_mask_pad tmp --split 0 --index-subset 2
### MMseqs2 ungapped gpu: uses same db as CPU
${WORKSPACE}/bin/mmseqs-${ARCH_GPU} gpuserver /dev/shm/targetdb_mask_pad.idx --max-seqs 4000 --db-load-mode 0 --prefilter-mode 3 &
PID=$!
sleep 60
for QUERYBATCH in ${BENCHDIR}/${QUERY_NAME}.split/*; do
	start_time=$(date +%s%3N)
	${WORKSPACE}/bin/mmseqs-${ARCH_GPU} easy-search "${QUERYBATCH}" /dev/shm/targetdb_mask_pad ${BENCHDIR}/${TAG}.aln ${BENCHDIR}/${TAG}.tmp --max-seqs 4000 --threads ${NUM_THREADS} --prefilter-mode 3 -e 10000 --gpu 1 --gpu-server 1 --db-load-mode 2
	end_time=$(date +%s%3N)
	elapsed_time=$(($end_time - $start_time))
	QUERYBATCH_NAME=$(echo "$QUERYBATCH" | sed "s/.*\///")
	echo "$QUERYBATCH_NAME: $elapsed_time" >> ${WORKSPACE}/logs/${TAG}.time.log
done
kill $PID
rm -rf /dev/shm/targetdb* ${BENCHDIR}/tmp/targetdb*
rm -rf ${BENCHDIR}