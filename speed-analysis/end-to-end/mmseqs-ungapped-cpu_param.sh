#!/bin/sh -ex

DBTAG=$1
SAMPLE=$2
BATCHSIZE=$3
ITERATIONS=1
TOOL=MMSEQS-UNGAPPED-CPU

WORKSPACE="/home/achacon/scratch.achacon_gpu/ACHACON/MSA_BENCH_MMSEQS_PAPER"
TMP_WORKSPACE="/tmp/achacon/"

QUERY_NAME=${SAMPLE}_sampled_query.fasta
QUERY_INPUT=${WORKSPACE}/data/${QUERY_NAME}
DB=${WORKSPACE}/data/${DBTAG}.targetdb.fasta

TAG=${DBTAG}.${TOOL}.IT-${ITERATIONS}.S-${SAMPLE}.B-${BATCHSIZE}
BENCHDIR=${TMP_WORKSPACE}/tmp/${TAG}

rm -rf ${BENCHDIR}
mkdir -p ${TMP_WORKSPACE}
mkdir -p ${BENCHDIR}
cp ${QUERY_INPUT} ${BENCHDIR}

mkdir -p ${WORKSPACE}/logs
rm -f ${WORKSPACE}/logs/${TAG}.time.log

${WORKSPACE}/bin/seqkit split ${BENCHDIR}/${QUERY_NAME} -s "$BATCHSIZE"

### MMSEQS-UNGAPPED-CPU
mkdir ${BENCHDIR}/tmp

${WORKSPACE}/bin/mmseqs-cpu createdb $DB ${BENCHDIR}/tmp/targetdb
${WORKSPACE}/bin/mmseqs-cpu makepaddedseqdb ${BENCHDIR}/tmp/targetdb /dev/shm/targetdb_mask_pad --mask 1
${WORKSPACE}/bin/mmseqs-cpu createindex /dev/shm/targetdb_mask_pad tmp --split 0 --index-subset 2

for QUERYBATCH in ${BENCHDIR}/${QUERY_NAME}.split/*; do
	start_time=$(date +%s%3N)
	${WORKSPACE}/bin/mmseqs-cpu easy-search "${QUERYBATCH}" /dev/shm/targetdb_mask_pad ${BENCHDIR}/${TAG}.aln ${BENCHDIR}/tmp --max-seqs 4000 --threads 128 --prefilter-mode 1 -e 10000 --db-load-mode 2
	end_time=$(date +%s%3N)
	elapsed_time=$(($end_time - $start_time))
	QUERYBATCH_NAME=$(echo "$QUERYBATCH" | sed "s/.*\///")
	echo "$QUERYBATCH_NAME: $elapsed_time" >> ${WORKSPACE}/logs/${TAG}.time.log
done
rm -rf /dev/shm/targetdb* ${BENCHDIR}/tmp/targetdb*
rm -rf ${BENCHDIR}
