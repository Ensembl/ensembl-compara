#!/bin/sh

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Utility script to generate the appropriate commands for solr replication 
# Arguments: 
  # -s: www | grch37 (to know which machines)
  # -t: test | before | after (stage of the release: setup test, one day before release, after release)
  # user input: for 37 only - is there new data (yes or no)

while getopts s:t: option
do
  case "${option}" in
    s) site=${OPTARG};;
    t) stage=${OPTARG};;
  esac
done

currentrelease="$(curl 'http://rest.ensembl.org/info/software' -H 'Content-type:application/json' -s | sed -e's/{"release":\(.*\)}/\1/')"
if [[ $stage == "after" ]] ; then
  release=$currentrelease
else
  release=$(($currentrelease+1))
fi

if ! [[ $release =~ ^[0-9]+$ ]] ; then
  echo "Couldn't retrieve release version, something might be wrong with rest call: http://rest.ensembl.org/info/software !!!"
  exit 1;
fi

if [[ $(( $release % 2 )) == 0 ]] ; then
  release_type="even"
  replicate_release_type="even" #this is used for the replication which is different for before/after release
  release_port="8000"
else
  release_type="odd"
  replicate_release_type="odd"
  release_port="9000"
fi

#read -p 'Is it for www or grch37 [www/grch37]: ' site
if [[ $site != "www" && $site != "grch37" ]] ; then
  echo "Invalid entry!! Please enter either www or grch37"
  exit 1;
fi

if [[ $site == "grch37" ]] ; then
  read -p 'Is there new data for the release?[y/n]: ' new_data
  if [[ $new_data != "y" && $new_data != "n" ]] ; then
    echo "Invalid entry!! Please enter either y or n"
    exit 1;
  fi
fi

if [[ $site == "www" ]] ; then
  new_data="y" #there is always new data for www
fi


#read -p 'Is it for test or one day before release or after release [test/before/after]: ' stage
if [[ $stage != "before" && $stage != "after" && $stage != "test" ]] ; then
  echo "Invalid entry!! Please enter either test or before or after"
  exit 1;
fi

uppersite=${site^^}
if [[ $stage == "before" ]] ; then
  upperstage="ONE DAY BEFORE"
else
  upperstage=${stage^^}
fi

echo -e '\n'
read -p "Show commands to run for $uppersite solr replication $upperstage RELEASE $release [y/n]: " confirm
if [[ $confirm != "y" ]] ; then
  echo "Exiting !!!"
  exit 1;
fi

# setting up a hash for www and grch37 solr machines (obtained from https://www.ebi.ac.uk/seqdb/confluence/display/ENSWEB/Solr)
# key = combination of -s and -t ($site_$stage)
declare -A machines
machines[grch37_test]="wp-p2m-2f"
machines[grch37_before]="wp-p2m-26"
machines[grch37_after]="wp-p1m-74:wp-p1m-95"
machines[www_test]="wp-p2m-95"
machines[www_before]="wp-p2m-96:wp-p2m-97"
machines[www_after]="wp-p1m2-59:wp-p1m2-5a:wp-p1m2-5b:wp-p1m2-5c"

key="${site}_${stage}"

#split machines on ':' to get an array
machines_array=(`echo ${machines[$key]} | tr ':' ' '`)

step=0

for server in "${machines_array[@]}"
do
  if [[ $stage != "after" ]] ; then
    # Mute oh for these machines, only need to do this for test and before release.
    echo -e "\n$((step+=1)). Mute oh for $server."
    echo -e "\t ssh ens_adm02@ves-hx2-70"
    echo -e "\t oh mute-for check@$server 3w"
    echo -e "\t check that it is showing muted on http://useast.ensembl.org:8000/oh.html"
    
    # before release we do stop both kicker and solr-java at the start
    echo -e "\n$((step+=1)). Configure $server, this involves changing the port the server is running on 8000 and 9000 for each even and odd release."
    echo -e "\t ssh -i ~/.ssh/users/tc_ens02 tc_ens02@$server"
    echo -e "\t #Make sure kicker is disabled and stop solr"
    echo -e "\t op stop kicker"
    echo -e "\t op stop solr-java"
    echo -e "\t make sure solr-java is still not running by doing a ps aux | grep java, if it is kill the process"
    echo -e "\t op summary #to confirm kicker and solr-java are stopped"
  else
    # for post release we only disable kicker
    echo -en "\n$((step+=1)). Disable kicker "
    if [[ $site != "grch37" ]]; then echo -n "and remove indexes "; fi
    echo -e "on $server"
    echo -e "\t ssh ens_adm02@ves-hx2-70"
    echo -e "\t ssh -i ~/.ssh/users/tc_ens02 tc_ens02@$server"
    echo -e "\t op stop kicker"
    echo -e "\t op summary #to confirm kicker is stopped"
    if [[ $site == "grch37" ]]; then echo -e "\t exit;"; fi
  fi

  # we dont need to remove previous indexes for 37 as there is enough spaces
  if [[ $site != "grch37" ]] ; then
    echo -e "\n\t #Remove the index files from previous release to make sure there's enough disc space"
    echo -e "\t cd /data/solr-data"
    echo -e "\t rm -rf * #(If you want to replicate just one shard, say core, you delete only that folder)"
    echo -e "\n\t #Restart Solr to clear the indexes"
    echo -e "\t op stop solr-java"
    echo -e "\t op summary #to confirm solr-java is stopped"
    echo -e "\t #Make sure solr-java is still not running by doing 'ps aux | grep java'. If it is, kill the process."
    echo -e "\t op start solr-java"
    echo -e "\t exit;"
  fi

  # for post release, we need to replicate data first and then switch port at the end
  if [[ $stage != "after" || $new_data != 'y' ]] ; then
    echo -e "\n\t #Edit the controller script and ports for sharding (as ens_adm02)."
    echo -e "\t ssh ens_adm02@$server"
    echo -e "\t cd /data"

    if [[ $release_type == "even" ]] ; then
      echo -e "\t sed -i -e 's/BASE_PORT=900/BASE_PORT=800/g' controller"
      echo -e "\t cd /data/solr-conf/"
      echo -e "\t find . -name solrcore.properties -print0 | xargs -0 -n 1 sed -i -e 's/localhost:9000/localhost:8000/g'"
    else
      echo -e "\t sed -i -e 's/BASE_PORT=800/BASE_PORT=900/g' controller"
      echo -e "\t cd /data/solr-conf/"
      echo -e "\t find . -name solrcore.properties -print0 | xargs -0 -n 1 sed -i -e 's/localhost:8000/localhost:9000/g'"
    fi

    echo -e "\t exit;"
  fi

  if [[ $stage != "after" ]] ;  then
    echo -e "\n\t #Start solr, take about 2mins"
    echo -e "\t ssh  -i ~/.ssh/users/tc_ens02 tc_ens02@$server"
    echo -e "\t op start solr-java"
    echo -e "\t op start kicker"
    echo -e "\t Check a query works: http://${server}:$release_port/solr-sanger/ensembl_core/ensemblshards?indent=on&version=2.2&q=brca2"
    echo -e "\t exit;"
  fi

  if [[ $new_data == "n" && $stage == "after" ]] ; then
    echo -e "\t ssh -i ~/.ssh/users/tc_ens02 tc_ens02@$server"
    echo -e "\t op stop solr-java"
    echo -e "\t make sure solr-java is still not running by doing a ps aux | grep java, if it is kill the process"
    echo -e "\t op summary #to confirm kicker and solr-java are stopped"
    echo -e "\t op start solr-java"
    echo -e "\t op start kicker"
    echo -e "\t wait for 2 mins and check a query works: http://${server}:$release_port/solr-sanger/ensembl_core/ensemblshards?indent=on&version=2.2&q=brca2"
    echo -e "\t exit;"
  fi
done

if [[ $new_data == "y" ]] ; then
# for post release the release type is opposite as you are replicating to the server still running on the old port
  if [[ $stage == "after" ]] ; then    
    if [[ $release_type == "even" ]]; then replicate_release_type="odd"; else replicate_release_type="even"; fi
  fi;

  if [[ $site == "grch37" ]]; then generate_site=$site; else generate_site="ebi"; fi

  echo -e "\n $((step+=1)). Replicate data using a script."
  echo -e "\t ssh ens_adm02@ves-hx2-70"
  echo -e "\n\t NOTE: Run below in a screen session (screen -S solr-replication)"
  echo -e "\t cd /nfs/public/release/ensweb-software/ensembl-solr/sync"
  echo -e "\t #dry run - should only recognise the servers [${machines_array[@]}] showing message 'NEEDSYNCH'"
  echo -e "\t ./sync_indexes.pl -reltype ebi-$replicate_release_type --maxshards 3 --dry"
  echo -e "\t #for real"
  echo -e "\t  ./sync_indexes.pl -reltype ebi-$replicate_release_type --maxshards 3 \n"
#TODO: ask whether they want to sync all or by shard or by host and generate appropriate command
  echo -e "\t #IF NEEDED: You can also sync to individual server by prepending the host name, eg"
  echo -e "\t ./sync_indexes.pl -reltype ebi-$replicate_release_type --maxshards 3 -host ${machines_array[0]}"
  echo -e "\t #IF NEEDED: You can also sync to individual server by prepending the host name and to individual shared by prepending the shards"
  echo -e "\t ./sync_indexes.pl -reltype ebi-$replicate_release_type --maxshards 3 -host ${machines_array[0]} --shards ensembl_core"
  echo -e "\n $((step+=1)). Generate the dictionary indexes. Running the queries needed for this can identify problems with replication."
  echo -e "   If any of them fail you will need to take action (retry the query in a web browser, speak to Steve)."
  echo -e "\t /nfs/public/release/ensweb-software/ensembl-solr/build/make_dictionaries.pl -reltype $generate_site-$replicate_release_type [-dry]"

  # for post release, we need to replicate data first and then switch port at the end
  if [[ $stage == "after" && $new_data != 'n' ]] ; then
    for server in "${machines_array[@]}"
    do
      echo -e "\n $((step+=1)). Switch ports for $server - Edit the controller script."
      echo -e "\t ssh -i ~/.ssh/users/tc_ens02 tc_ens02@$server"
      echo -e "\t cd /data"

      if [[ $release_type == "even" ]] ; then
        echo -e "\t sed -i -e 's/BASE_PORT=900/BASE_PORT=800/g' controller"
        echo -e "\t cd /data/solr-conf/"
        echo -e "\t find . -name solrcore.properties -print0 | xargs -0 -n 1 sed -i -e 's/localhost:9000/localhost:8000/g'"
      else
        echo -e "\t sed -i -e 's/BASE_PORT=800/BASE_PORT=900/g' controller"
        echo -e "\t cd /data/solr-conf/"
        echo -e "\t find . -name solrcore.properties -print0 | xargs -0 -n 1 sed -i -e 's/localhost:8000/localhost:9000/g'"
      fi

      echo -e "\t exit;"
    done
  fi

  
  for server in "${machines_array[@]}"
  do
    echo -e "\n $((step+=1)). Reenable kicker on $server"
    echo -e "\t ssh -i ~/.ssh/users/tc_ens02 tc_ens02@$server"

    if [[ $stage == "after" && $new_data != 'n' ]] ; then
      echo -e "\t op stop solr-java"
      echo -e "\t VIP NOTE: make sure solr-java is still not running by doing a ps aux | grep java, if it is kill the process"
      echo -e "\t op summary #to confirm kicker and solr-java are stopped"
      echo -e "\t op start solr-java"
    fi
    echo -e "\t op start kicker"
    echo -e "\t exit;"
    echo -e "\n\t #Wait for 2mins and check the query below works:"
    echo -e "\t http://${server}:$release_port/solr-sanger/ensembl_core/ensemblshards?indent=on&version=2.2&q=brca2"
  done
fi

# updating oh for changes in solr port - can only be done one day before release for the HX servers and after release for HH servers (we will still get oh alerts for the test machines)
if [[ $stage == "after" || $stage == "before" ]] ; then
  if [[ $stage == "before" ]] ; then
    solr_group="hx-host-solr"
    #unmute oh for all the machines (dont forget the test machines as well)
    echo -e "\n $((step+=1)). UnMute Oh for: ${machines_array[@]} ${machines[${site}_test]}"
    echo -e "\t ssh ens_adm02@ves-hx2-70"
    echo -e "\t oh unmute check@${machines[${site}_test]}"
    for server in "${machines_array[@]}"
    do
      echo -e "\t oh unmute check@$server"
    done
  else 
    solr_group="hh-host-solr"
  fi
  echo -e "\n $((step+=1)). Update Oh for changes to ports for Solr machines"
  echo -e "\t ssh ens_adm02@ves-hx2-70"
  echo -e "\t vim /nfs/services/ensweb/webteam-utils/config/metagen/config/config-hosts.yaml"
  echo -e "\t search for $solr_group and change solr-port keys to $release_port"
  echo -e "\t regenerate (please 1007)"
  echo -e "\t snapshot (please 1124)"
fi
