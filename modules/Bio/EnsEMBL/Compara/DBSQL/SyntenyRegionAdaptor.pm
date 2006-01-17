#
# Ensembl module for Bio::EnsEMBL::Compara::SyntenyRegionAdaptor
#
# Cared for by Abel Ureta-Vidal <abel@ebi.ac.uk>
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 CONTACT

Ensembl - ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor;

use strict;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::SyntenyRegion;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

sub fetch_by_dbID{
   my ($self,$dbID) = @_;

   if( !defined $dbID ) {
     throw("fetch_by_dbID with no dbID!");
   }

   my $sth = $self->prepare("select synteny_region_id, method_link_species_set_id from synteny_region where synteny_region_id = $dbID");
   $sth->execute;
   my ($synteny_region_id, $method_link_species_set_id) = $sth->fetchrow_array();

   my $sr = new Bio::EnsEMBL::Compara::SyntenyRegion;
   $sr->dbID($synteny_region_id);
   $sr->method_link_species_set_id($method_link_species_set_id);

   my $dfra = $self->db->get_DnaFragRegionAdaptor;
   my $dfrs = $dfra->fetch_by_synteny_region_id($dbID);
   while (my $dfr = shift @{$dfrs}) {
     $sr->add_child($dfr);
   }
   return $sr;
}

sub store{
   my ($self,$sr) = @_;

   if( !ref $sr || !$sr->isa("Bio::EnsEMBL::Compara::SyntenyRegion") ) {
       throw("$sr is not a SyntenyRegion object");
   }

   my $sth = $self->prepare("insert into synteny_region (method_link_species_set_id) VALUES (?)");
   
   $sth->execute($sr->method_link_species_set_id);
   my $synteny_region_id = $sth->{'mysql_insertid'};
   
   $sr->dbID($synteny_region_id);
   $sr->adaptor($self);
   
   my $dfra = $self->db->get_DnaFragRegionAdaptor;
   foreach my $dfr (@{$sr->children}) {
     $dfr->synteny_region_id($synteny_region_id);
     $dfra->store($dfr);
   }
   return $sr->dbID;
}

sub fetch_by_MethodLinkSpeciesSet_DnaFrag {
  my ($self, $mlss, $dnafrag, $start, $end) = @_;

  my $sql = "select sr.synteny_region_id from synteny_region sr, dnafrag_region dfr where sr.method_link_species_set_id = ? and sr.synteny_region_id=dfr.synteny_region_id and dfr.dnafrag_id = ?";
  
  if (defined $start) {
    $sql .= " and dfr.dnafrag_end >= $start";
  }
  if (defined $end) {
    $sql .= " and dfr.dnafrag_start <= $end";
  }

  my $sth = $self->prepare($sql);
  $sth->execute($mlss->dbID, $dnafrag->dbID);

  my $synteny_region_id;
  $sth->bind_columns(\$synteny_region_id);
  my @srs;
  while ($sth->fetch) {
    my $sr = new Bio::EnsEMBL::Compara::SyntenyRegion;
    $sr->dbID($synteny_region_id);
    $sr->method_link_species_set_id($mlss->dbID);

    my $dfra = $self->db->get_DnaFragRegionAdaptor;
    my $dfrs = $dfra->fetch_by_synteny_region_id($synteny_region_id);
    while (my $dfr = shift @{$dfrs}) {
      $sr->add_child($dfr);
    }

    push @srs, $sr;
  }

  return \@srs;
}

1;







