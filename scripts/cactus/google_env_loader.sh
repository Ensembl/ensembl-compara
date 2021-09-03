#!/usr/bin/env bash

# ----  Function to wait the GPU to be loaded ----
check_gpu(){
  start_time=$SECONDS
  stop_condition=600 #seconds
  status=1
 
  while [ $status -ne 0 ]; do
    nvidia-smi &>/dev/null
    status=$?
 
    # GPU loaded =)
    [ $status -eq 0  ] && break
 
    elapsed=$(get_elapsed_time $start_time)
 
    # GPU not loaded until now =/
    [ $elapsed -gt $stop_condition  ] && break
 
    sleep 10
  done
 
}
 
# ---- the following is for Cactus ----
 
# load singularity module
module load singularity/3.6.4
 
# Docker Image for "normal" Cactus (without-gpu binaries)
export CACTUS_IMAGE="/apps/cactus/images/cactus.sif"
 
# Docker Image for Cactus with GPU binaries
export CACTUS_GPU_IMAGE="/apps/cactus/images/cactus-gpu.sif"
 
# Create local folder to add some binaries
LOCAL_SCRIPTS="$HOME/.local/scripts"
[ -d $LOCAL_SCRIPTS ] || mkdir -p $LOCAL_SCRIPTS
 
# Download scripts
URL="https://raw.githubusercontent.com/thiagogenez/ensembl-compara/feature/cactus_scripts/scripts/cactus"
CACTUS_SCRIPTS=(cactus_tree_prepare.py cactus_parser.py)
for i in ${CACTUS_SCRIPTS[@]}; do
	wget --quiet $URL/$i -O $LOCAL_SCRIPTS/$i
	chmod +x $LOCAL_SCRIPTS/$i
done 

#UPDATE PATH
export PATH=${LOCAL_SCRIPTS}:$PATH
 
# if this is a GPU-enable node, forcing the bash to stop until GPUs are loaded
if [[ -d /usr/local/cuda/ ]]; then
  status=$(check_gpu)
fi
