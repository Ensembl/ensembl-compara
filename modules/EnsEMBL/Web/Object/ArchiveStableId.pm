=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Object::ArchiveStableId;

### NAME: EnsEMBL::Web::Object::ArchiveStableId
### Wrapper around a Bio::EnsEMBL::ArchiveStableId object  

### STATUS: At Risk
### Contains a lot of functionality not directly related to
### manipulation of the underlying API object 

### DESCRIPTION


use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);



=head2 _adaptor

 Arg1        : data object
 Description : internal call to get archive stable ID adaptor
 Return type : ArchiveStableId adaptor

=cut

sub _adaptor {
  my $self = shift;
  return $self->database('core')->get_ArchiveStableIdAdaptor;
}


=head2 gene

 Arg1        : data object
 Description : fetches archived genes off the core API object 
 Return type : list ref of archive IDs

=cut

sub gene {
  my $self = shift;
  return $self->Obj->get_all_gene_archive_ids();
}


=head2 transcript

 Arg1        : data object
 Description : fetches transcript archive IDs off the core API object 
 Return type : listref of Bio::EnsEMBL::ArchiveStableId

=cut

sub transcript {
  my $self = shift;
  return $self->Obj->get_all_transcript_archive_ids;
}


=head2 peptide

 Arg1        : data object
 Description : fetches peptide archive IDs off the core API object 
 Return type : listref of Bio::EnsEMBL::ArchiveStableId

=cut

sub peptide {
  my $self = shift;
  return $self->Obj->get_all_translation_archive_ids;
}


=head2 get_peptide

 Arg1        : data object
 Description : fetches peptide seq  off the core API object 
 Return type : string

=cut

sub get_peptide {
  my $self = shift;
  return $self->Obj->get_peptide;
}


=head2 get_all_associated_archived

 Arg1        : data object
 Description : fetches all associated archived IDs
 Return type : Arrayref of
                  Bio::EnsEMBL::ArchiveStableId archived gene
                  Bio::EnsEMBL::ArchiveStableId archived transcript
                  Bio::EnsEMBL::ArchiveStableId archived translation (optional)
                  String peptide sequence (optional)

=cut

sub get_all_associated_archived {
  my $self = shift;
  return $self->Obj->get_all_associated_archived;
}


=head2 history

 Arg1        : data object
 Description : gets the archive id history tree based around this ID
 Return type : listref of Bio::EnsEMBL::ArchiveStableId
               As every ArchiveStableId knows about it's successors, this is
                a linked tree.

=cut

sub history {
  my $self = shift;

  my $adaptor = $self->_adaptor;
  return unless $adaptor;

  my $history = $adaptor->fetch_history_tree_by_stable_id($self->stable_id);
  return $history;
}


=head2 short_id_history

 Arg1        : data object
 Description : fetches history for stable_id off the core API object 
 Return type : list ref of Archive ID objects

=cut

sub short_id_history {
  my $self = shift;
  my $adaptor = $self->_adaptor; 
  my $history =  $adaptor->fetch_archive_id_history($self->Obj);
  return $history;
}


=head2 successors

 Arg1        : data object
 Description : fetches successors off the core API object 
 Return type : list ref of Archive ID objects

=cut

sub successors {
  my $self = shift;
  return $self->Obj->get_all_successors;
}


=head2 successor_history

 Arg1        : data object
 Description : fetches successor history of core API object 
 Return type : list ref of Archive ID objects

=cut

sub successor_history {
  my $self = shift;
  my $adaptor = $self->_adaptor;
  return unless $adaptor;
  return $adaptor->fetch_successor_history($self->Obj);
}


=head2 predecessors

 Arg1        : data object
 Description : fetches predecessors off the core API object 
 Return type : list ref of Archive ID objects

=cut

sub predecessors {
  my $self = shift;
  return $self->Obj->get_all_predecessors;
}


=head2 predecessor_history

 Arg1        : data object
 Description : fetches predecessor history of core API object 
 Return type : list ref of Archive ID objects

=cut

sub predecessor_history {
  my $self = shift;
  my $adaptor = $self->_adaptor;
  return unless $adaptor;
  return $adaptor->fetch_predecessor_history($self->Obj);
}


=head2 type

 Arg1        : data object
 Description : fetches type off the core API object 
 Return type : string

=cut

sub type {
  my $self = shift;
  return $self->Obj->type;
}


=head2 stable_id

 Arg1        : data object
 Description : fetches stable_id off the core API object 
 Return type : string

=cut

sub stable_id {
  my $self = shift;
  return $self->Obj->stable_id;
}


=head2 version

 Arg1        : data object
 Description : fetches version off the core API object 
 Return type : string

=cut

sub version {
  my $self = shift;
  return $self->Obj->version;
}


=head2 release

 Arg1        : data object
 Description : fetches release number off the core API object 
 Return type : string

=cut

sub release {
  my $self = shift;
  return $self->Obj->release;
}


=head2 assembly

 Arg1        : data object
 Description : fetches assembly off the core API object 
 Return type : string

=cut

sub assembly {
  my $self = shift;
  return $self->Obj->assembly;
}


=head2 db_name

 Arg1        : data object
 Description : fetches db_name off the core API object 
 Return type : string

=cut

sub db_name {
  my $self = shift;
  return $self->Obj->db_name;
}


=head2 current_version

 Arg1        : data object
 Description : fetches current version off the core API object 
 Return type : string

=cut

sub current_version {
  my $self = shift;
  return $self->Obj->current_version;
}


=head2 is_current

 Arg1        : data object
 Description : determines whether object is in the current database 
 Return type : Boolean

=cut

sub is_current {
  my $self = shift;
  return $self->Obj->is_current;
}


=head2 get_latest_incarnation

 Arg1        : data object
 Description : Fetch the latest incarnation of this object
 Return type : Bio::EnsEMBL::ArchiveStableId

=cut

sub get_latest_incarnation {
  my $self = shift;
  return $self->Obj->get_latest_incarnation;
}


1;
