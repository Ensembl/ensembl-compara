#!/usr/local/bin/perl

use strict;
use warnings;
use Storable;

use FindBin qw($Bin);
use File::Basename qw( dirname );

# --- load libraries needed for reading config ---
use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}


use Bio::Tools::Run::Search;
use Bio::Search::Result::EnsemblResult;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::SpeciesDefs;

#warn( "Storable VERSION: $Storable::VERSION\n" );

my $token = shift @ARGV;
if( ! $token ){ die( "runblast.pl called with no token" ) }
my @bits = split( '/', $token );
my $ticket = join( '',$bits[-3],$bits[-2] ); # Ticket = 3rd + 2nd to last dirs

# Retrieve the runnable object
my $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new();
my $DBCONNECTION = EnsEMBL::Web::DBSQL::DBConnection->new( undef, $SPECIES_DEFS );

my $blast_adaptor = $DBCONNECTION->get_databases_species( $SPECIES_DEFS->ENSEMBL_PRIMARY_SPECIES, 'blast')->{'blast'};

$blast_adaptor->ticket( $ticket );

my $runnable = Bio::Tools::Run::Search->retrieve( $token, $blast_adaptor  );

if( ! $runnable ){ die( "Token $token not found" ) }
$runnable->verbose(1);

eval{
  # Initialise
  my $species = $runnable->result->database_species();
  my $ensembl_adaptor = $DBCONNECTION->get_DBAdaptor( 'core', $species );
  $runnable->result->core_adaptor( $ensembl_adaptor );
  # Do the job
  $runnable->run_blast;
  $runnable->store;
};
if( $@ ){ die( $@ ) }

exit 0;
