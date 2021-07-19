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

use strict;
use warnings;

use FindBin qw($Bin);
use File::Basename qw( dirname );

# --- load libraries needed for reading config ---
use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs; SiteDefs->import; };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use Storable;
use Bio::Tools::Run::Search;
use Bio::Search::Result::EnsemblResult;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::SpeciesDefs;

my $token    = shift @ARGV;
my $filename = shift @ARGV;
(my $FN2 = $filename) =~ s/parsing/done/;
(my $FN3 = $filename) =~ s/parsing/error/;
if( ! $token ){ die( "runblast.pl called with no token" ) }
my @bits = split( '/', $token );
my $ticket = join( '',$bits[-3],$bits[-2] ); # Ticket = 3rd + 2nd to last dirs

# Retrieve the runnable object
my $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new();
my $DBCONNECTION = EnsEMBL::Web::DBSQL::DBConnection->new( undef, $SPECIES_DEFS );

my $blast_adaptor = $DBCONNECTION->get_databases_species( $SPECIES_DEFS->ENSEMBL_PRIMARY_SPECIES, 'blast')->{'blast'};
$blast_adaptor->{'disconnect_flag'} = 0;
$blast_adaptor->ticket( $ticket );

my $runnable = eval { Bio::Tools::Run::Search->retrieve( $token, $blast_adaptor  ) };

if( ! $runnable ){ 
  warn "Renaming $filename -> $FN3";
  rename $filename, $FN3;
  open O, ">>$FN3";
  print O $@;
  close O;
  die( "Token $token not found" );
}
$runnable->verbose(1);

eval{
  # Initialise
  my $species = $runnable->result->database_species();
  my $ensembl_adaptor = $DBCONNECTION->get_DBAdaptor( 'core', $species );
  warn $runnable;
  $runnable->result->core_adaptor( $ensembl_adaptor );
  
  # Do the job
  $runnable->parse( "$token.out" );
  $runnable->status("COMPLETED");
  $runnable->store;
};
if( $@ ){
  warn "Renaming $filename -> $FN3";
  rename $filename, $FN3;
  open O, ">>$FN3";
  print O $@;
  close O;
  die $@;
} else {
  warn "Renaming $filename -> $FN2";
  rename $filename, $FN2;
}
exit 0;
