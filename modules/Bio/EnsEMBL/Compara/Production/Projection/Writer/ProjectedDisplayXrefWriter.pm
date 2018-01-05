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

Bio::EnsEMBL::Compara::Production::Projection::Writer::ProjectedDisplayXrefWriter

=head1 DESCRIPTION

This class will write the results of the given projections to a 
database given at construction by setting the target Display Xref and 
description if required.

=head1 AUTHOR

Andy Yates (ayatesatebiacuk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: http://lists.ensembl.org/mailman/listinfo/dev

=cut

package Bio::EnsEMBL::Compara::Production::Projection::Writer::ProjectedDisplayXrefWriter;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref check_ref);

use base qw(Bio::EnsEMBL::Compara::Production::Projection::Writer::BaseWriter);

=head2 new()

  Arg[-dba]           : required; Assumed to be a DBA which we can write to
  Arg[-descriptions]  : If set to true will force the transfer of descriptions
                        and not just the display xref. Defaults to false
  Description : New method used for a new instance of the given object. 
                Required fields are indicated accordingly. Fields are specified
                using the Arguments syntax (case insensitive).

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);
  my ( $dba, $descriptions) = rearrange( [qw(dba descriptions)], @args );

  assert_ref( $dba, 'Bio::EnsEMBL::DBSQL::DBAdaptor' );
  confess(
'The attribute dba must be specified during construction or provide a builder subroutine'
  ) if !defined $dba;
  $self->{dba} = $dba if defined $dba;
  
  $descriptions = $self->_descriptions_builder() if ! defined $descriptions;
  $self->{descriptions} = $descriptions if defined $descriptions;

  return $self;
}

=head2 dba()

  Description : Getter. Should be a write enabled connection

=cut

sub dba {
  my ($self) = @_;
  return $self->{dba};
}

=head2 descriptions()

  Description : Getter. Returns if we want to propagate the descriptions or not

=cut


sub descriptions {
  my ($self) = @_;
  return $self->{descriptions};
}

=head2 _dbname_to_original_type()

  Arg[1]      : DBAdaptor; should point to the source of the Hash (normally
                the source)
  Description : Getter. Returns what type of object to link the 

=cut


sub _dbname_to_original_type {
  my ($self, $dba) = @_;
  if(! exists $self->{dbname_to_original_type}) {
    $self->{dbname_to_original_type} = $self->_dbname_to_original_type_builder($dba);
  }
  return $self->{dbname_to_original_type};
}

sub _descriptions_builder {
  my ($self) = @_;
  return 0;
}


=head2 write_projection()

Re-assigns the attacted DBEntry from the list of projections to the
core database which was given to this object during construction. This method
also stores the newly assigned DBEntry.

=cut

sub write_projection {
  my ($self, $p) = @_;
  my $db_entry_a  = $self->dba()->get_DBEntryAdaptor();
  my $gene_a      = $self->dba()->get_GeneAdaptor();
    
  #Do Processing
  $self->_process_entry($p);
  $self->_process_description($p);
  $self->_update_status($p->to()->get_Gene());
  
  #Store Xref on original type of object
  my ($type, $target_object) = $self->_type_and_object($p);
  $db_entry_a->store($p->entry(), $target_object, $type, 1);
  #Update gene now we have stored the DBEntry
  $gene_a->update($p->to()->get_Gene());
  
  return;
}

=head2 _process_entry()

Sets up an Xref to be persisted back to the target core database for 
later processing.

=cut

sub _process_entry {
  my ($self, $p) = @_;
  
  my $entry = $p->entry();
  my $from_gene = $p->from()->get_Gene();
  my $from_species = $p->from()->genome_db()->name();
  my $from_stable_id = $from_gene->stable_id();
  
  #Setup Xref
  my $info_txt = "from $from_species gene $from_stable_id";
  $entry->info_type('PROJECTION');
  $entry->info_text($info_txt);
  
  #Check for modification of display if we projected 1:m
  #Code taken from original projection code. Can only do this if
  #we were given a DisplayProjection object
  if(check_ref($p, 'Bio::EnsEMBL::Compara::Production::Projection::DisplayProjection') && $p->total() > 1) {
    my $total = $p->total();
    my $index = $p->current_index();
    my $tuple_txt = " ($index of $total)";
    my $existing = $entry->display_id();
    $existing =~ s/\(\d+ of \d+\)//;
    $entry->display_id($existing . $tuple_txt);
    $info_txt .= $tuple_txt;
  }
  
  #Assign it to the gene
  my $to_gene = $p->to()->get_Gene();
  $to_gene->display_xref($entry);
  
  return;
}

=head2 _process_description()

Copies the description from a source to a target gene if allowed

=cut

sub _process_description {
  my ($self, $p) = @_;
  my $from_gene = $p->from()->get_Gene();
  my $to_gene = $p->to()->get_Gene();
  if($self->description()) {
    $to_gene->description($from_gene->description());
  }
  return;
}

=head2 _type_and_object()

Performs the lookup of what the original entry was located on and then
returns the object the DBEntry should be attached to and the type of
object it is. We also allow for the mapping of those which are marked as
HGNC*transcript or Gene to go to the correct object

=cut

sub _type_and_object {
  my ($self, $p) = @_;
  my $entry = $p->entry();
  my $dbname = $entry->dbname();
  my $to_gene = $p->to()->get_Gene();
  
  my $src_dba = $p->from()->genome_db()->db_adpator();
  my $dbname_to_type = $self->_dbname_to_original_type($src_dba);
  my $type = $dbname_to_type->{$entry->dbname()};
  
  my $target_object;
  if($type eq 'Gene' || $dbname =~ /HGNC_.*gene/) {
    $type = 'Gene';
    $target_object = $to_gene;
  }
  elsif($type eq 'Transcript' || $dbname =~ /HGNC_.*transcript/ ) {
    $type = 'Transcript';
    $target_object = $to_gene->canonical_transcript();
  }
  elsif($type eq 'Translation') {
    $target_object = $to_gene->canonical_transcript()->translation();
  }
  else {
    throw('Cannot handle Xrefs of the type '.$type);
  }
  return ($target_object, $type);
}

=head2 _update_status()

Assigns everything to KNOWN_BY_PROJECTION for the given gene and transcripts

=cut

sub _update_status {
  my ($self, $gene) = @_;
  my $status = 'KNOWN_BY_PROJECTION';
  $gene->status($status);
  foreach my $t (@{$gene->get_all_Transcripts()}) {
    $t->status($status);
  }
  return;
}

sub _dbname_to_original_type_builder {
  my ($self, $dba) = @_;
  my $sql = <<SQL;
SELECT DISTINCT e.db_name, ox.ensembl_object_type 
FROM external_db e, xref x, object_xref ox 
WHERE x.xref_id=ox.xref_id 
AND e.external_db_id=x.external_db_id
SQL
  return $dba->dbc->sql_helper->execute_into_hash(-SQL => $sql);
}

1;
