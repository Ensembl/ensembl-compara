#!/usr/local/bin/perl -w

use strict;
use warnings;
use Carp;
use Data::Dumper qw( Dumper );

use FindBin qw($Bin);
use File::Basename qw( dirname );

use Pod::Usage;
use Getopt::Long;

use vars qw( $ENSEMBL_ROOT );
BEGIN{
  $ENSEMBL_ROOT = dirname( $Bin );
}

use lib "$ENSEMBL_ROOT/conf";
use lib "$ENSEMBL_ROOT/modules";
use lib "$ENSEMBL_ROOT/ensembl/modules";
use lib "$ENSEMBL_ROOT/ensembl-external/modules";
use lib "$ENSEMBL_ROOT/ensembl-compara/modules";
use lib "$ENSEMBL_ROOT/ensembl-variation/modules";
use lib "$ENSEMBL_ROOT/bioperl-live";

use SpeciesDefs;
our $SPECIES_DEFS;
BEGIN{
  local $SIG{__WARN__} = sub{};
  $SPECIES_DEFS = SpeciesDefs->new;
}
$SPECIES_DEFS || pod2usage("$0: SpeciesDefs config not found");

use EnsEMBL::DB::Core;

MAIN:{
  my $blast_adaptor = EnsEMBL::DB::Core->get_blast_database;
  $blast_adaptor->rotate_daily_tables();
  $blast_adaptor->clean_blast_database(7);
}


exit 0;
