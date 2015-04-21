#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Data::Dumper;

my $usage = "$0
--help                print this menu
--from_dbname string
--to_dbname string
--reg_conf string
--mlss_id int: the expected mlss_id of the synteny
\n";

my $help = 0;
my ($from_dbname, $to_dbname, $reg_conf, $mlss_id);

GetOptions('help' => \$help,
	   'from_dbname=s' => \$from_dbname,
           'to_dbname=s' => \$to_dbname,
	   'reg_conf=s' => \$reg_conf,
           'mlss_id=i' => \$mlss_id,         
);

$|=1;

if ($help) {
  print $usage;
  exit 0;
}

my($f_mlss_a, $f_synt_a, $t_mlss_a, $t_synt_a, $t_dfr_a, %dbah);

Bio::EnsEMBL::Registry->load_all($reg_conf);

foreach my $dba(@{ Bio::EnsEMBL::Registry->get_all_DBAdaptors }){
 if($dba->dbc->dbname eq $from_dbname){
  $dbah{ "from" } = $dba;
  ($f_synt_a,$f_mlss_a) = get_adaptors($dba);
 } elsif ($dba->dbc->dbname eq $to_dbname){
  $dbah{ "to" } =  $dba;
  ($t_synt_a,$t_mlss_a,$t_dfr_a) = get_adaptors($dba);
 }
}

unless($t_mlss_a->fetch_by_dbID($mlss_id)){
 die "\n**** Can not find mlssid $mlss_id in ", $dbah{ "to" }->dbc->dbname, " ****\n";
}

my $pre = 10000 * $mlss_id; # assume mlss_id for synteny is 5 digits

foreach my$synteny_region(@{ $f_synt_a->fetch_all_by_MethodLinkSpeciesSet($f_mlss_a->fetch_by_dbID($mlss_id)) }){
 my $sy_id = $pre + $synteny_region->dbID;;
 my@dfr;
 foreach my $dnafrag_region(@{ $synteny_region->get_all_DnaFragRegions }){
  $dnafrag_region->synteny_region_id($sy_id);
  push(@dfr, $dnafrag_region);
 }

 $synteny_region->dbID($sy_id);
 my $sth = $dbah{"to"}->dbc->prepare("insert into synteny_region (synteny_region_id, method_link_species_set_id) VALUES (?,?)");
 $sth->execute(int($synteny_region->dbID), $synteny_region->method_link_species_set_id);
 foreach my $dfr(@dfr){ 
  $t_dfr_a->store($dfr);
 }
}


sub get_adaptors{
 my ($dba)=@_;
 return( $dba->get_adaptor("SyntenyRegion"), $dba->get_adaptor("MethodLinkSpeciesSet"), $dba->get_adaptor("DnaFragRegion") );
}

