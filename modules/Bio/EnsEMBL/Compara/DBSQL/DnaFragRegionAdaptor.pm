#
# Ensembl module for Bio::EnsEMBL::Compara::DnaFragRegionAdaptor
#
# Cared for by Abel Ureta-Vidal <abel@ebi.ac.uk>
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DnaFragRegionAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 CONTACT

Ensembl - ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::DnaFragRegionAdaptor;

use strict;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::DnaFragRegion;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

sub fetch_by_synteny_region_id {
  my ($self, $synteny_region_id) = @_;
  
  if( !defined $synteny_region_id ) {
    throw("fetch_by_synteny_region_id with no synteny_region_id!");
  }
#  print "synteny_region_id : $synteny_region_id\n";
  my $sth = $self->prepare("select synteny_region_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand from dnafrag_region where synteny_region_id = $synteny_region_id");
  $sth->execute;

  
  my ($dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand);
  $sth->bind_columns(\$synteny_region_id, \$dnafrag_id, \$dnafrag_start, \$dnafrag_end, \$dnafrag_strand);
  
  my $dfrs;
  while ($sth->fetch()) {
    my $dfr = new Bio::EnsEMBL::Compara::DnaFragRegion;
    $dfr->synteny_region_id($synteny_region_id);
    $dfr->dnafrag_id($dnafrag_id);
    $dfr->dnafrag_start($dnafrag_start);
    $dfr->dnafrag_end($dnafrag_end);
    $dfr->dnafrag_strand($dnafrag_strand);
    $dfr->adaptor($self);
    push @{$dfrs}, $dfr;
  }
  return $dfrs;
}

sub store{
   my ($self,$dfr) = @_;

   if( !ref $dfr || !$dfr->isa("Bio::EnsEMBL::Compara::DnaFragRegion") ) {
       throw("$dfr is not a DnaFragRegion object");
   }

   my $sth = $self->prepare("insert into dnafrag_region (synteny_region_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand) VALUES (?,?,?,?,?)");
   
   $sth->execute($dfr->synteny_region_id, $dfr->dnafrag_id, $dfr->dnafrag_start, $dfr->dnafrag_end, $dfr->dnafrag_strand);
   $dfr->adaptor($self);
   
   return 1;
}

1;







