#
# BioPerl module for DBSQL::Obj
#
# Cared for by Ewan Birney <birney@sanger.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

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

Post questions the the EnsEMBL developer list: <ensembl-dev@ebi.ac.uk>

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
  $pairs->{'AnalysisData'} = "Bio::EnsEMBL::Hive::DBSQL::AnalysisDataAdaptor";
  $pairs->{'AnchorSeq'} = "Bio::EnsEMBL::Compara::Production::DBSQL::AnchorSeqAdaptor";
  $pairs->{'AnchorAlign'} = "Bio::EnsEMBL::Compara::Production::DBSQL::AnchorAlignAdaptor";
  return $pairs;
}
 

1;
