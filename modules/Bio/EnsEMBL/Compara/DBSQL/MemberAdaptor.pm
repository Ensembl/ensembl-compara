package Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 list_internal_ids

  Arg        : None
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub list_internal_ids {
  my $self = shift;
  
  my @tables = $self->_tables;
  my ($name, $syn) = @{$tables[0]};
  my $sql = "SELECT ${syn}.${name}_id from ${name} ${syn}";
  
  my $sth = $self->prepare($sql);
  $sth->execute;  
  
  my $internal_id;
  $sth->bind_columns(\$internal_id);

  my @internal_ids;
  while ($sth->fetch()) {
    push @internal_ids, $internal_id;
  }

  $sth->finish;

  return \@internal_ids;
}

=head2 fetch_by_dbID

  Arg [1]    : int $id
               the unique database identifier for the feature to be obtained
  Example    : $feat = $adaptor->fetch_by_dbID(1234);
  Description: Returns the feature created from the database defined by the
               the id $id.
  Returntype : Bio::EnsEMBL::SeqFeature
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_by_dbID{
  my ($self,$id) = @_;

  unless(defined $id) {
    $self->throw("fetch_by_dbID must have an id");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "${syn}.${name}_id = $id";

  #return first element of _generic_fetch list
  my ($obj) = @{$self->_generic_fetch($constraint)};
  return $obj;
}

=head2 fetch_by_source_stable_id

  Arg [1]    : string $source_name
  Arg [2]    : string $stable_id
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_by_source_stable_id {
  my ($self,$source_name, $stable_id) = @_;

  unless(defined $source_name) {
    $self->throw("fetch_by_source_stable_id must have an source_name");
  }
  unless(defined $stable_id) {
    $self->throw("fetch_by_source_stable_id must have an stable_id");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};
  my ($source_table, $source_syn) = @{$tabs[1]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "${source_syn}.source_name = '$source_name' AND ${syn}.stable_id = '$stable_id'";

  #return first element of _generic_fetch list
  my ($obj) = @{$self->_generic_fetch($constraint)};
  return $obj;
}

=head2 fetch_all

  Arg        : None
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_all {
  my $self = shift;

  return $self->_generic_fetch();
}

=head2 fetch_by_source

  Arg [1]    : string $source_name
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_by_source {
  my ($self,$source_name) = @_;

  $self->throw("source_name arg is required\n")
    unless ($source_name);

  my $constraint = "s.source_name = '$source_name'";

  return $self->_generic_fetch($constraint);
}

=head2 fetch_by_source_taxon

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_by_source_taxon {
  my ($self,$source_name,$taxon_id) = @_;

  $self->throw("source_name and taxon_id args are required") 
    unless($source_name && $taxon_id);

  my $constraint = "s.source_name = '$source_name' and m.taxon_id = $taxon_id";

  return $self->_generic_fetch($constraint);
}

=head2 fetch_by_relation

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_by_relation {
  my ($self, $relation) = @_;

  my $join;
  my $constraint;

  $self->throw() 
    unless (defined $relation && ref $relation);
  
  if ($relation->isa('Bio::EnsEMBL::Compara::Family')) {
    my $family_id = $relation->dbID;
    $constraint = "fm.family_id = $family_id";
    my $extra_columns = [qw(fm.family_id
                            fm.member_id
                            fm.cigar_line)];
    $join = [[['family_member', 'fm'], 'm.member_id = fm.member_id', $extra_columns]];
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
    my $domain_id = $relation->dbID;
    $constraint = "dm.domain_id = $domain_id";
    my $extra_columns = [qw(dm.domain_id
                            dm.member_id
                            dm.member_start
                            dm.member_end)];
    $join = [[['domain_member', 'dm'], 'm.member_id = dm.member_id', $extra_columns]];
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
    my $homology_id = $relation->dbID;
    $constraint .= "hm.homology_id = $homology_id";
    my $extra_columns = [qw(hm.homology_id
                            hm.member_id
                            hm.peptide_member_id
                            hm.cigar_line
                            hm.cigar_start
                            hm.cigar_end
                            hm.perc_cov
                            hm.perc_id
                            hm.perc_pos)];
    $join = [[['homology_member', 'hm'], 'm.member_id = hm.member_id', $extra_columns]];
  }
  else {
    $self->throw();
  }

  return $self->_generic_fetch($constraint, $join);
}

=head2 fetch_by_relation_source

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_by_relation_source {
  my ($self, $relation, $source_name) = @_;

  my $join;
  my $constraint = "s.source_name = '$source_name'";

  $self->throw() 
    unless (defined $relation && ref $relation);
  
  $self->throw("source_name arg is required\n")
    unless ($source_name);

  if ($relation->isa('Bio::EnsEMBL::Compara::Family')) {
    my $family_id = $relation->dbID;
    $constraint .= " AND fm.family_id = $family_id";
    my $extra_columns = [qw(fm.family_id
                            fm.member_id
                            fm.cigar_line)];
    $join = [[['family_member', 'fm'], 'm.member_id = fm.member_id', $extra_columns]];
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
    my $domain_id = $relation->dbID;
    $constraint .= " AND dm.domain_id = $domain_id";
    my $extra_columns = [qw(dm.domain_id
                            dm.member_id
                            dm.member_start
                            dm.member_end)];
    $join = [[['domain_member', 'dm'], 'm.member_id = dm.member_id', $extra_columns]];
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
    my $homology_id = $relation->dbID;
    $constraint .= " AND hm.homology_id = $homology_id";
    my $extra_columns = [qw(hm.homology_id
                            hm.member_id
                            hm.peptide_member_id
                            hm.cigar_line
                            hm.cigar_start
                            hm.cigar_end
                            hm.perc_cov
                            hm.perc_id
                            hm.perc_pos)];
    $join = [[['homology_member', 'hm'], 'm.member_id = hm.member_id', $extra_columns]];
  }
  else {
    $self->throw();
  }
  return $self->_generic_fetch($constraint, $join);
}

=head2 fetch_by_relation_source_taxon

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_by_relation_source_taxon {
  my ($self, $relation, $source_name, $taxon_id) = @_;

  my $join;
  my $constraint = "s.source_name = '$source_name' AND m.taxon_id = $taxon_id";

  $self->throw()
    unless (defined $relation && ref $relation);
  
  $self->throw("source_name and taxon_id args are required") 
    unless($source_name && $taxon_id);

  if ($relation->isa('Bio::EnsEMBL::Compara::Family')) {
    my $family_id = $relation->dbID;
    $constraint .= " AND fm.family_id = $family_id";
    my $extra_columns = [qw(fm.family_id
                         fm.member_id
                         fm.cigar_line)];
    $join = [[['family_member', 'fm'], 'm.member_id = fm.member_id', $extra_columns]];
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
    my $domain_id = $relation->dbID;
    $constraint .= " AND dm.domain_id = $domain_id";
    my $extra_columns = [qw(dm.domain_id
                         dm.member_id
                         dm.member_start
                         dm.member_end)];
    $join = [[['domain_member', 'dm'], 'm.member_id = dm.member_id', $extra_columns]];
  }
#  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
#  }
  else {
    $self->throw();
  }
  return $self->_generic_fetch($constraint, $join);
}

#
# INTERNAL METHODS
#
###################

=head2 _generic_fetch

  Arg [1]    : (optional) string $constraint
               An SQL query constraint (i.e. part of the WHERE clause)
  Arg [2]    : (optional) string $logic_name
               the logic_name of the analysis of the features to obtain
  Example    : $fts = $a->_generic_fetch('contig_id in (1234, 1235)', 'Swall');
  Description: Performs a database fetch and returns feature objects in
               contig coordinates.
  Returntype : listref of Bio::EnsEMBL::SeqFeature in contig coordinates
  Exceptions : none
  Caller     : BaseFeatureAdaptor, ProxyDnaAlignFeatureAdaptor::_generic_fetch

=cut
  
sub _generic_fetch {
  my ($self, $constraint, $join) = @_;
  
  my @tables = $self->_tables;
  my $columns = join(', ', $self->_columns());
  
  if ($join) {
    foreach my $single_join (@{$join}) {
      my ($tablename, $condition, $extra_columns) = @{$single_join};
      if ($tablename && $condition) {
        push @tables, $tablename;
        
        if($constraint) {
          $constraint .= " AND $condition";
        } else {
          $constraint = " $condition";
        }
      } 
      if ($extra_columns) {
        $columns .= ", " . join(', ', @{$extra_columns});
      }
    }
  }
      
  #construct a nice table string like 'table1 t1, table2 t2'
  my $tablenames = join(', ', map({ join(' ', @$_) } @tables));

  my $sql = "SELECT $columns FROM $tablenames";

  my $default_where = $self->_default_where_clause;
  my $final_clause = $self->_final_clause;

  #append a where clause if it was defined
  if($constraint) { 
    $sql .= " WHERE $constraint ";
    if($default_where) {
      $sql .= " AND $default_where ";
    }
  } elsif($default_where) {
    $sql .= " WHERE $default_where ";
  }

  #append additional clauses which may have been defined
  $sql .= " $final_clause";

  # warn $sql;
  my $sth = $self->prepare($sql);
  $sth->execute;  

#  print STDERR $sql,"\n";

  return $self->_objs_from_sth($sth);
}

sub _tables {
  my $self = shift;

  return (['member', 'm'], ['source', 's']);
}

sub _columns {
  my $self = shift;

  return qw (m.member_id
             m.stable_id
             m.taxon_id
             m.genome_db_id
             m.description
             m.chr_name
             m.chr_start
             m.chr_end
             m.sequence
             s.source_id
             s.source_name);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @members = ();

  while ($sth->fetch()) {
    my ($member,$attribute);
    $member = Bio::EnsEMBL::Compara::Member->new_fast
      ({'_dbID' => $column{'member_id'},
        '_stable_id' => $column{'stable_id'},
        '_taxon_id' => $column{'taxon_id'},
        '_genome_db_id' => $column{'genome_db_id'},
        '_description' => $column{'description'},
        '_chr_name' => $column{'chr_name'},
        '_chr_start' => $column{'chr_start'},
        '_chr_end' => $column{'chr_end'},
        '_sequence' => $column{'sequence'},
        '_source_id' => $column{'source_id'},
        '_source_name' => $column{'source_name'},
        '_adaptor' => $self});

    my @_columns = $self->_columns;
    if (scalar keys %column > scalar @_columns) {
      $attribute = new Bio::EnsEMBL::Compara::Attribute;
      $attribute->member_id($column{'member_id'});
      foreach my $autoload_method (keys %column) {
        next if (grep /$autoload_method/,  @_columns);
        $attribute->$autoload_method($column{$autoload_method});
      }
    }
    if (defined $attribute) {
      push @members, [$member, $attribute];
    } else {
      push @members, $member;
    }
  }
  return \@members
}

sub _default_where_clause {
  my $self = shift;

  return 'm.source_id = s.source_id';
}

sub _final_clause {
  my $self = shift;

  return '';
}

#
# STORE METHODS
#
################

=head2 store

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub store {
  my ($self,$member) = @_;

  unless($member->isa('Bio::EnsEMBL::Compara::Member')) {
    $self->throw(
      "member arg must be a [Bio::EnsEMBL::Compara::Member]"
    . "not a $member");
  }
  
  my $already_stored_member = $self->fetch_by_source_stable_id($member->source_name,$member->stable_id); 
  if (defined $already_stored_member) {
    $member->adaptor($already_stored_member->adaptor);
    $member->dbID($already_stored_member->dbID);
    if (defined $member->taxon) {
      $self->db->get_TaxonAdaptor->store_if_needed($member->taxon);
    }
    return $member->dbID;
  }

  $member->source_id($self->store_source($member->source_name));

  my $sth = 
    $self->prepare("INSERT INTO member (stable_id,source_id, 
                                taxon_id, genome_db_id, description,
                                chr_name, chr_start, chr_end, sequence) 
                    VALUES (?,?,?,?,?,?,?,?,?)");

  $sth->execute($member->stable_id,
		$member->source_id, 
		$member->taxon_id,
		$member->genome_db_id,
                $member->description,
		$member->chr_name, 
		$member->chr_start,
		$member->chr_end,
		$member->sequence);

  $member->dbID( $sth->{'mysql_insertid'} );
  $member->adaptor($self);
  if (defined $member->taxon) {
    $self->db->get_TaxonAdaptor->store_if_needed($member->taxon);
  }
  return $member->dbID;
}

sub update_sequence {
  my ($self, $member) = @_;

  my $sql = "UPDATE member SET sequence = ? WHERE member_id = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($member->sequence, $member->dbID);
}

=head2 store_source

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub store_source {
  my ($self,$source_name) = @_;
  
  my $sql = "SELECT source_id FROM source WHERE source_name = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($source_name);
  my $rowhash = $sth->fetchrow_hashref;
  if ($rowhash->{source_id}) {
    return $rowhash->{source_id};
  } else {
    $sql = "INSERT INTO source (source_name) VALUES (?)";
    $sth = $self->prepare($sql);
    $sth->execute($source_name);
    return $sth->{'mysql_insertid'};
  }
}

1;






