=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;
use Bio::EnsEMBL::Compara::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(:assert :check);

use DBI qw(:sql_types);

our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor);

our %single_species_ml = ('ENSEMBL_PARALOGUES' => 1, 'ENSEMBL_HOMOEOLOGUES' => 1, 'ENSEMBL_ORTHOLOGUES' => 0, 'ENSEMBL_PROJECTIONS' => 0);

=head2 fetch_all_by_Member

  Arg [1]    : Bio::EnsEMBL::Compara::Member $member
  Arg [-METHOD_LINK_TYPE] (opt)
             : string: the method_link_type of the homologies
               usually ENSEMBL_ORTHOLOGUES or ENSEMBL_PARALOGUES
  Arg [-METHOD_LINK_SPECIES_SET] (opt)
             : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
               Describes the kind of homology and the set of species
  Arg [-SPECIES_TREE_NODE_IDS] (opt)
             : Array of integers: the node_ids of the SpeciesTreeNodes
               we want to keep in the results. Used to get in/out-paralogues
  Example    : $homologies = $HomologyAdaptor->fetch_all_by_Member($member);
  Description: fetch the homology relationships where the given member is implicated
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_Member {
  my ($self, $member, @args) = @_;

  my ($method_link_type, $method_link_species_set, $species_tree_node_ids) =
    rearrange([qw(METHOD_LINK_TYPE METHOD_LINK_SPECIES_SET SPECIES_TREE_NODE_IDS)], @args);

  assert_ref_or_dbID($method_link_species_set, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet', '-METHOD_LINK_SPECIES_SET') if defined $method_link_species_set;
  assert_ref($member, 'Bio::EnsEMBL::Compara::Member');

  my $seq_member_id = $member->isa('Bio::EnsEMBL::Compara::GeneMember') ? $member->canonical_member_id : $member->dbID;

  my $join = [[['homology_member', 'hm'], 'h.homology_id = hm.homology_id']];
  my $constraint = 'hm.seq_member_id = ?';
  $self->bind_param_generic_fetch($seq_member_id, SQL_INTEGER);

  if (defined $method_link_species_set) {
    $constraint .= ' AND h.method_link_species_set_id = ?';
    $self->bind_param_generic_fetch(ref($method_link_species_set) ? $method_link_species_set->dbID : $method_link_species_set, SQL_INTEGER);
  }

  if (defined $species_tree_node_ids) {
    $constraint .= sprintf(' AND h.species_tree_node_id IN (%s)', join(',', -1, @$species_tree_node_ids));
  }

  # This internal variable is used by add_Member method 
  # in Bio::EnsEMBL::Compara::MemberSet to make sure that the first element
  # of the member array is the one that has been used by the user to fetch the
  # homology object
  $self->{'_this_one_first'} = $seq_member_id;

  my $homologies = $self->generic_fetch($constraint, $join);

  if (defined $method_link_type) {
    return [grep {$_->method_link_species_set->method->type eq $method_link_type} @$homologies];
  } else {
    return $homologies;
  }
}


=head2 fetch_all_by_Member_paired_species

  Arg [1]    : Bio::EnsEMBL::Compara::Member $member
  Arg [2]    : string $species
               e.g. "Mus_musculus" or "Mus musculus"
  Arg [3]    : (optional) an arrayref of method_link types
               e.g. ['ENSEMBL_ORTHOLOGUES']. Default is ['ENSEMBL_ORTHOLOGUES','ENSEMBL_PARALOGUES']
  Example    : $homologies = $HomologyAdaptor->fetch_all_by_Member_paired_species($member, "Mus_musculus");
  Description: fetch the homology relationships where the given member is implicated
               in pair with another member from the paired species. Member species and
               paired species should be different.
               
               When you give the species name the method attempts to find
               the species without _ subsitution and then replacing them
               for spaces. This is to help support GenomeDB objects which
               have _ in their names.
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Exceptions : If a GenomeDB cannot be found for the given species name
  Caller     : 

=cut

sub fetch_all_by_Member_paired_species {
  my ($self, $member, $species, $method_link_types) = @_;

  my $gdb1 = $member->genome_db;

  my $gdb_a = $self->db->get_GenomeDBAdaptor();
  my $gdb2 = eval {$gdb_a->fetch_by_registry_name($species)};
  if(!defined $gdb2) {
      $gdb2 = eval {$gdb_a->fetch_by_name_assembly($species)};
      if(!defined $gdb2) {
          throw("No GenomeDB found with name '$species'");
      }
  }

  unless (defined $method_link_types) {
    $method_link_types = [keys %single_species_ml];
  }
  my $mlssa = $self->db->get_MethodLinkSpeciesSetAdaptor;

  my $all_homologies = [];
  foreach my $ml (@{$method_link_types}) {
    my $mlss;
    if ($gdb1->dbID == $gdb2->dbID) {
      next unless $single_species_ml{$ml};
      $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($ml, [$gdb1], "no_warning");
    } else {
      next if $single_species_ml{$ml};
      $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($ml, [$gdb1, $gdb2], "no_warning");
    }
    if (defined $mlss) {
      my $homologies = $self->fetch_all_by_Member($member, -METHOD_LINK_SPECIES_SET => $mlss);
      push @{$all_homologies}, @{$homologies} if (defined $homologies);
    }
  }
  return $all_homologies;
}


=head2 fetch_by_Member_Member

  Arg [1]    : Bio::EnsEMBL::Compara::Member $member
  Arg [2]    : Bio::EnsEMBL::Compara::Member $member
  Example    : $homologies = $HomologyAdaptor->fetch_by_Member_Member(
                   $member1->gene_member, $member2->gene_member);
  Description: fetch the homology relationships with the given member pair.
  Returntype : a Bio::EnsEMBL::Compara::Homology object or undef
  Exceptions : none
  Caller     : 

=cut

sub fetch_by_Member_Member {
  my ($self, $member1, $member2) = @_;

  assert_ref($member1, 'Bio::EnsEMBL::Compara::Member');
  assert_ref($member2, 'Bio::EnsEMBL::Compara::Member');
  my $pid1 = $member1->isa('Bio::EnsEMBL::Compara::GeneMember') ? $member1->canonical_member_id : $member1->dbID;
  my $pid2 = $member2->isa('Bio::EnsEMBL::Compara::GeneMember') ? $member2->canonical_member_id : $member2->dbID;

  throw("The members should be different") if $pid1 eq $pid2;

  my $join = [[['homology_member', 'hm1'], 'h.homology_id = hm1.homology_id'],[['homology_member', 'hm2'], 'h.homology_id = hm2.homology_id']];

  my $constraint .= ' hm1.seq_member_id = ?';
  $self->bind_param_generic_fetch($pid1, SQL_INTEGER);
  $constraint .= ' AND hm2.seq_member_id = ?';
  $self->bind_param_generic_fetch($pid2, SQL_INTEGER);

  $self->{'_this_one_first'} = $pid1;

  return $self->generic_fetch_one($constraint, $join);
}



=head2 fetch_all_by_MethodLinkSpeciesSet

  Arg [1]    : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss or its dbID
  Arg [-ORTHOLOGY_TYPE] (opt)
             : string: the type of homology that have to be fetched
  Arg [-IS_TREE_COMPLIANT] (opt)
             : boolean: the filter on the confidence level
  Arg [-SPECIES_TREE_NODE_IDS] (opt)
             : Array of integers: the node_ids of the SpeciesTreeNodes
               we want to keep in the results. Used to get in/out-paralogues
  Example    : $homologies = $HomologyAdaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);
  Description: fetch all the homology relationships for the given MethodLinkSpeciesSet
               Since the homology analysis of each species pair is given a unique 
               MethodLinkSpeciesSet, this method can be used to grab all the 
               orthologues for a species pair, refined by an orthology_type
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all_by_MethodLinkSpeciesSet {
    my ($self, $mlss, @args) = @_;

    throw("method_link_species_set arg is required\n") unless ($mlss);

    my ($orthology_type, $is_tree_compliant, $species_tree_node_ids) =
        rearrange([qw(ORTHOLOGY_TYPE IS_TREE_COMPLIANT SPECIES_TREE_NODE_IDS)], @args);

    my $mlss_id = (ref($mlss) ? $mlss->dbID : $mlss);
    my $constraint = ' h.method_link_species_set_id = ?';
    $self->bind_param_generic_fetch($mlss_id, SQL_INTEGER);

    if (defined $orthology_type) {
        $constraint .= ' AND h.description = ?';
        $self->bind_param_generic_fetch($orthology_type, SQL_VARCHAR);
    }

    if (defined $is_tree_compliant) {
        $constraint .= ' AND h.is_tree_compliant = ?';
        $self->bind_param_generic_fetch($is_tree_compliant, SQL_INTEGER);
    }

    if (defined $species_tree_node_ids) {
        $constraint .= sprintf(' AND h.species_tree_node_id IN (%s)', join(',', -1, @$species_tree_node_ids));
    }

    return $self->generic_fetch($constraint);
}


=head2 fetch_all_by_tree_node_id

  Arg [1]    : int $tree_node_id
  Example    : $homologies = $HomologyAdaptor->fetch_all_by_tree_node_id($tree->node_id);
  Description: fetch all the homology relationships for the given tree
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all_by_tree_node_id {
  my ($self, $tree_node_id) = @_;

  throw("tree_node_id arg is required\n")
    unless ($tree_node_id);

  my $constraint = ' h.gene_tree_root_id = ?';
  $self->bind_param_generic_fetch($tree_node_id, SQL_INTEGER);

  return $self->generic_fetch($constraint);
}



=head2 fetch_all_by_genome_pair

  Arg [1]    : genome_db_id
  Arg [2]    : genome_db_id
  Example    : $homologies = $HomologyAdaptor->fetch_all_by_genome_pair(22,3);
  Description: fetch all the homology relationships for the a pair of genome_db_ids
               This method can be used to grab all the orthologues for a species pair.
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all_by_genome_pair {
    my ($self, $genome_db_id1, $genome_db_id2) = @_;

    my $mlssa = $self->db->get_MethodLinkSpeciesSetAdaptor;
    my @all_mlss;
    if ($genome_db_id1 == $genome_db_id2) {
        push @all_mlss, $mlssa->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$genome_db_id1]);
        push @all_mlss, $mlssa->fetch_by_method_link_type_GenomeDBs('ENSEMBL_HOMOEOLOGUES', [$genome_db_id1]);
    } else {
        push @all_mlss, $mlssa->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$genome_db_id1, $genome_db_id2]);
        push @all_mlss, $mlssa->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$genome_db_id1, $genome_db_id2]);
    }

    my $constraint = "h.method_link_species_set_id IN (". join (",", (map {$_->dbID} @all_mlss)) . ")";

    return $self->generic_fetch($constraint);
}


=head2 fetch_all_in_paralogues_from_Member_NCBITaxon

  Arg [1]    : member (Bio::EnsEMBL::Compara::Member)
  Arg [2]    : boundary_species (Bio::EnsEMBL::Compara::NCBITaxon)
  Example    : $homologies = $HomologyAdaptor->fetch_all_in_paralogues_from_Member_NCBITaxon
                    $human_member, $chicken_genomdb->taxon);
  Description: fetch all the same species paralogues of this member, that are more recent than
                the speciation even refered to by the boundary_species argument
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects

=cut

sub fetch_all_in_paralogues_from_Member_NCBITaxon {
    my $self = shift;
    return $self->_fetch_in_out_paralogues_with_NCBITaxon(1, @_);
}


=head2 fetch_all_out_paralogues_from_Member_NCBITaxon

  Arg [1]    : member (Bio::EnsEMBL::Compara::Member)
  Arg [2]    : boundary_species (Bio::EnsEMBL::Compara::NCBITaxon)
  Example    : $homologies = $HomologyAdaptor->fetch_all_in_paralogues_from_Member_NCBITaxon
                    $human_member, $chicken_genomdb->taxon);
  Description: fetch all the same species paralog of this member, that are older than
                the speciation even refered to by the boundary_species argument
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Caller     :

=cut

sub fetch_all_out_paralogues_from_Member_NCBITaxon {
    my $self = shift;
    return $self->_fetch_in_out_paralogues_with_NCBITaxon(0, @_);
}


=head2 fetch_all_in_paralogues_from_GenomeDB_NCBITaxon

  Arg [1]    : species (Bio::EnsEMBL::Compara::GenomeDB)
  Arg [2]    : boundary_species (Bio::EnsEMBL::Compara::NCBITaxon)
  Arg [3]    : member_type ('protein' or 'ncrna') (optional)
  Example    : $homologies = $HomologyAdaptor->fetch_all_in_paralogues_from_GenomeDB_NCBITaxon
                    $human_genomedb, $chicken_genomdb->taxon);
  Description: fetch all the same species paralog of this species, that are more recent than
                the speciation even refered to by the boundary_species argument
               WARNING: Some combinations may lead to a large number of rows (several millions)
               The time to download the data may be very long. We advise to use Biomart in those cases.
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Caller     :

=cut

sub fetch_all_in_paralogues_from_GenomeDB_NCBITaxon {
    my $self = shift;
    return $self->_fetch_in_out_paralogues_with_NCBITaxon(1, @_);
}


=head2 fetch_all_out_paralogues_from_GenomeDB_NCBITaxon

  Arg [1]    : species (Bio::EnsEMBL::Compara::GenomeDB)
  Arg [2]    : boundary_species (Bio::EnsEMBL::Compara::NCBITaxon)
  Arg [3]    : member_type ('protein' or 'ncrna') (optional)
  Example    : $homologies = $HomologyAdaptor->fetch_all_out_paralogues_from_GenomeDB_NCBITaxon
                    $human_genomedb, $chicken_genomdb->taxon);
  Description: fetch all the same species paralog of this species, that are older than
                the speciation even refered to by the boundary_species argument
               WARNING: Some combinations may lead to a large number of rows (several millions)
               The time to download the data may be very long. We advise to use Biomart in those cases.
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Caller     :

=cut

sub fetch_all_out_paralogues_from_GenomeDB_NCBITaxon {
    my $self = shift;
    return $self->_fetch_in_out_paralogues_with_NCBITaxon(0, @_);
}


sub _fetch_in_out_paralogues_with_NCBITaxon {
    my ($self, $in, $ref, $boundary_species, $member_type) = @_;

    my $species;

    if (check_ref($ref, 'Bio::EnsEMBL::Compara::GenomeDB')) {
        $species = $ref;
    } else {
        assert_ref($ref, 'Bio::EnsEMBL::Compara::Member');
        $species = $ref->genome_db;
    }
    my $mlss = $self->db->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$species]);

    assert_ref($boundary_species, 'Bio::EnsEMBL::Compara::NCBITaxon');
    # The last common ancestor of $species1 and $species2 defines the boundary
    my $lca = $self->db->get_NCBITaxonAdaptor->fetch_first_shared_ancestor_indexed($species->taxon, $boundary_species);

    my @good_node_ids = ();
    if ($member_type) {
        throw("Valid member_types are 'protein' and 'ncrna' (not $member_type)\n") if ($member_type ne 'protein') and ($member_type ne 'ncrna');
        push @good_node_ids, @{$self->_get_suitable_species_tree_node_ids($in, $lca, $member_type)};
    } else {
        push @good_node_ids, @{$self->_get_suitable_species_tree_node_ids($in, $lca, 'protein')};
        push @good_node_ids, @{$self->_get_suitable_species_tree_node_ids($in, $lca, 'ncrna')};
    }

    if ($mlss) {
        return $self->fetch_all_by_MethodLinkSpeciesSet($mlss, -SPECIES_TREE_NODE_IDS => \@good_node_ids);
    } else {
        return $self->fetch_all_by_Member($ref, -METHOD_LINK_SPECIES_SET => $mlss, -SPECIES_TREE_NODE_IDS => \@good_node_ids);
    }
}


sub _get_suitable_species_tree_node_ids {
    my ($self, $in, $lca, $member_type) = @_;

    my $mlss = $self->db->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type($member_type eq 'protein' ? 'PROTEIN_TREES' : 'NC_TREES')->[0];
    my $species_tree = $self->db->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($mlss->dbID, 'default');

    my $sth;

    if (not $lca) {
        my $sql = sprintf(q{SELECT node_id FROM species_tree_node WHERE root_id = ?});
        $sth = $self->prepare($sql);
        $sth->execute($species_tree->root_id);

    } else {
        my $sql = sprintf(q{SELECT DISTINCT stn.node_id FROM
            ncbi_taxa_node ntn1 JOIN ncbi_taxa_node ntn2 ON ntn1.left_index %s ntn2.left_index AND ntn1.right_index %s ntn2.right_index
            JOIN species_tree_node stn ON ntn2.taxon_id = stn.taxon_id
            WHERE
            ntn1.taxon_id = ?
            AND stn.root_id = ?
            },
            $in ? '<' : '>=',
            $in ? '>' : '<=',
        );
        $sth = $self->prepare($sql);
        $sth->execute($lca->node_id, $species_tree->root_id);
    }
    return [map {$_->[0]} @{$sth->fetchall_arrayref}];
}


=head2 fetch_orthocluster_with_Member

  Arg [1]    : Bio::EnsEMBL::Compara::Member $member
  Example    : my ($homology_list, $gene_list) = 
                 $HomologyAdaptor->fetch_orthocluster_with_Member($member);
  Description: do a recursive search starting from $gene_member to find the cluster of
               all connected genes and homologies via connected components clustering.
  Returntype : an array pair of array references.  
               First array_ref is the list of Homology objects in the cluster graph
               Second array ref is the list of unique SeqMembers in the cluster
  Exceptions : none
  Caller     : 

=cut

sub fetch_orthocluster_with_Member {
  my $self = shift;
  my $member = shift;
  
  assert_ref($member, 'Bio::EnsEMBL::Compara::Member');
  $member = $member->get_canonical_SeqMember if $member->isa('Bio::EnsEMBL::Compara::GeneMember');

  my $ortho_set = {};
  my $member_set = {};
  $self->_recursive_get_orthocluster($member, $ortho_set, $member_set, 0);

  my @homologies = values(%{$ortho_set});
  my @genes      = values(%{$member_set});
  return (\@homologies, \@genes);
}
 

sub _recursive_get_orthocluster {
  my $self = shift;
  my $gene = shift;
  my $ortho_set = shift;
  my $member_set = shift;
  my $debug = shift;

  return if($member_set->{$gene->dbID});

  print "query gene: " if ($debug);
  $gene->print_member() if($debug);
  $member_set->{$gene->dbID} = $gene;

  my $homologies = $self->fetch_all_by_Member($gene);
  printf("fetched %d homologies\n", scalar(@$homologies)) if($debug);

  foreach my $homology (@{$homologies}) {
    next if($ortho_set->{$homology->dbID});
    
    foreach my $member (@{$homology->get_all_Members}) {
      next if($member->dbID == $gene->dbID); #skip query gene
      $member->print_member if($debug);

      printf("adding homology_id %d to cluster\n", $homology->dbID) if($debug);
      $ortho_set->{$homology->dbID} = $homology;
      $self->_recursive_get_orthocluster($member, $ortho_set, $member_set, $debug);
    }
  }
  printf("done with search query %s\n", $gene->stable_id) if($debug);
}

sub fetch_by_stable_id {
    throw('Stable IDs are not implemented for homologies');
}

#
# internal methods
#
###################

# internal methods used in multiple calls above to build homology objects from table data  

sub _tables {
  return (['homology', 'h']);
}

sub _columns {
  return qw (h.homology_id
             h.method_link_species_set_id
             h.description
             h.is_tree_compliant
             h.dn
             h.ds
             h.n
             h.s
             h.lnl
             h.species_tree_node_id
             h.gene_tree_node_id
             h.gene_tree_root_id);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my ($homology_id, $description, $is_tree_compliant, $dn, $ds, $n, $s, $lnl,
      $method_link_species_set_id, $species_tree_node_id, $gene_tree_node_id, $gene_tree_root_id);

  $sth->bind_columns(\$homology_id, \$method_link_species_set_id,
                     \$description, \$is_tree_compliant, \$dn, \$ds,
                     \$n, \$s, \$lnl, \$species_tree_node_id, \$gene_tree_node_id, \$gene_tree_root_id);

  my @homologies = ();
  
  while ($sth->fetch()) {
    push @homologies, Bio::EnsEMBL::Compara::Homology->new_fast({
            'adaptor'                       => $self,
            'dbID'                          => $homology_id,
            '_description'                  => $description,
            '_is_tree_compliant'            => $is_tree_compliant,
            '_method_link_species_set_id'   => $method_link_species_set_id,
            '_dn'                           => $dn,
            '_ds'                           => $ds,
            '_n'                            => $n,
            '_s'                            => $s,
            '_lnl'                          => $lnl,
            '_this_one_first'               => $self->{'_this_one_first'},
            '_species_tree_node_id'         => $species_tree_node_id,
            '_gene_tree_node_id'            => $gene_tree_node_id,
            '_gene_tree_root_id'            => $gene_tree_root_id,
       });
  }
  
  return \@homologies;  
}

#
# STORE METHODS
#
################

=head2 store

 Arg [1]    : Bio::EnsEMBL::Compara::Homology $homology
 Example    : $HomologyAdaptor->store($homology)
 Description: Stores a homology object into a compara database
 Returntype : int 
              been the database homology identifier, if homology stored correctly
 Exceptions : when isa if Arg [1] is not Bio::EnsEMBL::Compara::Homology
 Caller     : general

=cut

sub store {
  my ($self,$hom) = @_;
  
  assert_ref($hom, 'Bio::EnsEMBL::Compara::Homology');

  $hom->adaptor($self);

  if ( !defined $hom->method_link_species_set_id && defined $hom->method_link_species_set) {
    $self->db->get_MethodLinkSpeciesSetAdaptor->store($hom->method_link_species_set);
  }

  assert_ref($hom->method_link_species_set, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet');
  $hom->method_link_species_set_id($hom->method_link_species_set->dbID);
  
  unless($hom->dbID) {
    my $sql = 'INSERT INTO homology (method_link_species_set_id, description, is_tree_compliant, species_tree_node_id, gene_tree_node_id, gene_tree_root_id) VALUES (?,?,?,?,?,?)';
    my $sth = $self->prepare($sql);
    $sth->execute($hom->method_link_species_set_id, $hom->description, $hom->is_tree_compliant, $hom->{_species_tree_node_id}, $hom->{_gene_tree_node_id}, $hom->{_gene_tree_root_id});
    $hom->dbID( $self->dbc->db_handle->last_insert_id(undef, undef, 'homology', 'homology_id') );
  }

  my $sql = 'INSERT IGNORE INTO homology_member (homology_id, gene_member_id, seq_member_id, cigar_line, perc_id, perc_pos, perc_cov) VALUES (?,?,?,?,?,?,?)';
  my $sth = $self->prepare($sql);
  foreach my $member(@{$hom->get_all_Members}) {
    # Stores the member if not yet stored
    $self->db->get_SeqMemberAdaptor->store($member) unless (defined $member->dbID);
    $sth->execute($member->set->dbID, $member->gene_member_id, $member->dbID, $member->cigar_line, $member->perc_id, $member->perc_pos, $member->perc_cov);
  }

  return $hom->dbID;
}


=head2 update_genetic_distance

 Arg [1]    : Bio::EnsEMBL::Compara::Homology $homology
 Example    : $HomologyAdaptor->update_genetic_distance($homology)
 Description: updates the n,s,dn,ds,lnl values from a homology object into a compara database
 Exceptions : when isa if Arg [1] is not Bio::EnsEMBL::Compara::Homology
 Caller     : Bio::EnsEMBL::Compara::Runnable::Homology_dNdS

=cut

sub update_genetic_distance {
  my $self = shift;
  my $hom = shift;

  assert_ref($hom, 'Bio::EnsEMBL::Compara::Homology');

  throw("homology object must have dbID")
    unless ($hom->dbID);
  # We use here internal hash key for _dn and _ds because the dn and ds method call
  # do some filtering based on the threshold_on_ds.
  unless(defined $hom->{'_dn'} and defined $hom->{'_ds'} and defined $hom->n and defined $hom->lnl and defined $hom->s) {
    warn("homology needs valid dn, ds, n, s, and lnl values to store");
    return $self;
  }

  my $sql = 'UPDATE homology SET dn=?, ds=?, n=?, s=?, lnl=? WHERE homology_id=?';

  my $sth = $self->prepare($sql);
  $sth->execute($hom->{'_dn'},$hom->{'_ds'},$hom->n, $hom->s, $hom->lnl, $hom->dbID);
  $sth->finish();

  return $self;
}



1;
