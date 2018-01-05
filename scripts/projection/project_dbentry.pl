# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

use Getopt::Long;
use Pod::Usage;

use Bio::EnsEMBL::Compara::Production::Projection::RunnableDB::ProjectOntologyXref;
use Bio::EnsEMBL::Compara::Production::Projection::RunnableDB::RunnableLogger;  
use Bio::EnsEMBL::Registry;

my $log_config = <<LOGCFG;
log4perl.logger=DEBUG, Screen
log4perl.appender.Screen=Log::Log4perl::Appender::Screen
log4perl.appender.Screen.stderr=1
log4perl.appender.Screen.Threshold=DEBUG
log4perl.appender.Screen.layout=Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern=%d %p> %M{2}::%L - %m%n
LOGCFG

my @options = qw( 
  source=s 
  target=s 
  engine=s 
  compara=s 
  source_name=s
  write_to_db 
  display_xrefs
  all_sources
  one_to_many
  dbentry_type=s@
  file=s 
  registry=s 
  log_cfg=s
  verbose help man 
);

#The only thing we run in global
run();
#End of the script

sub run {
  my $opts = _get_opts();
  _initalise_log($opts);
  my $runnable = _build_runnable($opts);
  $runnable->run_without_hive();
  return;
}

sub _get_opts {
  my $opts = {};
  GetOptions($opts, @options) or pod2usage(1);
  pod2usage( -exitstatus => 0, -verbose => 1 ) if $opts->{help};
  pod2usage( -exitstatus => 0, -verbose => 2 ) if $opts->{man};
  
  #Source & target check
  _exit('No -source option given', 1, 1) if ! $opts->{source};
  _exit('No -target option given', 1, 1) if ! $opts->{target};
  _exit('No -compara option given', 1, 1) if ! $opts->{compara};
  
  #Registry work
  my $reg = $opts->{registry};
  _exit('No -registry option given', 2, 1) if ! $reg && ! -f $reg;
  my @args = ($reg);
  push @args, 1 if $opts->{verbose};
  Bio::EnsEMBL::Registry->load_all(@args);
  
  #Engine work
  if(! $opts->{engine}) {
    my $base = 'Bio::EnsEMBL::Compara::Production::Projection::';
    if($opts->{display_xrefs}) {
      $opts->{engine} = $base.'DisplayXrefProjectionEngine';
    }
    else {
      $opts->{engine} = $base.'GOAProjectionEngine';
    }
  }
  
  if(! $opts->{write_to_db} && ! $opts->{file}) {
    _exit('-write_to_db and -file were not specified. We need one', 3, 1);
  }
	
  return $opts;
}

sub _build_runnable {
  my ($opts) = @_;
  my %args = (
    -PROJECTION_ENGINE => _build_engine($opts),
    -TARGET_GENOME_DB => _get_genome_db($opts, $opts->{target}),
    -DEBUG => $opts->{verbose}
  );
  $args{-FILE} = $opts->{file} if $opts->{file};
  $args{-WRITE_DBA} = _get_adaptor($opts->{target}, 'core') if $opts->{write_to_db};
  return Bio::EnsEMBL::Compara::Production::Projection::RunnableDB::ProjectOntologyXref->new_without_hive(%args);
}

sub _build_engine {
  my ($opts) = @_;
  my $mod = $opts->{engine};
  _runtime_import($mod, 1);
  my %args = (
    -GENOME_DB => _get_genome_db($opts, $opts->{source}),
    -DBA => _get_adaptor($opts->{compara}, 'compara'),
    _log()
  );
  $args{-ALL_SOURCES} = 1 if $opts->{all_sources};
  $args{-ONE_TO_MANY} = 1 if $opts->{one_to_many};
  $args{-DBENTRY_TYPES} = $opts->{dbentry_type} if $opts->{dbentry_type};
  $args{-SOURCE}      = $opts->{source_name} if $opts->{source_name};
  return $mod->new(%args);
}

sub _get_genome_db {
  my ($opts, $name) = @_;
  my $compara_dba = _get_adaptor($opts->{compara}, 'compara');
  my $core_dba = _get_adaptor($name, 'core');
  my $gdb_a = $compara_dba->get_GenomeDBAdaptor();
  my $gdb = $gdb_a->fetch_by_core_DBAdaptor($core_dba);

  return $gdb;
}

sub _get_adaptor {
  my ($name, $group) = @_;
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($name, $group);
  if(! defined $dba) {
    _exit("No adaptor for ${name} and ${group}. Check your registry and try again", 5, 1);
  }
  return $dba;
}

sub _exit {
  my ($msg, $status, $verbose) = @_;
  print STDERR $msg, "\n";
  pod2usage( -exitstatus => $status, -verbose => $verbose);
}

my $log4perl_available = 0;

sub _initalise_log {
  my ($opts) = @_;
  if(_runtime_import('Log::Log4perl')) {
    if($opts->{log_cfg}) {
      Log::Log4perl->init($opts->{log_cfg});
    }
    else {
      Log::Log4perl->init(\$log_config);
    }
    $log4perl_available = 1;
  }
}

#If log4perl was available let the module get it's own logger otherwise we 
#build our own
sub _log {
  my ($opts) = @_;
  if($log4perl_available) {
    return;
  }
  my $log = Bio::EnsEMBL::Compara::Production::Projection::RunnableDB::RunnableLogger->new(
    -DEBUG => $opts->{verbose}
  );
  return ( -LOG => $log );
}

sub _runtime_import {
  my ($mod, $die) = @_;
  eval "require ${mod}";
  _exit "Cannot import ${mod}: $@", 5, 1 if $die && $@;
  return ($@) ? 0 : 1;
}

__END__
=pod

=head1 NAME

project_dbentry.pl

=head1 SYNOPSIS

  ./project_dbentry.pl -registry REG -source SRC -target TRG -compara COM [-log_cfg LOC] -display_xrefs] [-engine ENG] [-write_to_db] [-file FILE] [-verbose] [-help | -man]

=head1 DESCRIPTION

This script is a thin-wrapper around the RunnableDB instance and is used
for the ad-hoc testing & running of the Xref projection engine. At the moment
this is configured for projecting GO terms from one species to another
however it will operate on any Xref so long as you can provide the correct
projection engine implementation.

The script can also add data back into a database but to do so we must
assume that a core DBAdaptor for the target species is linked to 
a read/write account. Otherwise you will not be able to perform the 
linkage.

For a flavor of what the pipeline can do pass the script a file name which
will produce a CSV of what I<would> have been written back to the DB.

=head1 OPTIONS

=over 8

=item B<--registry>

The registry to use

=item B<--source>

The source species (species with GOs)

=item B<--target>

The target species (species without GOs)

=item B<--compara>

The compara database to use

=item B<--log_cfg>

The log4perl configuration location; otherwise the code will use a default
logger to STDERR

=item B<--source_name>

Optional argument allowing the specification of the level to perform 
projections at. This means if we wish to project from Gene to Gene you can
specify ENSEMBLGENE (these are the same names as used in MEMBER). The default
is ENSEMBLPEP and is the recommended mode.

=item B<--engine>

The engine to use; defaults to GOAProjectionEngine or 
DisplayXrefProjectionEngine. Must be a fully qualified package

=item B<--display_xrefs>

Flags we wish to project display Xrefs

=item B<--all_sources>

Allow the input of any sources of information - only relevant for display xrefs

=item B<--one_to_many>

Bring in 1:m relationships rather than just 1:1 - only relevant for display xrefs

=item B<--dbentry_type>

External DB name(s) of Xrefs we wish to consider for GO projection. Can specify
multiple --dbentry_type

=item B<--write_to_db>

Indicates we want Xrefs going back to the core DB. If used we assume the 
registry's core DBAdaptor is writable

=item B<--file>

Location to write output to. Can be a directory (so an automatically 
generated name will be given) or a full path. Specifying B<-> will write the
file out to STDOUT.

=item B<--verbose>

Start emitting more messages

=item B<--help>

Basic help with options

=item B<--man>

Manual version of the help. More complete 

=back

=head1 REQUIREMENTS

=over 8

=item EnsEMBL core (v60+)

=item EnsEMBL compara

=item EnsEMBL hive

=item Log::Log4perl - if not present on PERL5LIB or @INC messages go to STDOUT

=item Text::CSV (for file writing)

=item Data::Predicate 

=back

=cut
