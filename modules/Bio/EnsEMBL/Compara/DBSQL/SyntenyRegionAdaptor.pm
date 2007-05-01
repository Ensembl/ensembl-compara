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

Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor - Object to access data in the synteny_region
and dnafrag_region tables

=head1 SYNOPSIS

=head2 Get the adaptor from the Registry

  use Bio::EnsEMBL::Registry;

  my $reg = "Bio::EnsEMBL::Registry";
  $reg->load_registry_from_db(
      -host => "ensembldb.ensembl.org",
      -user => "anonymous");

  my $synteny_region_adaptor = $reg->get_adaptor(
      "Multi", "compara", "SyntenyRegion");

=head2 Store method

  $synteny_region_adaptor->store($synteny_region);

=head2 Fetching methods

  my $synteny_region = $synteny_region_adaptor->fetch_by_dbID(1);
  my $synteny_regions = $synteny_region_adaptor->
      fetch_by_MethodLinkSpeciesSet_DnaFrag(
          $mlss, $dnafrag, $start, $end);


=head2 Example script

  use strict;
  use Bio::EnsEMBL::Registry;

  my $reg = "Bio::EnsEMBL::Registry";

  $reg->load_registry_from_db(
      -host=>"ensembldb.ensembl.org", -user=>"anonymous", -software_version => 38);

  my $method_link_species_set_adaptor = $reg->get_adaptor(
      "Multi", "compara", "MethodLinkSpeciesSet");
  my $human_mouse_synteny_method_link_species_set =
      $method_link_species_set_adaptor->
          fetch_by_method_link_type_registry_aliases(
              "SYNTENY", ["human", "mouse"]);

  my $genome_db_adaptor = $reg->get_adaptor(
      "Multi", "compara", "GenomeDB");
  my $genome_db = $genome_db_adaptor->
      fetch_by_name_assembly("Homo sapiens", undef);

  my $dnafrag_adaptor = $reg->get_adaptor(
      "Multi", "compara", "DnaFrag");
  my $dnafrag = $dnafrag_adaptor->
      fetch_by_GenomeDB_and_name($genome_db, "3");

  my $synteny_region_adaptor = $reg->get_adaptor(
      "Multi", "compara", "SyntenyRegion");
  my $synteny_regions = $synteny_region_adaptor->
      fetch_by_MethodLinkSpeciesSet_DnaFrag(
          $human_mouse_synteny_method_link_species_set,
          $dnafrag, 100000, 200000);

  foreach my $this_synteny_region (@$synteny_regions) {
    my $these_dnafrag_regions = $this_synteny_region->children();
    foreach my $this_dnafrag_region (@$these_dnafrag_regions) {
      print $this_dnafrag_region->dnafrag->genome_db->name, ": ", $this_dnafrag_region->slice->name, "\n";
    }
    print "\n";
  }

=head1 DESCRIPTION

This object is intended for accessing data in the synteny_region and dnafrag_region tables.

=head1 INHERITANCE

This class inherits all the methods and attributes from Bio::EnsEMBL::DBSQL::BaseAdaptor

=head1 SEE ALSO

 - Bio::EnsEMBL::Compara::SyntenyRegion
 - Bio::EnsEMBL::Compara::DnaFragRegion
 - Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
 - Bio::EnsEMBL::Compara::GenomeDB

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


=head2 fetch_by_dbID

  Arg  1     : int $synteny_region_id
  Example    : my $this_synteny_region = $synteny_region_adaptor->
                  fetch_by_dbID($synteny_region_id)
  Description: Fetches the corresponding Bio::EnsEMBL::Compara::SyntenyRegion
               object.
  Returntype : Bio::EnsEMBL::Compara::SyntenyRegion object
  Exception  : Thrown if the argument is not defined
  Caller     :

=cut

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

=head2 store

  Arg  1     : Bio::EnsEMBL::Compara::SyntenyRegion object
  Example    : $synteny_region_adaptor->store($synteny_region)
  Description: Stores a Bio::EnsEMBL::Compara::SyntenyRegion object into
               the database as well as the underlying
               Bio::EnsEMBL::Compara::DnaFragRegion objects
  Returntype : int (the synteny_region_id)
  Exception  : Thrown if the argument is not a
               Bio::EnsEMBL::Compara::SyntenyRegion object
  Caller     :

=cut

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


=head2 fetch_all_by_MethodLinkSpeciesSet_Slice

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : Bio::EnsEMBL::Slice $original_slice
  Example    : my $synteny_regions =
                  $synteny_region_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
                      $method_link_species_set, $original_slice);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::SyntenyRegion objects.
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::SyntenyRegion objects.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::SyntenyRegion object can be retrieved
  Caller     : $object->method_name
  Status     : Medium risk

=cut

sub fetch_all_by_MethodLinkSpeciesSet_Slice {
  my ($self, $method_link_species_set, $reference_slice) = @_;
  my $all_synteny_regions = []; # Returned value

  ## method_link_species_set will be checked in the fetch_all_by_MethodLinkSpeciesSet_DnaFrag method

  ## Check original_slice
  unless(UNIVERSAL::isa($reference_slice, 'Bio::EnsEMBL::Slice')) {
    throw("[$reference_slice] should be a Bio::EnsEMBL::Slice object\n");
  }

  my $dnafrag_adaptor = $self->db->get_DnaFragAdaptor;

  my $projection_segments = $reference_slice->project('toplevel');
  return [] if(!@$projection_segments);

  foreach my $this_projection_segment (@$projection_segments) {
    my $this_slice = $this_projection_segment->to_Slice;
    my $this_dnafrag = $dnafrag_adaptor->fetch_by_Slice($this_slice);
    next if (!$this_dnafrag);
    my $these_synteny_regions = $self->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
            $method_link_species_set,
            $this_dnafrag,
            $this_slice->start,
            $this_slice->end,
        );

    push (@$all_synteny_regions, @$these_synteny_regions);
  }

  return $all_synteny_regions;
}


=head2 fetch_by_MethodLinkSpeciesSet_DnaFrag

 Status      : Deprecated. Use fetch_all_by_MethodLinkSpeciesSet_DnaFrag
               instead

=cut

sub fetch_by_MethodLinkSpeciesSet_DnaFrag {
  my $self = shift(@_);

  return $self->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(@_);
}


=head2 fetch_all_by_MethodLinkSpeciesSet_DnaFrag

  Arg 1      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss
  Arg 2      : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Arg 3 (opt): int $start
  Arg 4 (opt): int $end
  Example    : my $these_synteny_regions = $synteny_region_adaptor->
                  fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
                  $mlss, $dnafrag, 100000, 200000);
  Description: Fetches the Bio::EnsEMBL::Compara::SyntenyRegion
               objects in this region for the set of species
               defined by the $mlss.
  Returntype : listref of Bio::EnsEMBL::Compara::SyntenyRegion objects
  Exception  : Thrown if the argument is not defined
  Caller     :
  Status     : Stable

=cut

sub fetch_all_by_MethodLinkSpeciesSet_DnaFrag {
  my ($self, $mlss, $dnafrag, $start, $end) = @_;

  if (!UNIVERSAL::isa($mlss, "Bio::EnsEMBL::Compara::MethodLinkSpeciesSet")) {
    throw("[$mlss] is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object");
  }
  if (!UNIVERSAL::isa($dnafrag, "Bio::EnsEMBL::Compara::DnaFrag")) {
    throw("[$dnafrag] is not a Bio::EnsEMBL::Compara::DnaFrag object");
  }

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


=head2 fetch_all_by_MethodLinkSpeciesSet

  Arg 1      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss
  Example    : my $these_synteny_regions = $synteny_region_adaptor->
                  fetch_all_by_MethodLinkSpeciesSet($mlss);
  Description: Fetches the Bio::EnsEMBL::Compara::SyntenyRegion
               objects for the set of species defined by the $mlss.
  Returntype : listref of Bio::EnsEMBL::Compara::SyntenyRegion objects
  Exception  : Thrown if the argument is not defined
  Caller     :
  Status     : Stable

=cut

sub fetch_all_by_MethodLinkSpeciesSet {
  my ($self, $mlss) = @_;

  if (!UNIVERSAL::isa($mlss, "Bio::EnsEMBL::Compara::MethodLinkSpeciesSet")) {
    throw("[$mlss] is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object");
  }

  my $sql = "select sr.synteny_region_id from synteny_region sr where sr.method_link_species_set_id = ?";

  my $sth = $self->prepare($sql);
  $sth->execute($mlss->dbID);

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







