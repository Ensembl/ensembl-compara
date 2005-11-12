package Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;
use Bio::EnsEMBL::Utils::Exception;

our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor);

=head2 fetch_by_Member

 Arg [1]    : Bio::EnsEMBL::Compara::Member $member
 Example    : $homologies = $HomologyAdaptor->fetch_by_Member($member);
 Description: fetch the homology relationships where the given member is implicated
 Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
 Exceptions : none
 Caller     : general

=cut

sub fetch_by_Member {
  # to be renamed fetch_all_by_Member
  my ($self, $member) = @_;

  my $join = [[['homology_member', 'hm'], 'h.homology_id = hm.homology_id']];
  my $constraint = "hm.member_id = " .$member->dbID;;

  # This internal variable is used by add_Member_Attribute method 
  # in Bio::EnsEMBL::Compara::BaseRelation to make sure that the first element
  # of the member array is the one that has been used by the user to fetch the
  # homology object
  $self->{'_this_one_first'} = $member->stable_id;

  return $self->generic_fetch($constraint, $join);
}


=head2 fetch_by_Member_paired_species

  Arg [1]    : Bio::EnsEMBL::Compara::Member $member
  Arg [2]    : string $species
               e.g. "Mus_musculus" or "Mus musculus"
  Example    : $homologies = $HomologyAdaptor->fetch_by_Member($member, "Mus_musculus");
  Description: fetch the homology relationships where the given member is implicated
               in pair with another member from the paired species. Member species and
               paired species should be different.
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_by_Member_paired_species {
  # to be renamed fetch_all_by_Member_paired_species
  my ($self, $member, $species) = @_;

  $species =~ tr/_/ /;

  my $join = [[['homology_member', 'hm'], 'h.homology_id = hm.homology_id']];
  my $constraint = "hm.member_id = " .$member->dbID;

  my $sth =  $self->generic_fetch_sth($constraint, $join);
  
  my ($homology_id, $stable_id, $method_link_species_set_id, $description, $dn, 
      $ds, $n, $s, $lnl, $threshold_on_ds, $subtype);
  
  $sth->bind_columns(\$homology_id, \$stable_id, \$method_link_species_set_id, \$description, \$subtype,
                     \$dn, \$ds, \$n, \$s, \$lnl, \$threshold_on_ds);

  my @homology_ids = ();
  
  while ($sth->fetch()) {
    push @homology_ids, $homology_id; 
  }

  return [] unless (scalar @homology_ids);
  
  $join = [[['homology_member', 'hm'], 'h.homology_id = hm.homology_id'],
           [['member', 'm'], 'hm.member_id = m.member_id'],
           [['genome_db', 'gdb'], 'm.genome_db_id = gdb.genome_db_id']];

  my $comma_joined_homology_ids = join(',',@homology_ids);
  $constraint = "gdb.name = '$species' AND hm.homology_id in ($comma_joined_homology_ids) AND hm.member_id != " . $member->dbID;
  
  # See in fetch_by_Member what is this internal variable for
  $self->{'_this_one_first'} = $member->stable_id;

  return $self->generic_fetch($constraint, $join);
}


sub fetch_all_by_Member_method_link_type {
  my ($self, $member, $method_link_type) = @_;

  unless ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    throw("The argument must be a Bio::EnsEMBL::Compara::Member object, not $member");
  }

  throw("method_link_type arg is required\n")
    unless ($method_link_type);

  my $mlssa = $self->db->get_MethodLinkSpeciesSetAdaptor;
  my $mlss_arrayref = $mlssa->fetch_all_by_method_link_type_genome_db_id($method_link_type,$member->genome_db_id);
  
  unless (scalar @{$mlss_arrayref}) {
    warning("There is no $method_link_type data stored in the database for " . $member->genome_db->name . "\n");
    return [];
  }

  my $join = [[['homology_member', 'hm'], 'h.homology_id = hm.homology_id']];
  my $constraint =  " h.method_link_species_set_id in (". join (",", (map {$_->dbID} @{$mlss_arrayref})) . ")";

  $constraint .= " AND hm.member_id = " . $member->dbID;

  # See in fetch_by_Member what is this internal variable for
  $self->{'_this_one_first'} = $member->stable_id;

  return $self->generic_fetch($constraint, $join);
}

sub fetch_all_by_Member_MethodLinkSpeciesSet {
  my ($self, $member, $method_link_species_set) = @_;

  unless ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    throw("The argument must be a Bio::EnsEMBL::Compara::Member object, not $member");
  }

  throw("method_link_species_set arg is required\n")
    unless ($method_link_species_set);

#  my $mlssa = $self->db->get_MethodLinkSpeciesSetAdaptor;
#  my $mlss_arrayref = $mlssa->fetch_all_by_method_link_type_genome_db_id($method_link_type,$member->genome_db_id);
  
#  unless (scalar @{$mlss_arrayref}) {
#    warning("There is no $method_link_type data stored in the database for " . $member->genome_db->name . "\n");
#    return [];
#  }

  my $join = [[['homology_member', 'hm'], 'h.homology_id = hm.homology_id']];
  my $constraint =  " h.method_link_species_set_id =" . $method_link_species_set->dbID;

  $constraint .= " AND hm.member_id = " . $member->dbID;

  # See in fetch_by_Member what is this internal variable for
  $self->{'_this_one_first'} = $member->stable_id;

  return $self->generic_fetch($constraint, $join);
}


=head2 fetch_all_by_MethodLinkSpeciesSet

  Arg [1]    : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss
  Example    : $homologies = $HomologyAdaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);
  Description: fetch all the homology relationships for the given MethodLinkSpeciesSet
               Since each species pair Orthologue analysis is given a unique 
	       MethodLinkSpeciesSet, this method can be used to grab all the 
	       orthologues for a species pair.
  Returntype : an array reference of Bio::EnsEMBL::Compara::Homology objects
  Exceptions : none
  Caller     : 

=cut

sub fetch_all_by_MethodLinkSpeciesSet {
  my ($self, $method_link_species_set) = @_;

  throw("method_link_species_set arg is required\n")
    unless ($method_link_species_set);

  my $constraint =  " h.method_link_species_set_id =" . $method_link_species_set->dbID;

  return $self->generic_fetch($constraint);
}


sub fetch_all_by_genome_pair {
  my ($self, $genome_db_id1, $genome_db_id2) = @_;

  my $join = [ [['homology_member', 'hm1'], 'h.homology_id = hm1.homology_id'],
               [['member', 'm1'], 'hm1.member_id = m1.member_id'],
               [['homology_member', 'hm2'], 'h.homology_id = hm2.homology_id'],
               [['member', 'm2'], 'hm2.member_id = m2.member_id'],
             ];

  my $constraint = "m1.genome_db_id= $genome_db_id1";
  $constraint .= " AND m2.genome_db_id = $genome_db_id2";

  $self->{'_this_one_first'} = undef; #not relevant

  return $self->generic_fetch($constraint, $join);
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

  $gene->print_member("query gene\n") if($debug);
  $member_set->{$gene->dbID} = $gene;

  my $homologies = $self->fetch_by_Member($gene);
  printf("fetched %d homologies\n", scalar(@$homologies)) if($debug);

  foreach my $homology (@{$homologies}) {
    next if($ortho_set->{$homology->dbID});
    
    foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
      my ($member, $attribute) = @{$member_attribute};
      next if($member->dbID == $gene->dbID); #skip query gene
      $member->print_member if($debug);

      printf("adding homology_id %d to cluster\n", $homology->dbID) if($debug);
      $ortho_set->{$homology->dbID} = $homology;
      $self->_recursive_get_orthocluster($member, $ortho_set, $member_set, $debug);
    }
  }
  printf("done with search query %s\n", $gene->stable_id) if($debug);
}



#
# internal methods
#
###################

# internal methods used in multiple calls above to build homology objects from table data  

sub _tables {
  my $self = shift;

  return (['homology', 'h']);
}

sub _columns {
  my $self = shift;

  return qw (h.homology_id
             h.stable_id
             h.method_link_species_set_id
             h.description
             h.subtype
             h.dn
             h.ds
             h.n
             h.s
             h.lnl
             h.threshold_on_ds);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my ($homology_id, $stable_id, $description, $dn, $ds, $n, $s, $lnl, $threshold_on_ds,
      $method_link_species_set_id, $subtype);

  $sth->bind_columns(\$homology_id, \$stable_id, \$method_link_species_set_id,
                     \$description, \$subtype, \$dn, \$ds,
                     \$n, \$s, \$lnl, \$threshold_on_ds);

  my @homologies = ();
  
  while ($sth->fetch()) {
    push @homologies, Bio::EnsEMBL::Compara::Homology->new_fast
      ({'_dbID' => $homology_id,
       '_stable_id' => $stable_id,
       '_description' => $description,
       '_method_link_species_set_id' => $method_link_species_set_id,
       '_subtype' => $subtype,
       '_dn' => $dn,
       '_ds' => $ds,
       '_n' => $n,
       '_s' => $s,
       '_lnl' => $lnl,
       '_threshold_on_ds' => $threshold_on_ds,
       '_adaptor' => $self,
       '_this_one_first' => $self->{'_this_one_first'}});
  }
  
  return \@homologies;  
}

sub _default_where_clause {
  my $self = shift;
  return '';
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
    my $sql = "INSERT INTO homology (stable_id, method_link_species_set_id, description, subtype) VALUES (?,?,?,?)";
    my $sth = $self->prepare($sql);
    $sth->execute($hom->stable_id,$hom->method_link_species_set_id,$hom->description, $hom->subtype);
    $hom->dbID($sth->{'mysql_insertid'});
  }

  foreach my $member_attribute (@{$hom->get_all_Member_Attribute}) {   
    $self->store_relation($member_attribute, $hom);
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

# DEPRECATED METHODS
####################

sub fetch_by_Member_Homology_source {
  my ($self, $member, $source_name) = @_;
  deprecate("fetch_by_Member_Homology_source method is deprecated. Calling 
fetch_all_by_Member_method_link_type instead");
  return $self->fetch_all_by_Member_method_link_type($member, $source_name);
}

1;
