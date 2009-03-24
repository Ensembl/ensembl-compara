=head1 NAME

Bio::EnsEMBL::Compara::Production::DBSQL::AnchorAlignAdaptor

=head1 SYNOPSIS

=head1 CONTACT

Jessica Severin : jessica@ebi.ac.uk

=head1 APPENDIX

=cut


package Bio::EnsEMBL::Compara::DBSQL::AnchorAlignAdaptor;

use Data::Dumper;

use Bio::EnsEMBL::Compara::Production::EPOanchors::AnchorAlign;

use Bio::EnsEMBL::Hive::DBSQL::AnalysisDataAdaptor;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


#############################
#
# store methods
#
#############################

=head2 store

  Arg[1]     : one or many DnaFragChunk objects
  Example    : $adaptor->store($chunk);
  Description: stores DnaFragChunk objects into compara database
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub store {
  my ($self, $anchor_align)  = @_;

  throw() unless($anchor_align);
  throw() unless(UNIVERSAL::isa($anchor_align, 'Bio::EnsEMBL::Compara::Production::AnchorAlign'));

  my $query = qq{
  INSERT INTO anchor_align
    (method_link_species_set_id, anchor_id, dnafrag_id, dnafrag_start,
    dnafrag_end, dnafrag_strand, score, num_of_organisms, num_of_sequences)
  VALUES (?,?,?,?,?,?,?,?,?)};

	

  my $sth = $self->prepare($query);
  my $insertCount =
     $sth->execute($anchor_align->method_link_species_set_id,
        $anchor_align->anchor_id,
        $anchor_align->dnafrag_id,
        $anchor_align->dnafrag_start,
        $anchor_align->dnafrag_end,
        $anchor_align->dnafrag_strand,
        $anchor_align->score,
        $anchor_align->num_of_organisms,
        $anchor_align->num_of_sequences,
        );
  if($insertCount>0) {
    #sucessful insert
    $anchor_align->dbID( $sth->{'mysql_insertid'} );
    $sth->finish;
  }

  $anchor_align->adaptor($self);

  return $anchor_align;
}

sub store_exonerate_hits {
	my $self = shift;
	my $batch_records = shift;
	throw() unless($batch_records);
	
	my $dcs = $self->dbc->disconnect_when_inactive();
	$self->dbc->disconnect_when_inactive(0);
	$self->dbc->do("LOCK TABLE anchor_align WRITE");

	my $query = qq{
	INSERT INTO anchor_align (method_link_species_set_id, anchor_id, dnafrag_id, dnafrag_start,	
	dnafrag_end, dnafrag_strand, score, num_of_organisms, num_of_sequences)
	VALUES (?,?,?,?,?,?,?,?,?)};

	my $sth = $self->prepare($query);
	foreach my $row(@$batch_records) {
		$sth->execute( split(":", $row) );
	}	
	$sth->finish;
	$self->dbc->do("UNLOCK TABLES");
	$self->dbc->disconnect_when_inactive($dcs);
	return 1;
}


=head2 store_new_method_link_species_set_id

  Arg[1]     : 
  Example    : 
  Description: 
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

#sub store_new_method_link_species_set_id {
#	my($self) = @_;
#	my $insert_sth = "insert into method_link


###############################################################################
#
# fetch methods
#
###############################################################################

=head2 fetch_dnafrag_id

  Arg[1]     : 
  Arg[2]     :
  Example    : 
  Description: 
  Returntype : 
  Exceptions : none
  Caller     : general
=cut

sub fetch_dnafrag_id {
	my $self = shift;
	my($coord_sys, $dnafrag_name, $target_genome_db_id) = @_;
	unless (defined($coord_sys) and defined($dnafrag_name) and defined($target_genome_db_id)) {
		throw("fetch_dnafrag_id must have a coord_sys, dnafrag_name and target_genome_db_id");
	}
	my $query = qq{
		SELECT dnafrag_id FROM dnafrag WHERE name = ? AND 
		coord_system_name = ? AND genome_db_id = ?};
	my $sth = $self->prepare($query);
	$sth->execute($dnafrag_name, $coord_sys, $target_genome_db_id) or die $self->errstr;
	while (my$row = $sth->fetchrow_arrayref) {
		return $row->[0];
	}
}


##########################


sub get_target_file {
	my $self = shift;
	my($analysis_data_id, $target_genome_db_id) = @_;
	my $query = qq{
		SELECT data FROM analysis_data WHERE analysis_data = ?};
	my $sth = $self->prepare($query);
	$sth->execute($analysis_data_id) or die $self->errstr;
	return $sth->fetchrow_arrayref()->[0]->{target_genomes}->{$target_genome_db_id};
}





=head2 fetch_anchors_by_genomedb_id

  Arg[1]     : 
  Arg[2]     :
  Example    : 
  Description: 
  Returntype : 
  Exceptions : none
  Caller     : general
=cut

sub fetch_anchors_by_genomedb_id {
	my ($self, $genome_db_id) = @_;
	my $return_hashref;
	unless (defined $genome_db_id) {
		throw("fetch_all_by_anchor_id_and_mlss_id must have an anchor_id and a method_link_species_set_id");
	}

	my $query = qq{
		SELECT aa.dnafrag_id, aa.anchor_align_id, aa.anchor_id, 
		aa.dnafrag_start, aa.dnafrag_end 
		FROM anchor_align aa INNER JOIN dnafrag df ON 
		aa.dnafrag_id = df.dnafrag_id WHERE 
		df.genome_db_id = ? order by aa.dnafrag_id, aa.dnafrag_start};
	my $sth = $self->prepare($query);
	$sth->execute($genome_db_id) or die $self->errstr;
	while (my$row = $sth->fetchrow_arrayref) {
		push(@{$return_hashref->{$row->[0]}}, [ $row->[1], $row->[2], $row->[3], $row->[4] ]);
	}
	return $return_hashref;
}

=head2 fetch_all_by_anchor_id_and_mlss_id

  Arg[1]     : anchor_id, string
  Arg[2]     : method_link_species_set_id, string
  Example    : my $anchor = $anchor_align_adaptor->fetch_all_by_anchor_id_and_mlss_id($self->input_anchor_id,$self->method_link_species_set_id);
  Description: returns hashref of cols. from anchor_align table using anchor_align_id as unique hash key
  Returntype : hashref 
  Exceptions : none
  Caller     : general
=cut

sub fetch_all_by_anchor_id_and_mlss_id {
	my ($self, $anchor_id, $method_link_species_set_id) = @_;
	unless (defined $anchor_id && defined $method_link_species_set_id) {
		throw("fetch_all_by_anchor_id_and_mlss_id must have an anchor_id and a method_link_species_set_id");
	}

	my $query = qq{
		SELECT anchor_align_id, method_link_species_set_id, anchor_id, 
		dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand, score, 
		num_of_organisms, num_of_sequences FROM anchor_align WHERE 
		anchor_id = ? AND method_link_species_set_id = ?};
	my $sth = $self->prepare($query);
	$sth->execute($anchor_id, $method_link_species_set_id) or die $self->errstr;
	return $sth->fetchall_hashref("anchor_align_id");
}

=head2 fetch_dnafrag_and_genome_db_ids_by_test_mlssid

  Arg[1]     : method_link_species_set_id, string
  Arg[2]     : genome_db_ids, arrray_ref
  Example    : my $anchor = $anchor_align_adaptor->fetch_all_by_anchor_id_and_mlss_id($self->input_anchor_id,$self->method_link_species_set_id);
  Description: returns hashref of cols. from anchor_align table using anchor_align_id as unique hash key
  Returntype : hashref 
  Exceptions : none
  Caller     : general
=cut

sub fetch_dnafrag_and_genome_db_ids_by_test_mlssid {
	my ($self, $test_method_link_species_set_id, $anchor_id) = @_;
	unless (defined $test_method_link_species_set_id && defined $anchor_id) {
		throw("fetch_dnafrag_and_genome_db_ids_by_test_mlssid
			must have a method_link_species_set_id and an anchor_id");
	}

#	my $question_marks = join(",", split("","?" x scalar(@$genome_db_ids)));
	my $query = qq{
		SELECT aa.dnafrag_id, df.genome_db_id 
		FROM anchor_align aa INNER JOIN dnafrag df on aa.dnafrag_id = df.dnafrag_id
		WHERE aa.anchor_id = ? and aa.method_link_species_set_id = ? AND aa.anchor_status IS NULL}; 
#		df.genome_db_id IN ($question_marks) AND aa.anchor_status IS NULL};
	my $sth = $self->prepare($query);
	my $genome_dbs = join(",", @$genome_db_ids);
	$sth->execute($anchor_id, $test_method_link_species_set_id, @$genome_db_ids) or die $self->errstr;
	return $sth->fetchall_arrayref;
}

=head2 fetch_all_anchor_ids_by_test_mlssid_and_genome_db_ids

  Arg[1]     : method_link_species_set_id, string
  Arg[2]     : genome_db_ids, arrray_ref
  Arg[3]     : anchor_id, string
  Example    : my $anchor = $anchor_align_adaptor->fetch_all_by_anchor_id_and_mlss_id($self->input_anchor_id,$self->method_link_species_set_id);
  Description: returns hashref of cols. from anchor_align table using anchor_align_id as unique hash key
  Returntype : hashref 
  Exceptions : none
  Caller     : general
=cut

sub fetch_all_anchor_ids_by_test_mlssid_and_genome_db_ids {
	my ($self, $test_method_link_species_set_id) = @_;
	unless (defined $test_method_link_species_set_id) {
		throw("fetch_all_anchor_ids_by_test_mlssid_and_genome_db_ids
			must have a method_link_species_set_id");
	}

#	my $question_marks = join(",", split("","?" x scalar(@$genome_db_ids)));
	my $query = qq{
		SELECT distinct(aa.anchor_id)
		FROM anchor_align aa INNER JOIN dnafrag df on aa.dnafrag_id = df.dnafrag_id
		WHERE aa.method_link_species_set_id = ?}; 
#		df.genome_db_id IN ($question_marks) AND aa.anchor_status IS NULL};
	my $sth = $self->prepare($query);
	my $genome_dbs = join(",", @$genome_db_ids);
	$sth->execute($test_method_link_species_set_id) or die $self->errstr;
	return $sth->fetchall_arrayref;
}
=head2 fetch_all_anchors_with_zero_strand

  Arg[1]     : genome_db_ids, array_reff
  Arg[2]     : method_link_species_set_id, string
  Example    : my $anchor = $anchor_align_adaptor->fetch_all_anchors_with_zero_strand($self->genome_db_ids, $self->test_method_link_species_set_id);
  Description: returns arrayref of anchor_id's. from anchor_align table
  Returntype : hashref 
  Exceptions : none
  Caller     : general
=cut

sub fetch_all_anchors_with_zero_strand {
	my ($self, $method_link_species_set_id) = @_;
	unless (defined $method_link_species_set_id) {
		throw("fetch_all_anchors_with_zero_strand must have a method_link_species_set_id");
	}
#	my $question_marks = join(",", split("","?" x scalar(@$genome_db_ids)));
	my $query = qq{
		SELECT distinct(aa.anchor_id) from anchor_align aa INNER JOIN dnafrag df 
		ON aa.dnafrag_id = df.dnafrag_id WHERE aa.dnafrag_strand = 0 AND 
		aa.method_link_species_set_id = ? AND aa.anchor_status IS NULL};
	my $sth = $self->prepare($query);
	my $genome_dbs = join(",", @$genome_db_ids);
	$sth->execute($method_link_species_set_id, @$genome_db_ids) or die $self->errstr;
	return $sth->fetchall_arrayref;
}

=head2 update_zero_strand_anchors

  Arg[1]     : anchor_ids, arrayref
  Arg[2]     : analysis_id, string
  Arg[3]     : method_link_species_set_id, string
  Example    : 
  Description: 
  Returntype : 
  Exceptions : none
  Caller     : general
=cut

sub update_zero_strand_anchors {
	my ($self, $anchor_ids, $analysis_id, $method_link_species_set_id) = @_;
	unless (defined $anchor_ids && defined $analysis_id && defined $method_link_species_set_id) {
		throw("update_anchors_with_zero_strand must have a list of anchor_ids, an analysis_id and a method_link_species_set_id");
	}
	my $query = qq{update anchor_align set anchor_status = ? where method_link_species_set_id = ? and anchor_id = ?};
	my $sth = $self->prepare($query);
	foreach my$anchor_id(@{$anchor_ids}) {
		$sth->execute($analysis_id, $method_link_species_set_id, $anchor_id->[0]) or die $self->errstr;
	}
}

=head2 update_failed_anchor

  Arg[1]     : anchor_id, hashref 
  Arg[2]     : current analysis_id, string
  Example    : $anchor_align_adaptor->update_failed_anchor($self->input_anchor_id, $self->input_analysis_id);
  Description: updates anchor_status field, setting it to the current analysis_id, if the anchor fails the filters associated with the analysis_id
  Returntype : none
  Exceptions : none
  Caller     : general
=cut

sub update_failed_anchor {
	my($self, $failed_anchor_hash_ref, $analysis_id_which_failed, $test_mlssid) = @_;
	unless (defined $failed_anchor_hash_ref && defined $analysis_id_which_failed && defined $test_mlssid) {
		throw("update_failed_anchor must have both a failed_anchor_id and the current analysis_id");
	}

	my $update = qq{
		UPDATE anchor_align SET anchor_status = ? WHERE anchor_id = ? AND method_link_species_set_id = ?};
	my $sth = $self->prepare($update);
	foreach my $failed_anchor(%{$failed_anchor_hash_ref}) {
		$sth->execute($analysis_id_which_failed, $failed_anchor, $test_mlssid) or die $self->errstr;
	}
	return 1;
}

=head2 fetch_all_dnafrag_ids 

  Arg[1]     : listref of genome_db_ids 
  Example    : 
  Description: 
  Returntype : arrayref 
  Exceptions : none
  Caller     : general
=cut

sub fetch_all_dnafrag_ids {
	my($self, $mlssid) = @_;
	my $return_hashref;
	my $dnafrag_query = qq{
		SELECT DISTINCT(dnafrag_id) FROM anchor_align
		WHERE method_link_species_set_id = ?};
#		WHERE df.genome_db_id = ?};  
	my $sth = $self->prepare($dnafrag_query);
	$sth->execute($mlssid);
	while(my@row = $sth->fetchrow_array) {
		push(@{$return_hashref->{$genome_db_id}}, @row);
	}
	return $return_hashref;
}

=head2 fetch_all_anchors_by_dnafrag_id 

  Arg[1]     : dnafrag_id, string
  Example    : 
  Description: 
  Returntype : arrayref 
  Exceptions : none
  Caller     : general
=cut

sub fetch_all_anchors_by_dnafrag_id_and_test_mlssid {
	my($self, $dnafrag_id, $test_mlssid) = @_;
	unless (defined $dnafrag_id && defined $test_mlssid) {
		throw("fetch_all_anchors_by_dnafrag_id_and_test_mlssid  must 
			have a dnafrag_id and a test_mlssid");
	}
	my $dnafrag_query = qq{
		SELECT aa.anchor_align_id, aa.anchor_id, aa.dnafrag_start, aa.dnafrag_end FROM anchor_align aa
		WHERE aa.dnafrag_id = ? AND aa.method_link_species_set_id = ? AND anchor_status 
		IS NULL ORDER BY dnafrag_start, dnafrag_end};
	my $sth = $self->prepare($dnafrag_query);
	$sth->execute($dnafrag_id, $test_mlssid) or die $self->errstr;
	return $sth->fetchall_arrayref();
}
 
=head2 fetch_all_overlapping_anchors

  Args       : none
  Example    : 
  Description: 
  Returntype : none
  Exceptions : none
  Caller     : general
=cut

sub fetch_all_filtered_anchors {
	my($self) = @_;
	my %Return_hash;
	my $fetch_query = qq{
		SELECT anchor_id, dnafrag_id, dnafrag_start, dnafrag_end, num_of_sequences, num_of_organisms 
		FROM anchor_align WHERE anchor_status IS NULL ORDER BY dnafrag_id, dnafrag_start, dnafrag_end};

	my $sth = $self->prepare($fetch_query);
	$sth->execute() or die $self->errstr;
	my$array_ref = $sth->fetchall_arrayref();
	for(my$i=0;$i<@{$array_ref};$i++) {
		push(@{$Return_hash{$array_ref->[$i]->[1]}}, 
		[ $array_ref->[$i]->[0], $array_ref->[$i]->[2], $array_ref->[$i]->[3], $array_ref->[$i]->[4], $array_ref->[$i]->[5] ]);
		# [ anchor_id, dnafrag_start, dnafrag_end, num_of_seqs_that_hit_the_genomic_position, num_of_organisms_from_which_seqs_derived ]
		splice(@{$array_ref}, $i, 1); #reduce momory used
		$i--;
	}
	return \%Return_hash;
}

=head2 fetch_by_dbID

  Arg [1]    : int $dbID
  Example    :
  Description: Returns the AnchorAlign obejcts with this anchor_align_id
  Returntype : Bio::EnsEMBL::Compara::Production::AnchorAlign object
  Exceptions :
  Caller     : general
=cut

sub fetch_by_dbID {
  my ($self, $id) = @_;

  unless (defined $id) {
    throw("fetch_by_dbID must have an id");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "${syn}.${name}_id = $id";

  #return first element of _generic_fetch list
  my ($obj) = @{$self->_generic_fetch($constraint)};
  return $obj;
}


=head2 fetch_all_by_MethodLinkSpeciesSet

  Arg [1]    : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss
  Example    :
  Description: Returns all the AnchorAlign obejcts for this MethodLinkSpeciesSet
  Returntype : listref of Bio::EnsEMBL::Compara::Production::AnchorAlign objects
  Exceptions :
  Caller     : general

=cut

sub fetch_all_by_MethodLinkSpeciesSet {
  my ($self, $method_link_species_set) = @_;

  unless (UNIVERSAL::isa($method_link_species_set, "Bio::EnsEMBL::Compara::MethodLinkSpeciesSet")) {
    throw("[$method_link_species_set] must be a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "aa.method_link_species_set_id = ". $method_link_species_set->dbID;

  #return first element of _generic_fetch list
  return $self->_generic_fetch($constraint);
}


############################
#
# INTERNAL METHODS
# (pseudo subclass methods)
#
############################

#internal method used in multiple calls above to build objects from table data

sub _tables {
  my $self = shift;

  return (['anchor_align', 'aa'] );
}

sub _columns {
  my $self = shift;

  return qw (aa.anchor_align_id
             aa.method_link_species_set_id
             aa.anchor_id
             aa.dnafrag_id
             aa.dnafrag_start
             aa.dnafrag_end
             aa.dnafrag_strand
             aa.score
             aa.num_of_organisms
             aa.num_of_sequences
             aa.anchor_status
            );
}

sub _default_where_clause {
  my $self = shift;
  return '';
}

sub _final_clause {
  my $self = shift;
  $self->{'_final_clause'} = shift if(@_);
  return $self->{'_final_clause'};
}


sub _objs_from_sth {
  my ($self, $sth) = @_;

  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my $anchor_aligns = [];

  while ($sth->fetch()) {
    my $this_anchor_align;

    $this_anchor_align = Bio::EnsEMBL::Compara::Production::AnchorAlign->new();

    $this_anchor_align->adaptor($self);
    $this_anchor_align->dbID($column{'anchor_align_id'});
    $this_anchor_align->method_link_species_set_id($column{'method_link_species_set_id'});
    $this_anchor_align->anchor_id($column{'anchor_id'});
    $this_anchor_align->dnafrag_id($column{'dnafrag_id'});
    $this_anchor_align->dnafrag_start($column{'dnafrag_start'});
    $this_anchor_align->dnafrag_end($column{'dnafrag_end'});
    $this_anchor_align->dnafrag_strand($column{'dnafrag_strand'});
    $this_anchor_align->score($column{'score'});
    $this_anchor_align->num_of_organisms($column{'num_of_organisms'});
    $this_anchor_align->num_of_sequences($column{'num_of_sequences'});
    $this_anchor_align->anchor_status($column{'anchor_status'});

    push(@$anchor_aligns, $this_anchor_align);
  }
  $sth->finish;

  return $anchor_aligns;
}


=head2 _generic_fetch

  Arg [1]    : (optional) string $constraint
               An SQL query constraint (i.e. part of the WHERE clause)
  Arg [2]    : (optional) string $logic_name
               the logic_name of the analysis of the features to obtain
  Example    : $fts = $a->_generic_fetch('contig_id in (1234, 1235)', 'Swall');
  Description: Performs a database fetch and returns feature objects in
               contig coordinates.
  Returntype : listref of Bio::EnsEMBL::Production::DnaFragChunk in contig coordinates
  Exceptions : none
  Caller     : internal

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
  $sql .= " $final_clause" if($final_clause);

  my $sth = $self->prepare($sql);
  $sth->execute;

  # print STDERR "sql execute finished. about to build objects\n";

  return $self->_objs_from_sth($sth);
}


1;
