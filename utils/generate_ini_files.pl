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

# Script to generate one or more basic ini files for individual species
# Default output directory is .

use strict;
use Getopt::Long;

## EDIT THIS LIST WITH YOUR SPECIES PRODUCTION NAMES 
## All lowercase with underscores, e.g. tyrannosaurus_rex
my @new_species = qw(
);

my $dir;

BEGIN{
  &GetOptions('dir'  => \$dir);
}

$dir ||= '.';
print "Outputting ini files to $dir\n";

foreach (@new_species) {
  my $content   = _generate_content($_); 
  my $path      = $dir.'/' if $dir;
  $path        .= $_.'.ini';

  open(my $fh, '>', $path) or die "Could not open file '$path' $!";
  print $fh $content;;
  close $fh;
}

## INI FILE TEMPLATE - ONLY EDIT IF THERE ARE SIGNIFICANT CHANGES

sub _generate_content {
  my $prod_name = shift;

  my $output = qq(###############################################################################
#   
#   Description:    Configuration file for species );
 
  $output .= $prod_name;

  $output .= qq(
#   
#
###############################################################################

#################
# GENERAL CONFIG
#################
[general]

# Database info: only specify values if different from those in DEFAULTS

SPECIES_RELEASE_VERSION = 1

####################
# Species-specific colours
####################

[ENSEMBL_STYLE]

[ENSEMBL_COLOURS]
# Accept defaults


####################
# External Database ad Indexer Config
####################
[ENSEMBL_EXTERNAL_DATABASES]
# Accept defaults

[ENSEMBL_EXTERNAL_INDEXERS]
# Accept defaults


####################
# Configure External Genome Browsers
####################

[EXTERNAL_GENOME_BROWSERS]
# None

####################
# Configure External URLs
# These are mainly for (1) External Genome Browse  {EGB_ }
#                      (2) DAS tracks              {DAS_ }
####################

[ENSEMBL_EXTERNAL_URLS]
# Accept defaults

####################
# Configure search example links
####################


[ENSEMBL_DICTIONARY]

[SAMPLE_DATA]

LOCATION_PARAM    = 
LOCATION_TEXT     = 

GENE_PARAM        = 
GENE_TEXT         = 

TRANSCRIPT_PARAM  = 
TRANSCRIPT_TEXT   = 

SEARCH_TEXT       = 
);

}

