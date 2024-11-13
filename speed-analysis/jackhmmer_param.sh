#!/bin/sh -ex

DBTAG=$1
SAMPLE=$2
BATCHSIZE=$3
ITERATIONS=1
TOOL=JACKHMMER

WORKSPACE="/home/achacon/scratch.achacon_gpu/ACHACON/MSA_BENCH_MMSEQS_PAPER"
TMP_WORKSPACE="/tmp/achacon/"

QUERY_NAME=${SAMPLE}_sampled_query.fasta
QUERY_INPUT=${WORKSPACE}/data/${QUERY_NAME}
DB=${WORKSPACE}/data/${DBTAG}.targetdb.fasta

TAG=${DBTAG}.${TOOL}.IT-${ITERATIONS}.S-${SAMPLE}.B-${BATCHSIZE}
#QUERY=${WORKSPACE}/${QUERY_NAME}.${BATCHSIZE}.split/
BENCHDIR=${TMP_WORKSPACE}/tmp/${TAG}

rm -rf ${BENCHDIR}
mkdir -p ${TMP_WORKSPACE}
mkdir -p ${BENCHDIR}
cp ${QUERY_INPUT} ${BENCHDIR}

mkdir -p ${WORKSPACE}/logs
rm -f ${WORKSPACE}/logs/${TAG}.time.log

${WORKSPACE}/bin/seqkit split ${BENCHDIR}/${QUERY_NAME} -s "$BATCHSIZE"

### HMMer3
time cp $DB /dev/shm/db30Mio.fas
for QUERYBATCH in ${BENCHDIR}/${QUERY_NAME}.split/*; do
        start_time=$(date +%s%3N)
        ${WORKSPACE}/bin/jackhmmer --cpu 128 -N 1 -E 10000 --noali --tblout ${BENCHDIR}/tblout.hmmer $QUERYBATCH /dev/shm/db30Mio.fas > ${WORKSPACE}/logs/${TAG}.log
        end_time=$(date +%s%3N)
        elapsed_time=$(($end_time - $start_time))
        QUERYBATCH_NAME=$(echo "$QUERYBATCH" | sed "s/.*\///")
        echo "$QUERYBATCH_NAME: $elapsed_time" >> ${WORKSPACE}/logs/${TAG}.time.log
done
rm -rf /dev/shm/db30Mio.fas
rm -rf ${BENCHDIR}
