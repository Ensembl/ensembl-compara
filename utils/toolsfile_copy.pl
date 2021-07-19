#!/usr/local/bin/perl
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


## Description: script to copy all the tools file for release cycle
## TODO: could .sconf to run script without webcode dependencies (see ENSWEBREL-711 as example)

use strict;
use warnings;
use Carp;

use FindBin qw($Bin);
use File::Basename qw( dirname );

use Getopt::Long;

my ($SERVERROOT, $help, $info, $date);

## In debug mode, select queries will be run but not inserts and updates
my $DEBUG = 0;

BEGIN{
  &GetOptions(
    'info'    => \$info,
    'date=s'  => \$date,
  );

  $SERVERROOT = dirname( $Bin );
  $SERVERROOT =~ s#/utils##;
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs; SiteDefs->import; };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::DBHub;

my $hub = EnsEMBL::Web::DBHub->new;
my $sd  = $hub->species_defs;

my $current_release = $sd->ENSEMBL_VERSION;
my $prev_release    = $current_release - 1;

# blast file copying
my $blast_path       = $SiteDefs::ENSEMBL_NCBIBLAST_DATA_PATH_DNA."/";
my $gene_path        = $SiteDefs::ENSEMBL_NCBIBLAST_DATA_PATH."/";
(my $prev_blast_path = $blast_path) =~ s/$current_release/$prev_release/gi;

warn "\n\n COPYING blast files for ".$SiteDefs::SUBDOMAIN_DIR." release $current_release. Running the following commands: \n\n";

if($SiteDefs::SUBDOMAIN_DIR eq 'grch37') {
  warn "mkdir -p $blast_path \n";
  system("mkdir -p $blast_path");

  warn "mv $prev_blast_path* $blast_path \n";
  system("mv $prev_blast_path* $blast_path");

  warn "ln -s $blast_path* $prev_blast_path. \n";
  system("ln -s $blast_path* $prev_blast_path.");
  
  warn "\n\n COPYING blat files for ".$SiteDefs::SUBDOMAIN_DIR." release $current_release. Running the following commands: \n\n";  
  
  (my $blat_path = $blast_path) =~ s/blast\/dna/blat/gi;
  (my $prev_blat = $blat_path)  =~ s/$current_release/$prev_release/gi;
  
  warn "mkdir -p $blat_path \n";
  system("mkdir -p $blat_path");

  warn "mv $prev_blat* $blat_path \n";
  system("mv $prev_blat* $blat_path");

  warn "ln -s $blat_path* $prev_blat. \n";
  system("ln -s $blat_path* $prev_blat.");  
}