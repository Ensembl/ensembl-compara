#!/usr/local/bin/perl

use strict;
use warnings;
use Storable;

use FindBin qw($Bin);
use File::Basename qw( dirname );
use File::Find;

# --- load libraries needed for reading config ---
use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::SpeciesDefs;
my $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new();

#---- load plugins ---
# Ensure that plugins are loaded before running the BLAST
# This code copied from conf/perl.startup.pl
my ($i, @plugins, @plugin_dirs);
my @lib_dirs = @{$SPECIES_DEFS->ENSEMBL_LIB_DIRS};

for (reverse @{$SPECIES_DEFS->ENSEMBL_PLUGINS||[]}) {
  if (++$i % 2) {
    push @plugin_dirs, "$_/modules" if -e "$_/modules";
  } else {
    unshift @plugins, $_;
  }
}

unshift @INC, reverse @plugin_dirs; # Add plugin directories to INC so that EnsEMBL::PLUGIN modules can be used

find(\&load_plugins, @plugin_dirs);

# Loop through the plugin directories, requiring .pm files
# The effect of this is that any plugin with an EnsEMBL::Web:: namespace is used to extend that module in the core directory
# Functions that exist in both the core and the plugin will be overwritten, functions that exist only in the plugin will be added
sub load_plugins {
  if (/\.pm$/ && !/MetaDataBlast\.pm/) {
    my $dir  = $File::Find::topdir;
    my $file = $File::Find::name;
    
    (my $relative_file = $file) =~ s/^$dir\///;    
    (my $package = $relative_file) =~ s/\//::/g;
    $package =~ s/\.pm$//g;
    
    # Regex matches all namespaces which are EnsEMBL:: but not EnsEMBL::Web
    # Therefore the if statement is true for EnsEMBL::Web:: and Bio:: packages, which are the ones we need to overload
    if ($package !~ /^EnsEMBL::(?!Web)/) {      
      no strict 'refs';
      
      # Require the base module first, unless it already exists
      if (!exists ${"$package\::"}{'ISA'}) {
        foreach (@lib_dirs) {
          eval "require '$_/$relative_file'";
          warn $@ if $@ && $@ !~ /^Can't locate/;
          last if exists ${"$package\::"}{'ISA'};
        }
      }
      
      eval "require '$file'"; # Require the plugin module
      warn $@ if $@;
    }
  }
}
#--- finished loading plugins ---

use Bio::Tools::Run::Search;
use Bio::Search::Result::EnsemblResult;
use EnsEMBL::Web::DBSQL::DBConnection;

my $token = shift @ARGV;
if( ! $token ){ die( "runblast.pl called with no token" ) }
my @bits = split( '/', $token );
my $ticket = join( '',$bits[-3],$bits[-2] ); # Ticket = 3rd + 2nd to last dirs

# Retrieve the runnable object

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
