package Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor;

use strict;

use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

use Bio::EnsEMBL::Utils::Exception qw(deprecate throw);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use DBI qw(:sql_types);

our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor);


=head2 fetch_all_by_Member

 Arg [1]    : Bio::EnsEMBL::Compara::Member $member
 Example    : $homologies = $HomologyAdaptor->fetch_all_by_Member($member);
 Description: fetch the homology relationships where the given member is implicated
 Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
 Exceptions : none
 Caller     : general

=cut

sub fetch_all_by_Member {
  my ($self, $member) = @_;

  #$member = $member->get_canonical_Member;
  my $join = [[['homology_member', 'hm'], 'h.homology_id = hm.homology_id']];
  my $constraint = "hm.member_id = " .$member->dbID;

  # This internal variable is used by add_Member method 
  # in Bio::EnsEMBL::Compara::MemberSet to make sure that the first element
  # of the member array is the one that has been used by the user to fetch the
  # homology object
  $self->{'_this_one_first'} = $member->stable_id;

  return $self->generic_fetch($constraint, $join);
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

	my $gdb_a = $self->db->get_GenomeDBAdaptor();
  my $gdb1 = $member->genome_db;
  my $gdb2 = eval {$gdb_a->fetch_by_name_assembly($species)};
  if(!defined $gdb2) {
  	my $species_no_underscores = $species;
  	$species_no_underscores =~ tr/_/ /;
  	$gdb2 = eval {$gdb_a->fetch_by_name_assembly($species_no_underscores)};
  	if(!defined $gdb2) {
  		throw("No GenomeDB found with names [$species | $species_no_underscores]");
  	}
  }

  unless (defined $method_link_types) {
    $method_link_types = ['ENSEMBL_ORTHOLOGUES','ENSEMBL_PARALOGUES'];
  }
  my $mlssa = $self->db->get_MethodLinkSpeciesSetAdaptor;

  my $all_homologies = [];
  foreach my $ml (@{$method_link_types}) {
    my $mlss;
    if ($gdb1->dbID == $gdb2->dbID) {
      next if ($ml eq 'ENSEMBL_ORTHOLOGUES');
      $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($ml, [$gdb1], "no_warning");
    } else {
      $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($ml, [$gdb1, $gdb2], "no_warning");
    }
    if (defined $mlss) {
      my $homologies = $self->fetch_all_by_Member_MethodLinkSpeciesSet($member, $mlss);
      push @{$all_homologies}, @{$homologies} if (defined $homologies);
    }
  }
  return $all_homologies;
}


=head2 fetch_all_by_Member_method_link_type

  Arg [1]    : Bio::EnsEMBL::Compara::Member $member
  Arg [2]    : string $method_link_type
  Example    : $homologies = $HomologyAdaptor->fetch_all_by_Member_method_link_type(
                   $member, "ENSEMBL_ORTHOLOGUES");
  Description: fetch the homology relationships where the given member is implicated
               in a relationship of the type defined by $method_link_type.
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all_by_Member_method_link_type {
  my ($self, $member, $method_link_type) = @_;

  unless ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    throw("The argument must be a Bio::EnsEMBL::Compara::Member object, not $member");
  }

  unless ($member->genome_db_id) {
    warning("Cannot get Homologues for a Bio::EnsEMBL::Compara::Member (".$member->source_name.
        "::".$member->stable_id.") with no GenomeDB");
    return [];
  }
  #$member = $member->get_canonical_Member;

  throw("method_link_type arg is required\n")
    unless ($method_link_type);

  my $mlssa = $self->db->get_MethodLinkSpeciesSetAdaptor;
  my $mlss_arrayref = $mlssa->fetch_all_by_method_link_type_GenomeDB($method_link_type,$member->genome_db);

  unless (scalar @{$mlss_arrayref}) {
    warning("There is no $method_link_type data stored in the database for " . $member->genome_db->name . "\n");
    return [];
  }

  my $join = [[['homology_member', 'hm'], 'h.homology_id = hm.homology_id']];
  my $constraint =  " h.method_link_species_set_id in (". join (",", (map {$_->dbID} @{$mlss_arrayref})) . ")";

  $constraint .= " AND hm.member_id = " . $member->dbID;

  # See in fetch_all_by_Member what is this internal variable for
  $self->{'_this_one_first'} = $member->stable_id;

  return $self->generic_fetch($constraint, $join);
}

=head2 fetch_all_by_Member_MethodLinkSpeciesSet

  Arg [1]    : Bio::EnsEMBL::Compara::Member $member
  Arg [2]    : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss
  Example    : $homologies = $HomologyAdaptor->fetch_all_by_Member_MethodLinkSpeciesSet($member, $mlsss);
  Description: fetch the homology relationships for a given $member and $mlss.
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all_by_Member_MethodLinkSpeciesSet {
  my ($self, $member, $method_link_species_set) = @_;

  unless ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    throw("The argument must be a Bio::EnsEMBL::Compara::Member object, not $member");
  }
  #$member = $member->get_canonical_Member;

  throw("method_link_species_set arg is required\n")
    unless ($method_link_species_set);

  my $join = [[['homology_member', 'hm'], 'h.homology_id = hm.homology_id']];
  my $constraint =  " h.method_link_species_set_id =" . $method_link_species_set->dbID;

  $constraint .= " AND hm.member_id = " . $member->dbID;

  # See in fetch_all_by_Member what is this internal variable for
  $self->{'_this_one_first'} = $member->stable_id;

  return $self->generic_fetch($constraint, $join);
}


=head2 fetch_by_Member_Member_method_link_type

  Arg [1]    : Bio::EnsEMBL::Compara::Member $member
  Arg [2]    : Bio::EnsEMBL::Compara::Member $member
  Arg [3]    : string $method_link_type
  Example    : $homologies = $HomologyAdaptor->fetch_by_Member_Member_method_link_type(
                   $member1->gene_member, $member2->gene_member, "ENSEMBL_ORTHOLOGUES");
  Description: fetch the homology relationships where the given member pair is implicated
               in a relationship of the type defined by $method_link_type.
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_by_Member_Member_method_link_type {
  my ($self, $member1, $member2, $method_link_type) = @_;

  unless ($member1->stable_id ne $member2->stable_id) {
    throw("The members should be different");
  }
  unless ($member1->isa('Bio::EnsEMBL::Compara::Member')) {
    throw("The argument must be a Bio::EnsEMBL::Compara::Member object, not $member1");
  }
  unless ($member2->isa('Bio::EnsEMBL::Compara::Member')) {
    throw("The argument must be a Bio::EnsEMBL::Compara::Member object, not $member2");
  }

  $method_link_type = 'ENSEMBL_ORTHOLOGUES' unless (defined($method_link_type));
  my $genome_dbs = [$member1->genome_db, $member2->genome_db];
  if ($member1->genome_db_id == $member2->genome_db_id) {
    $method_link_type = 'ENSEMBL_PARALOGUES';
    $genome_dbs = [$member1->genome_db];
  }
  my $mlssa = $self->db->get_MethodLinkSpeciesSetAdaptor;
  my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type,$genome_dbs);

  unless (defined($mlss)) {
    warning("There is no $method_link_type data stored in the database for " . $member1->genome_db->name . " and " . $member2->genome_db->name . "\n");
    return [];
  }

  #$member1 = $member1->get_canonical_Member;
  #$member2 = $member2->get_canonical_Member;

  #  my $join = [[['homology_member', 'hm'], 'h.homology_id = hm.homology_id']];
  my $join = [[['homology_member', 'hm1'], 'h.homology_id = hm1.homology_id'],[['homology_member', 'hm2'], 'h.homology_id = hm2.homology_id']];
  my $constraint =  " h.method_link_species_set_id =" . $mlss->dbID;

  $constraint .= " AND hm1.member_id = " . $member1->dbID;
  $constraint .= " AND hm2.member_id = " . $member2->dbID;
#  $constraint .= " AND hm1.member_id<hm2.member_id ";

  # See in fetch_all_by_Member what is this internal variable for
  $self->{'_this_one_first'} = $member1->stable_id;

  return $self->generic_fetch($constraint, $join);
}

=head2 fetch_by_Member_id_Member_id

  Arg [1]    : int $member_id1
  Arg [2]    : int $member_id2
  Example    : $homologies = $HomologyAdaptor->fetch_by_Member_id_Member_id(
                   $member_id1, $member_id2);
  Description: fetch the homology relationships for a given member_id pair
  Returntype : a Bio::EnsEMBL::Compara::Homology object
  Exceptions : none
  Caller     : 

=cut

sub fetch_by_Member_id_Member_id {
  my ($self, $member_id1, $member_id2,$allow_duplicates) = @_;

  unless ($member_id1 ne $member_id2) {
    throw("The members should be different");
  }
  my $join = [[['homology_member', 'hm1'], 'h.homology_id = hm1.homology_id'],[['homology_member', 'hm2'], 'h.homology_id = hm2.homology_id']];

  my $constraint .= " hm1.member_id = " . $member_id1;
  $constraint .= " AND hm2.member_id = " . $member_id2;

  # See in fetch_all_by_Member what is this internal variable for
  $self->{'_this_one_first'} = $member_id1;

  my $homology = $self->generic_fetch($constraint, $join);

  return undef unless (defined $homology || 0 == scalar @$homology);

  #my $pmember_id1 = $self->db_get_MemberAdaptor->fetch_canonical_member_for_gene_member_id($member_id1)->dbID;
  #my $pmember_id2 = $self->db_get_MemberAdaptor->fetch_canonical_member_for_gene_member_id($member_id2)->dbID;

  #return $self->fetch_by_PMember_id_PMember_id($pmember_id1, $pmember_id2, $allow_duplicates);
  return shift @{$homology};
}

=head2 fetch_by_PMember_id_PMember_id

  Arg [1]    : int $member_id1
  Arg [2]    : int $member_id2
  Example    : $homologies = $HomologyAdaptor->fetch_by_Member_id_Member_id(
                   $member_id1, $member_id2);
  Description: fetch the homology relationships for a given peptide_member_id pair
  Returntype : a Bio::EnsEMBL::Compara::Homology object
  Exceptions : none
  Caller     : 

=cut

sub fetch_by_PMember_id_PMember_id {
  my ($self, $member_id1, $member_id2,$allow_duplicates) = @_;

  unless ($member_id1 ne $member_id2) {
    throw("The members should be different");
  }
  my $join = [[['homology_member', 'hm1'], 'h.homology_id = hm1.homology_id'],[['homology_member', 'hm2'], 'h.homology_id = hm2.homology_id']];

  my $constraint .= " hm1.peptide_member_id = " . $member_id1;
  $constraint .= " AND hm2.peptide_member_id = " . $member_id2;

  # See in fetch_by_PMember what is this internal variable for
  $self->{'_this_one_first'} = $member_id1;

  my $homology = $self->generic_fetch($constraint, $join);

  return undef unless (defined $homology || 0 == scalar @$homology);

  # At production time, we may have more than one entry due to the
  # OtherParalogs code, so we allow fetching with the extra parameter,
  # but the duplicity is cleaned up afterwards
  if (1 < scalar @$homology && !defined($allow_duplicates)) {
    throw("Returns more than one element");
  }

  return shift @{$homology};
}


=head2 fetch_all_by_MethodLinkSpeciesSet

  Arg [1]    : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss or its dbID
  Arg [-ORTHOLOGY_TYPE] (opt)
             : string: the type of homology that have to be fetched
  Arg [-SUBTYPE] (opt)
             : string: the subtype (taxonomy level) of the homologies that have
                       to be fetched
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

    my ($orthology_type, $subtype) = rearrange([qw(ORTHOLOGY_TYPE SUBTYPE)], @args);

    my $mlss_id = (ref($mlss) ? $mlss->dbID : $mlss);
    my $constraint =  ' h.method_link_species_set_id = ?';
    $self->bind_param_generic_fetch($mlss_id, SQL_INTEGER);

    if (defined $orthology_type) {
        $constraint .= ' AND h.description = ?';
        $self->bind_param_generic_fetch($orthology_type, SQL_VARCHAR);
    }
    if (defined $subtype) {
        $constraint .= ' AND h.subtype = ?';
        $self->bind_param_generic_fetch($subtype, SQL_VARCHAR);
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

  my $constraint =  " h.tree_node_id =" . $tree_node_id;

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
    } else {
        push @all_mlss, $mlssa->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$genome_db_id1, $genome_db_id2]);
        push @all_mlss, $mlssa->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$genome_db_id1, $genome_db_id2]);
    }

    my $constraint =  "h.method_link_species_set_id IN (". join (",", (map {$_->dbID} @all_mlss)) . ")";

    return $self->generic_fetch($constraint);
}


=head2 fetch_all_by_MethodLinkSpeciesSet_orthology_type

  Description: DEPRECATED. Use fetch_all_by_MethodLinkSpeciesSet($method_link_species_set, -orthology_type => $orthology_type) instead

=cut

sub fetch_all_by_MethodLinkSpeciesSet_orthology_type {
    my ($self, $method_link_species_set, $orthology_type) = @_;
    deprecate('Use fetch_all_by_MethodLinkSpeciesSet($method_link_species_set, -orthology_type => $orthology_type) instead. fetch_all_by_MethodLinkSpeciesSet_orthology_type() will be removed in release 70.');
    return $self->fetch_all_by_MethodLinkSpeciesSet($method_link_species_set, -orthology_type => $orthology_type);
}


=head2 fetch_all_by_MethodLinkSpeciesSet_orthology_type_subtype

  Description: DEPRECATED. Use fetch_all_by_MethodLinkSpeciesSet($method_link_species_set, -orthology_type => $orthology_type, -subtype => $subtype) instead

=cut

sub fetch_all_by_MethodLinkSpeciesSet_orthology_type_subtype {
    my ($self, $method_link_species_set, $orthology_type, $subtype) = @_;
    deprecate('Use fetch_all_by_MethodLinkSpeciesSet($method_link_species_set, -orthology_type => $orthology_type, -subtype => $subtype) instead. fetch_all_by_MethodLinkSpeciesSet_orthology_type_subtype() will be removed in release 70.');
    return $self->fetch_all_by_MethodLinkSpeciesSet($method_link_species_set, -orthology_type => $orthology_type, -subtype => $subtype);
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
    my ($self, $member, $boundary_species) = @_;

    assert_ref($member, 'Bio::EnsEMBL::Compara::Member');
    assert_ref($boundary_species, 'Bio::EnsEMBL::Compara::NCBITaxon');

    my $all_paras = $self->fetch_all_by_Member_MethodLinkSpeciesSet(
        $member,
        $self->db->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$member->genome_db]),
    );
    return $self->_filter_paralogues_by_ancestral_species($all_paras, $member->genome_db, $boundary_species, 1);
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
    my ($self, $member, $boundary_species) = @_;

    assert_ref($member, 'Bio::EnsEMBL::Compara::Member');
    assert_ref($boundary_species, 'Bio::EnsEMBL::Compara::NCBITaxon');

    my $all_paras = $self->fetch_all_by_Member_MethodLinkSpeciesSet(
        $member,
        $self->db->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$member->genome_db]),
    );
    return $self->_filter_paralogues_by_ancestral_species($all_paras, $member->genome_db, $boundary_species, 0);
}


=head2 fetch_all_in_paralogues_from_GenomeDB_NCBITaxon

  Arg [1]    : species (Bio::EnsEMBL::Compara::GenomeDB)
  Arg [2]    : boundary_species (Bio::EnsEMBL::Compara::NCBITaxon)
  Example    : $homologies = $HomologyAdaptor->fetch_all_in_paralogues_from_GenomeDB_NCBITaxon
                    $human_genomedb, $chicken_genomdb->taxon);
  Description: fetch all the same species paralog of this species, that are more recent than
                the speciation even refered to by the boundary_species argument
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Caller     :

=cut

sub fetch_all_in_paralogues_from_GenomeDB_NCBITaxon {
    my ($self, $species, $boundary_species) = @_;

    assert_ref($species, 'Bio::EnsEMBL::Compara::GenomeDB');
    assert_ref($boundary_species, 'Bio::EnsEMBL::Compara::NCBITaxon');

    my $all_paras = $self->fetch_all_by_MethodLinkSpeciesSet(
        $self->db->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$species]),
    );

    return $self->_filter_paralogues_by_ancestral_species($all_paras, $species, $boundary_species, 1);
}


=head2 fetch_all_out_paralogues_from_GenomeDB_NCBITaxon

  Arg [1]    : species (Bio::EnsEMBL::Compara::GenomeDB)
  Arg [2]    : boundary_species (Bio::EnsEMBL::Compara::NCBITaxon)
  Example    : $homologies = $HomologyAdaptor->fetch_all_out_paralogues_from_GenomeDB_NCBITaxon
                    $human_genomedb, $chicken_genomdb->taxon);
  Description: fetch all the same species paralog of this species, that are older than
                the speciation even refered to by the boundary_species argument
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Caller     :

=cut

sub fetch_all_out_paralogues_from_GenomeDB_NCBITaxon {
    my ($self, $species, $boundary_species) = @_;

    assert_ref($species, 'Bio::EnsEMBL::Compara::GenomeDB');
    assert_ref($boundary_species, 'Bio::EnsEMBL::Compara::NCBITaxon');

    my $all_paras = $self->fetch_all_by_MethodLinkSpeciesSet(
        $self->db->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs('ENSEMBL_PARALOGUES', [$species]),
    );

    return $self->_filter_paralogues_by_ancestral_species($all_paras, $species, $boundary_species, 0);
}


# Convenience method to filter a list of homologies
sub _filter_paralogues_by_ancestral_species {
    my ($self, $all_paras, $species1, $species2, $in_out) = @_;

    assert_ref($species1, 'Bio::EnsEMBL::Compara::GenomeDB');
    assert_ref($species2, 'Bio::EnsEMBL::Compara::NCBITaxon');

    my $ncbi_a = $self->db->get_NCBITaxonAdaptor;

    # The last common ancestor of $species1 and $species2 defines the boundary
    my $lca =  $ncbi_a->fetch_first_shared_ancestor_indexed($species1->taxon, $species2);

    my @good_paralogues;
    foreach my $hom (@$all_paras) {

        # The taxon where the homology "appeared"
        my $ancspec = $ncbi_a->fetch_node_by_name($hom->subtype);
    
        # Compares the homology taxon to the boundary
        push @good_paralogues, $hom if $in_out xor ($ancspec eq $ncbi_a->fetch_first_shared_ancestor_indexed($lca, $ancspec));
    }

    return \@good_paralogues;
}


=head2 fetch_orthocluster_with_Member

  Arg [1]    : Bio::EnsEMBL::Compara::Member $gene_member (must be ENSEMBLGENE type)
  Example    : my ($homology_list, $gene_list) = 
                 $HomologyAdaptor->fetch_orthocluster_with_Member($gene_member);
  Description: do a recursive search starting from $gene_member to find the cluster of
               all connected genes and homologies via connected components clustering.
  Returntype : an array pair of array references.  
               First array_ref is the list of Homology objects in the cluster graph
	       Second array ref is the list of unique gene Members in the cluster
  Exceptions : none
  Caller     : 

=cut

sub fetch_orthocluster_with_Member {
  my $self = shift;
  my $gene_member = shift;
  
  my $ortho_set = {};
  my $member_set = {};
  $self->_recursive_get_orthocluster($gene_member, $ortho_set, $member_set, 0);

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
    
    foreach my $member (@{$homology->get_all_GeneMembers}) {
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
             h.subtype
             h.dn
             h.ds
             h.n
             h.s
             h.lnl
             h.threshold_on_ds
             h.ancestor_node_id
             h.tree_node_id);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my ($homology_id, $description, $dn, $ds, $n, $s, $lnl, $threshold_on_ds,
      $method_link_species_set_id, $subtype, $ancestor_node_id, $tree_node_id);

  $sth->bind_columns(\$homology_id, \$method_link_species_set_id,
                     \$description, \$subtype, \$dn, \$ds,
                     \$n, \$s, \$lnl, \$threshold_on_ds, \$ancestor_node_id, \$tree_node_id);

  my @homologies = ();
  
  while ($sth->fetch()) {
    push @homologies, Bio::EnsEMBL::Compara::Homology->new_fast({
            '_adaptor'                      => $self,           # field name NOT in sync with Bio::EnsEMBL::Storable
            '_dbID'                         => $homology_id,    # field name NOT in sync with Bio::EnsEMBL::Storable
            '_description'                  => $description,
            '_method_link_species_set_id'   => $method_link_species_set_id,
            '_subtype'                      => $subtype,
            '_dn'                           => $dn,
            '_ds'                           => $ds,
            '_n'                            => $n,
            '_s'                            => $s,
            '_lnl'                          => $lnl,
            '_threshold_on_ds'              => $threshold_on_ds,
            '_this_one_first'               => $self->{'_this_one_first'},
            '_ancestor_node_id'             => $ancestor_node_id,
            '_tree_node_id'                 => $tree_node_id,
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
  
  $hom->isa('Bio::EnsEMBL::Compara::Homology') ||
    throw("You have to store a Bio::EnsEMBL::Compara::Homology object, not a $hom");

  $hom->adaptor($self);

  if ( !defined $hom->method_link_species_set_id && defined $hom->method_link_species_set) {
    $self->db->get_MethodLinkSpeciesSetAdaptor->store($hom->method_link_species_set);
  }

  if (! defined $hom->method_link_species_set) {
    throw("Homology object has no set MethodLinkSpecies object. Can not store Homology object\n");
  } else {
    $hom->method_link_species_set_id($hom->method_link_species_set->dbID);
  }
  
  unless($hom->dbID) {
    my $sql = 'INSERT INTO homology (method_link_species_set_id, description, subtype, ancestor_node_id, tree_node_id) VALUES (?,?,?,?,?)';
    my $sth = $self->prepare($sql);
    $sth->execute($hom->method_link_species_set_id, $hom->description, $hom->subtype, $hom->ancestor_node_id, $hom->tree_node_id);
    $hom->dbID($sth->{'mysql_insertid'});
  }

  my $sql = 'INSERT IGNORE INTO homology_member (homology_id, member_id, peptide_member_id, cigar_line, perc_id, perc_pos, perc_cov) VALUES (?,?,?,?,?,?,?)';
  my $sth = $self->prepare($sql);
  foreach my $member(@{$hom->get_all_Members}) {
    # Stores the member if not yet stored
    $self->db->get_MemberAdaptor->store($member) unless (defined $member->dbID);
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

  throw("You have to store a Bio::EnsEMBL::Compara::Homology object, not a $hom")
    unless($hom->isa('Bio::EnsEMBL::Compara::Homology'));

  throw("homology object must have dbID")
    unless ($hom->dbID);
  # We use here internal hash key for _dn and _ds because the dn and ds method call
  # do some filtering based on the threshold_on_ds.
  unless(defined $hom->{'_dn'} and defined $hom->{'_ds'} and defined $hom->n and defined $hom->lnl and defined $hom->s) {
    warn("homology needs valid dn, ds, n, s, and lnl values to store");
    return $self;
  }

  my $sql = "UPDATE homology SET dn=?, ds=?, n=?, s=?, lnl=?";

  if (defined $hom->threshold_on_ds) {
    $sql .= ", threshold_on_ds=?";
  }

  $sql .= " WHERE homology_id=?";

  my $sth = $self->prepare($sql);

  if (defined $hom->threshold_on_ds) {
    $sth->execute($hom->{'_dn'},$hom->{'_ds'},$hom->n, $hom->s, $hom->lnl, $hom->threshold_on_ds, $hom->dbID);
  } else {
    $sth->execute($hom->{'_dn'},$hom->{'_ds'},$hom->n, $hom->s, $hom->lnl, $hom->dbID);
  }
  $sth->finish();

  return $self;
}


=head2 fetch_all_orphans_by_GenomeDB

 Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
 Example    : $HomologyAdaptor->fetch_all_orphans_by_GenomeDB($genome_db);
 Description: fetch the members for a genome_db that have no homologs in the database
 Returntype : an array reference of Bio::EnsEMBL::Compara::Member objects
 Exceptions : when isa if Arg [1] is not Bio::EnsEMBL::Compara::GenomeDB
 Caller     : general

=cut


sub fetch_all_orphans_by_GenomeDB {
  my $self = shift;
  my $gdb = shift;

  throw("genome_db arg is required\n")
    unless ($gdb);

  my $sql = 'SELECT mg.member_id FROM member mg LEFT JOIN homology_member hm ON (mg.canonical_member_id = hm.member_id) WHERE hm.member_id IS NULL AND mg.genome_db_id = ?';
  my $sth = $self->dbc->prepare($sql);
  $sth->execute($gdb->dbID);
  my $ma = $self->db->get_MemberAdaptor;
  my @members;
  while ( my $member_id  = $sth->fetchrow ) {
    my $member = $ma->fetch_by_dbID($member_id);
    push @members, $member;
  }
  return \@members;
}


1;
