=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

##################################
#
#  DEPRECATED MODULE
#
# The local BioPerl server is no
# longer in use, so this module is
# obsolete. It will be removed in
# Ensembl release 78.
#
##################################

package EnsEMBL::Web::ExtIndex::biosql;

use strict;
use Bio::DB::BioDB;
use Bio::Seq::RichSeq;

sub new{
warn "!!! DEPRECATED MODULE - will be removed in Release 78";
  my $class = shift;
  my $self = bless {
    'db' => Bio::DB::BioDB->new(@_)
  }, $class;
  return $self;
}    

sub get_seq_by_acc { 
warn "!!! DEPRECATED MODULE - will be removed in Release 78";
my $self = shift; return $self->get_seq_by_id( @_ ); }

sub get_seq_by_id {
warn "!!! DEPRECATED MODULE - will be removed in Release 78";
  my( $self, $args ) = @_;
  my $seq_adaptor = $self->{db}->get_object_adaptor( 'Bio::SeqI' );
  my $seq = Bio::Seq::RichSeq->new(
    -accession_number => $args->{ 'ID' },
    -namespace        => $args->{ 'biodb_namespace' }
  );
  $seq = $seq_adaptor->find_by_unique_key( $seq );
  return $seq;
}

1;
