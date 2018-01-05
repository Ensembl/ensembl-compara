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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor

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

  my $synteny_region = $synteny_region_adaptor->fetch_by_dbID(1); # Used for production purposes

  my $synteny_regions = $synteny_region_adaptor->
      fetch_all_by_MethodLinkSpeciesSet($mlss);

  my $synteny_regions = $synteny_region_adaptor->
      fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss, $dnafrag, $start, $end);

  my $synteny_regions = $synteny_region_adaptor->
      fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice);


=head2 Example script

  use Bio::EnsEMBL::Registry;

  my $reg = "Bio::EnsEMBL::Registry";

  $reg->load_registry_from_db(
      -host=>"ensembldb.ensembl.org", -user=>"anonymous");

  my $method_link_species_set_adaptor = $reg->get_adaptor(
      "Multi", "compara", "MethodLinkSpeciesSet");
  my $human_mouse_synteny_method_link_species_set =
      $method_link_species_set_adaptor->
          fetch_by_method_link_type_registry_aliases(
              "SYNTENY", ["human", "mouse"]);

  my $genome_db_adaptor = $reg->get_adaptor(
      "Multi", "compara", "GenomeDB");
  my $genome_db = $genome_db_adaptor->
      fetch_by_name_assembly("homo_sapiens");

  my $dnafrag_adaptor = $reg->get_adaptor(
      "Multi", "compara", "DnaFrag");
  my $dnafrag = $dnafrag_adaptor->
      fetch_by_GenomeDB_and_name($genome_db, "3");

  my $synteny_region_adaptor = $reg->get_adaptor(
      "Multi", "compara", "SyntenyRegion");
  my $synteny_regions = $synteny_region_adaptor->
      fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
          $human_mouse_synteny_method_link_species_set,
          $dnafrag, 100000, 200000);

  foreach my $this_synteny_region (@$synteny_regions) {
    my $these_dnafrag_regions = $this_synteny_region->get_all_DnaFragRegions();
    foreach my $this_dnafrag_region (@$these_dnafrag_regions) {
      print $this_dnafrag_region->dnafrag->genome_db->name, ": ", $this_dnafrag_region->slice->name, "\n";
    }
    print "\n";
  } 

=head1 APPENDIX

  The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor;

use strict;
use warnings;

use DBI qw(:sql_types);

use Data::Dumper;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);
use Bio::EnsEMBL::Compara::SyntenyRegion;

use base qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);


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
  Status     : Stable

=cut

sub store {
   my ($self,$sr) = @_;

   assert_ref($sr, 'Bio::EnsEMBL::Compara::SyntenyRegion', 'sr');

   my $dbID = $self->generic_insert('synteny_region', {
           'synteny_region_id' => $sr->dbID,
           'method_link_species_set_id' => $sr->method_link_species_set_id,
       }, 'synteny_region_id');
   $self->attach($sr, $dbID);

   my $dfra = $self->db->get_DnaFragRegionAdaptor;
   foreach my $dfr (@{$sr->get_all_DnaFragRegions()}) {
     $dfr->synteny_region_id($sr->dbID);
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
  Status     : Stable

=cut

sub fetch_all_by_MethodLinkSpeciesSet_Slice {
  my ($self, $method_link_species_set, $reference_slice) = @_;
  my $all_synteny_regions = []; # Returned value

  ## method_link_species_set will be checked in the fetch_all_by_MethodLinkSpeciesSet_DnaFrag method

  ## Check original_slice
  assert_ref($reference_slice, 'Bio::EnsEMBL::Slice', 'reference_slice');

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

  assert_ref($mlss, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet', 'mlss');
  assert_ref($dnafrag, 'Bio::EnsEMBL::Compara::DnaFrag', 'dnafrag');

  my $join = [[['dnafrag_region', 'dfr'], 'sr.synteny_region_id=dfr.synteny_region_id']];
  my $constraint = '(sr.method_link_species_set_id = ?) AND (dfr.dnafrag_id = ?)';
  $self->bind_param_generic_fetch($mlss->dbID, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag->dbID, SQL_INTEGER);
  
  if (defined $start) {
    $constraint .= ' AND (dfr.dnafrag_end >= ?)';
    $self->bind_param_generic_fetch($start, SQL_INTEGER);
  }
  if (defined $end) {
    $constraint .= ' AND (dfr.dnafrag_start <= ?)';
    $self->bind_param_generic_fetch($end, SQL_INTEGER);
  }

  return $self->generic_fetch($constraint, $join);
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

  assert_ref($mlss, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet', 'mlss');

  my $constraint = 'method_link_species_set_id = ?';
  $self->bind_param_generic_fetch($mlss->dbID, SQL_INTEGER);

  return $self->generic_fetch($constraint);
}


sub count_by_mlss_id {
    my ($self, $mlss_id) = @_;

    $self->bind_param_generic_fetch($mlss_id, SQL_INTEGER);
    return $self->generic_count('method_link_species_set_id=?');
}


#
# Virtual methods from BaseAdaptor
####################################

sub _tables {

    return (['synteny_region', 'sr'])
}

sub _columns {

    return qw(
        sr.synteny_region_id
        sr.method_link_species_set_id
    );
}

sub _objs_from_sth {
    my ($self, $sth) = @_;

    my $dfra = $self->db->get_DnaFragRegionAdaptor;
    return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::SyntenyRegion', [
            'dbID',
            'method_link_species_set_id',
        ], sub {
            my $a = shift;
            return {
                'regions' => $dfra->fetch_all_by_synteny_region_id($a->[0]),
            }
        } );
}


1;

