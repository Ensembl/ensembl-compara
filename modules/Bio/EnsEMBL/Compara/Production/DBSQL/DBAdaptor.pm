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

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor

=head1 SYNOPSIS

    $db = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
        -user   => 'root',
        -dbname => 'pog',
        -host   => 'caldy',
        -driver => 'mysql',
        );


=head1 DESCRIPTION

This object represents the handle for a comparative DNA alignment database

=head1 CONTACT

Post questions the the EnsEMBL developer list: <http://lists.ensembl.org/mailman/listinfo/dev>

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;

use strict;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::DBAdaptor );


#add production specific adaptors
sub get_available_adaptors {
  my $self = shift;

  my $pairs = $self->SUPER::get_available_adaptors;
  $pairs->{'DnaFragChunk'} = "Bio::EnsEMBL::Compara::Production::DBSQL::DnaFragChunkAdaptor";
  $pairs->{'DnaFragChunkSet'} = "Bio::EnsEMBL::Compara::Production::DBSQL::DnaFragChunkSetAdaptor";
  $pairs->{'DnaCollection'} = "Bio::EnsEMBL::Compara::Production::DBSQL::DnaCollectionAdaptor";
  $pairs->{'AnchorSeq'} = "Bio::EnsEMBL::Compara::Production::DBSQL::AnchorSeqAdaptor";
  $pairs->{'AnchorAlign'} = "Bio::EnsEMBL::Compara::Production::DBSQL::AnchorAlignAdaptor";
  return $pairs;
}
 

1;
