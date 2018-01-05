=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=pod

=head1 NAME

Bio::EnsEMBL::Compara::Production::ProjectionRunnableDB::ProjectOntologyXref

=head1 DESCRIPTION

This object serves two functions. In the first instance it is a 
RunnableDB instance to be used in a Hive pipeline and therefore 
inherits from Hive's Process object. A second set of methods is provided 
with the suffix C<without_hive> which allows you to use this object 
outside of a Hive pipeline.

The Runnable is here to bring together a ProjectionEngine with the
GenomeDB instances it will work with and have it interact with a 
ProjectionEngine writer (which can be a database or a file). See the
C<fetch_input()> method for information on the parameters the module
responds and to C<new_without_hive()> for information on how to use
the module outside of hive.

=head1 AUTHOR

Andy Yates (ayatesatebiacuk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: http://lists.ensembl.org/mailman/listinfo/dev

=cut

package Bio::EnsEMBL::Compara::Production::Projection::RunnableDB::ProjectOntologyXref;

use strict;
use warnings;

use base qw(
  Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable
);

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref check_ref);

use File::Spec;

use Bio::EnsEMBL::Hive::URLFactory;
use Bio::EnsEMBL::Hive::AnalysisJob;

use Bio::EnsEMBL::Compara::Production::Projection::RunnableDB::RunnableLogger;
use Bio::EnsEMBL::Compara::Production::Projection::Writer::ProjectedDBEntryWriter;
use Bio::EnsEMBL::Compara::Production::Projection::Writer::ProjectedDisplayXrefWriter;
use Bio::EnsEMBL::Compara::Production::Projection::Writer::ProjectedFileWriter;
use Bio::EnsEMBL::Compara::Production::Projection::Writer::MultipleWriter;


#--- Non-hive methods
=head2 new_without_hive()

  Arg [PROJECTION_ENGINE]       : (ProjectionEngine) The projection engine to use to transfer terms 
  Arg [TARGET_GENOME_DB]        : (GenomeDB)  GenomeDB to project terms to
  Arg [WRITE_DBA]               : (DBAdaptor) Required if not given -FILE; used to 
  Arg [FILE]                    : (String) Location of pipeline output; if given a directory it will generate a file name
  
  Example    : See synopsis
  Description: Non-hive version of the object construction to be used with scripts
  Returntype : Bio::EnsEMBL::Compara::Production::Projection::RunnableDB::ProjectOntologyXref
  Exceptions : if PROJECTION_ENGINE was not given and was not a valid object. 
               Also if we had no GenomeDBs given
  Caller     : general

=cut

sub new_without_hive {
  my ($class, @params) = @_;
  
  my $self = bless {}, $class;
  
  my $job = Bio::EnsEMBL::Hive::AnalysisJob->new();
  $self->input_job($job);
  
  my ($projection_engine, $target_genome_db, $write_dba, $file, $debug) = rearrange(
    [qw(projection_engine target_genome_db write_dba file debug)], 
  @params);
  
  throw('-PROJECTION_ENGINE was not defined ') unless defined $projection_engine;
  $self->projection_engine($projection_engine);
  throw('-TARGET_GENOME_DB was not defined ') unless defined $target_genome_db;
  $self->target_genome_db($target_genome_db);
  throw('Need a -FILE or -WRITE_DBA parameter') if ! defined $write_dba && ! defined $file;
  $self->write_dba($write_dba) if defined $write_dba;
  $self->file($file) if defined $file;
    
  return $self;
}

=head2 run_without_hive()

Performs the run() and write_output() calls in one method.

=cut

sub run_without_hive {
  my ($self) = @_;
  $self->run();
  $self->write_output();
  return;
}

=head2 fetch_input()

Expect to see the following params:

=over 8

=item source_genome_db_id - Required GenomeDB ID

=item target_genome_db_id - Required GenomeDB ID

=item projection_engine_class - Required String which is the package of the engine to use

=item method_link - Optional but should be the method_link class of the types of Homologies to get

=item write_to_db - Boolean which if on will start writing results to a core DB

=item core_db - String which should be a URL of the core DB to write to B<IF> the one available via the Registry is read-only

=item write_to_file - Boolean which if on will start writing results to a file

=item file - String indicating a directory to write to (auto generated file name) or a target file name. We do not automatically create directories

=item engine_params - Give optional parameters to the engine if required

=item source - The source of the DBEntries to use; specify the source_name as used in member

=back

=cut

sub fetch_input {
  my ($self) = @_;
  
  my $compara_dba = $self->get_compara_dba();
  my $gdb_a = $compara_dba->get_GenomeDBAdaptor();
  
  throw('No source_genome_db_id given in input') if ! $self->param('source_genome_db_id');
  throw('No target_genome_db_id given in input') if ! $self->param('target_genome_db_id');
  throw('No projection_engine_class given in input') if ! $self->param('projection_engine_class');
  
  #Building the engine
  my $source_gdb = $gdb_a->fetch_by_dbID($self->param('source_genome_db_id'));
  my $log = Bio::EnsEMBL::Compara::Production::Projection::RunnableDB::RunnableLogger->new(-DEBUG => $self->debug());
  
  my $params = { -GENOME_DB => $source_gdb, -DBA => $compara_dba, -LOG => $log };
  $params->{-METHOD_LINK} = $self->param('method_link') if $self->param('method_link');
  $params->{-SOURCE} = $self->param('source') if $self->param('source');
  %{$params} = %{$self->param('engine_params')} if $self->param('engine_params');
  
  my $engine = $self->_build_engine($params);
  $self->projection_engine($engine);
  
  #Working with target GDB
  my $target_genome_db = $gdb_a->fetch_by_dbID($self->param('target_genome_db_id'));
  $self->target_genome_db($target_genome_db);
  
  #Setting up the outputs
  if($self->param('write_to_db')) {
    my $core_db = $self->param('core_db');
    my $adaptor = ($core_db) 
                ? Bio::EnsEMBL::Hive::URLFactory->fetch($core_db) 
                : $target_genome_db->db_adaptor();
    $self->write_dba($adaptor)
  }
  if($self->param('write_to_file')) {
    my $file = $self->param('file');
    throw 'No file param given in input' unless $file;
    $self->file($file);
  }
  
  return 1; 
}

=head2 run()

Gets the engine, runs it & sets the output into projections

=cut

sub run {
  my ($self) = @_;
  my $engine = $self->projection_engine();
  my $projections = $engine->project($self->target_genome_db());
  $self->projections($projections);
  return 1;
}

=head2 write_output()

Takes the output pushed into projections and sends them into the specified
sources according to the options given.

=cut

sub write_output {
  my ($self) = @_;
  $self->_writer()->write();
  return 1;
}

#### Attributes

=head2 projection_engine()

The engine used to transfer terms.

=cut

sub projection_engine {
  my ($self, $projection_engine) = @_;
  if(defined $projection_engine) {
    assert_ref($projection_engine, 'Bio::EnsEMBL::Compara::Production::Projection::ProjectionEngine');
    $self->param('projection_engine', $projection_engine);
  }
  return $self->param('projection_engine');
}

=head2 target_genome_db()

The GenomeDB instance used to project terms to

=cut

sub target_genome_db {
  my ($self, $target_genome_db) = @_;
  if(defined $target_genome_db) {
    assert_ref($target_genome_db, 'Bio::EnsEMBL::Compara::GenomeDB');
    $self->{target_genome_db} = $target_genome_db;
    $self->param('target_genome_db', $target_genome_db);
  }
  $self->param('target_genome_db');
}

=head2 projections()

The projections we have projected; an ArrayRef of Projection objects

=cut

sub projections {
  my ($self, $projections) = @_;
  if(defined $projections && assert_ref($projections, 'ARRAY')) {
    $self->param('projections', $projections);
  }
  $self->param('projections');
}

=head2 _writer()

Returns the writer instance depending on what was given during construction.

=cut

sub _writer {
  my ($self) = @_;
  if(! defined $self->param('writer')) {
    my $projections = $self->projections();
    my $writers = [];
    
    if($self->write_dba()) {
      if(check_ref($self->projection_engine(), 'Bio::EnsEMBL::Compara::Production::Projection::DisplayXrefProjectionEngine')) {
        push(@$writers, Bio::EnsEMBL::Compara::Production::Projection::Writer::ProjectedDisplayXrefWriter->new(
          -PROJECTIONS  => $projections,
          -DBA          => $self->write_dba()
        ));
      }
      else {
        push(@$writers, Bio::EnsEMBL::Compara::Production::Projection::Writer::ProjectedDBEntryWriter->new(
          -PROJECTIONS  => $projections,
          -DBA          => $self->write_dba()
        ));
      }
    }
    if($self->file()) {
      push(@$writers, Bio::EnsEMBL::Compara::Production::Projection::Writer::ProjectedFileWriter->new(
        -PROJECTIONS  => $projections,
        -FILE         => $self->_target_filename()
      ));
    }
    
    if(scalar(@{$writers}) > 1) {
      $self->{writer} = Bio::EnsEMBL::Compara::Production::Projection::Writer::MultipleWriter->new(
        -WRITERS      => $writers,
        -PROJECTIONS  => $projections 
      );
    }
    else {
      $self->param('writer', shift @{$writers});
    }
  }
  
  return $self->param('writer');
}

=head2 write_dba()

A DBAdaptor instance which can write to a core DBAdaptor; assumed to be the
same as the target GenomeDB.

=cut

sub write_dba {
  my ($self, $write_dba) = @_;
  $self->param('write_dba', $write_dba) if defined $write_dba;
  return $self->param('write_dba');
}

=head2 file()

The file or directory to write to.

=cut

sub file {
  my ($self, $file) = @_;
  $self->param('file', $file) if defined $file;
  return $self->param('file');
}

=head2 _target_filename()

If file is a file name we will return that. If it was a directory we will 
return a automatically generated name (sourcename_to_targetname.txt)

=cut

sub _target_filename {
  my ($self) = @_;
  my $file = $self->file();
  if(-d $file) {
    my $source_genome_db = $self->projection_engine()->genome_db();
    my $target_genome_db = $self->target_genome_db();
    my $filename = sprintf('%s_to_%s.txt', $source_genome_db->name(), $target_genome_db->name());
    return File::Spec->catfile($file, $filename);
  }
  else {
    return $file;
  }
}

sub _build_engine {
  my ($self, $args) = @_;
  my $mod = $self->param('projection_engine_class');
  eval 'require '.$mod;
  throw("Cannot bring in the module ${mod}: $@") if $@;
  my $engine = $mod->new(%{$args});
  return $engine;
}

1;
