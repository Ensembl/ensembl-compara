=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DnaFragRegionAdaptor

=head1 SYNOPSIS

=head2 Get the adaptor from the Registry

  use Bio::EnsEMBL::Registry;

  my $reg = "Bio::EnsEMBL::Registry";
  $reg->load_registry_from_db(
      -host => "ensembldb.ensembl.org",
      -user => "anonymous");

  my $dnafrag_region_adaptor = $reg->get_adaptor(
      "Multi", "compara", "DnaFragRegion");


=head2 Storing method

  $dnafrag_region_adaptor->store($dnafrag_region); # Usually called by the Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor->store() method.


=head2 Fetching methods

  $dnafrag_region_adaptor->fetch_all_by_synteny_region_id($sinteny_region->dbID);  # Usually called by the Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor->fetch...() methods.


=head1 DESCRIPTION

A Bio::EnsEMBL::Compara::DBSQL::DnaFragRegion object stores the coordinates of a region that is in synteny with at least another one. These are linked in a Bio::EnsEMBL::Compara::DBSQL::SyntenyRegion object.

Please refer to the Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor for further info on how to fetch synteny blocks

=head1 CONTACT

Ensembl - dev@ensembl.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::DnaFragRegionAdaptor;

use strict;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::DnaFragRegion;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


=head2 fetch_by_synteny_region_id

  DEPRECATED. Please use fetch_all_by_synteny_region_id() instead

=cut


sub fetch_by_synteny_region_id {
  my ($self, $synteny_region_id) = @_;

  return $self->fetch_all_by_synteny_region_id($synteny_region_id);
}



=head2 fetch_all_by_synteny_region_id

  Arg  1     : int $synteny_region_id
  Example    : my $these_dnafrag_regions = $dnafrag_region_adaptor->
                  fetch_all_by_synteny_region_id($synteny_region_id)
  Description: Fetches the corresponding Bio::EnsEMBL::Compara::DnaFragRegion
               objects.
  Returntype : Listref of Bio::EnsEMBL::Compara::DnaFragRegion objects
  Exception  : Thrown if the argument is not defined
  Caller     : Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor
  Status     : At risk

=cut

sub fetch_all_by_synteny_region_id {
  my ($self, $synteny_region_id) = @_;
  
  if( !defined $synteny_region_id ) {
    throw("fetch_all_by_synteny_region_id with no synteny_region_id!");
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


=head2 store

  Arg  1     : Bio::EnsEMBL::Compara::DnaFragRegion $dnafrag_region
  Example    : $dnafrag_region_adaptor->store($dnafrag_region)
  Description: Stores the corresponding Bio::EnsEMBL::Compara::DnaFragRegion
               in the database.
  Returntype : int
  Exception  : Thrown if the argument is not defined
  Caller     : Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor
  Status     : At risk

=cut


sub store {
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







