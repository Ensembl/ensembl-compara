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

Bio::EnsEMBL::Compara::Production::Projection::Writer::ProjectedDBEntryWriter

=head1 DESCRIPTION

This class will write the results of the given projections to a 
database given at construction.

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: http://lists.ensembl.org/mailman/listinfo/dev

=cut

package Bio::EnsEMBL::Compara::Production::Projection::Writer::ProjectedDBEntryWriter;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use base qw(Bio::EnsEMBL::Compara::Production::Projection::Writer::BaseWriter);

=head2 new()

  Arg[-DBA]       : Bio::EnsEMBL::DBSQL::DBAdaptor; Assumed to be a DBA which 
                    can be written to. Required argument 
  Arg[-ANALYSIS]  : Bio::EnsEMBL::Analysis; analysis used to link DBEntries to
  Returntype      : Bio::EnsEMBL::Compara::Production::Projection::Writer::ProjectedDBEntryWriter
  Description     : New method used for a new instance of the given object. 
                    Required fields are indicated accordingly. Fields are 
                    specified using the Arguments syntax (case insensitive).
  Exceptions      : If the DBAdaptor was not defined 
  Status          : Stable

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);
  my ( $dba, $analysis, ) = rearrange( [qw(dba analysis)], @args );

  assert_ref( $dba, 'Bio::EnsEMBL::DBSQL::DBAdaptor' );
  $self->{dba} = $dba;
  if(defined $analysis) {
    assert_ref( $analysis, 'Bio::EnsEMBL::Analysis' );
    $self->{analysis} = $analysis;
  }

  return $self;
}

=head2 dba()

  Description : Getter. Should be a write enabled connection

=cut

sub dba {
  my ($self) = @_;
  return $self->{dba};
}

=pod

=head2 analysis()

  Description : Getter for the analysis to write  
  Returntype  : Bio::EnsEMBL::Analysis or undef
  Exceptions  : None
  Status      : Stable

=cut

sub analysis {
  my ($self) = @_;
  return $self->{analysis};
}


=head2 write_projection()

Re-assigns the attacted DBEntry from the list of projections to the
core database which was given to this object during construction. This method
also stores the newly assigned DBEntry.

=cut

sub write_projection {
  my ($self, $p) = @_;
  my $db_entry_a = $self->dba()->get_DBEntryAdaptor();
  my $entry = $self->_process_entry($p);
  my ($object, $type) = $self->_to_ensembl_object($p->to());
  $object->add_DBEntry($entry);
  $db_entry_a->store($entry, $object->dbID(), $type, 1);
  return;
}

=head2 _to_ensembl_object()

Maps a member object to its Ensembl core object and returns the expected type
for the DBEntryAdaptor to correctly write the xref back

=cut

sub _to_ensembl_object {
  my ($self, $member) = @_;
  my $source = $member->source_name();
  my $object;
  my $type;
  if($source eq 'ENSEMBLGENE') {
    ($object, $type) = ($member->get_Gene(), 'Gene');
  }
  elsif($source eq 'ENSEMBLTRANS') {
    ($object, $type) = ($member->get_Transcript(), 'Transcript');
  }
  elsif($source eq 'ENSEMBLPEP') {
    ($object, $type) = ($member->get_Translation(), 'Translation');
  }
  else {
    throw "Cannot understand how to write an Xref back for the source type $source";
  }
  return ($object, $type);
}

=head2 _process_entry()

Performs processing which at the moment is concerned with 
processing the Entry if it is an OntologyXref

All entries are setup with a linkage type of IEA, info type of PROJECTION
and a text description showing what species the linkage was from and
the stable ID of the source object.

=cut

sub _process_entry {
  my ($self, $p) = @_;
  my $entry = $p->entry();
  return $entry unless $entry->isa('Bio::EnsEMBL::OntologyXref');
  
  my $from_species = $p->from()->genome_db()->name();
  my $from = $p->from()->stable_id();
  $entry->flush_linkage_types();
  $entry->add_linkage_type("IEA");
  my $txt = "from $from_species";
  $entry->info_type("PROJECTION");
  $entry->info_text($txt);
  $entry->linkage_annotation("from $from_species entry $from");
  $self->_add_analysis($entry);
  return $entry;
}

sub _add_analysis {
  my ($self, $entry) = @_;
  my $a = $self->analysis();
  if(defined $a) {
    $entry->analysis($a);
  }
  return;
}

1;
