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

package Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor;

use vars qw(@ISA);
use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::ConstrainedElement;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);
use Data::Dumper;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


=head2 store

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object 
  Arg  2     : listref of Bio::EnsEMBL::Compara::ConstrainedElement ($constrained_element) objects 
               The things you want to store
  Example    : none
  Description: It stores the given ConstrainedElements in the database.
  Returntype : none
  Exceptions : throw if Arg-1 is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
	       throw if Arg-2 is not a Bio::EnsEMBL::Compara::ConstrainedElement	
  Caller     : called by the Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Gerp module 

=cut

sub store {
    my ( $self, $mlss_obj, $constrained_elements ) = @_;

    assert_ref($mlss_obj, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet', 'mlss_obj');
    
    my $mlssid = $mlss_obj->dbID;
    
    #
    #Find unique constrained_element_id by using a temporary table with an auto_increment column
    #
    my $ce_id_sql = "INSERT INTO constrained_element_production () VALUES ()";
    my $ce_id_sth = $self->prepare($ce_id_sql);

    my $constrained_element_sql = qq{INSERT INTO constrained_element (
		constrained_element_id,
		dnafrag_id,
		dnafrag_start, 
		dnafrag_end,
		dnafrag_strand,
		score,
		method_link_species_set_id,
		p_value
	) VALUES (?,?,?,?,?,?,?,?)};
    
    my $constrained_element_sth = $self->prepare($constrained_element_sql) or die;
    
    foreach my $constrained_element_group (@$constrained_elements) {
	$ce_id_sth->execute();
	my $constrained_element_id = $self->dbc->db_handle->last_insert_id(undef, undef, 'constrained_element', 'constrained_element_id');
	if ($constrained_element_id < $mlssid * 10000000000 || 
	    $constrained_element_id > ($mlssid+1) * 10000000000) {
	    $constrained_element_id = $mlssid * 10000000000 + $constrained_element_id;
	}

	foreach my $constrained_element (@{$constrained_element_group}) {
            assert_ref($constrained_element, 'Bio::EnsEMBL::Compara::ConstrainedElement', 'constrained_element');
	    $constrained_element_sth->execute(
					      $constrained_element_id,
					      $constrained_element->reference_dnafrag_id,
					      $constrained_element->start,
					      $constrained_element->end,
					      $constrained_element->strand,
					      $constrained_element->score,
					      $mlssid,
					      $constrained_element->p_value,
					     );
	}
    }
}

=head2 delete_by_MethodLinkSpeciesSet

  Arg  1     : method_link_species_set object $mlss
  Example    : $constrained_element_adaptor->delete_by_MethodLinkSpeciesSet($mlss);
  Description: It removes constrained elements with the specified method_link_species_set_id from the database
  Returntype : none
  Exceptions : throw if passed parameter is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object 
  Caller     : general

=cut

sub delete_by_MethodLinkSpeciesSet {
  my ($self, $mlss_obj) = @_;

  assert_ref($mlss_obj, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet', 'mlss_obj');

  my $cons_ele_sql =
        qq{DELETE FROM constrained_element WHERE method_link_species_set_id = ?};
  
# Delete constrtained element entries by mlss_id
  my $sth = $self->prepare($cons_ele_sql);
  $sth->execute($mlss_obj->dbID);
  $sth->finish;
}


=head2 delete_by_dbID

  Arg  1     : int $constrained_element_id
  Example    : $constrained_element_adaptor->delete_by_dbID(123);
  Description: It removes constrained elements with the specified ID
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub delete_by_dbID {
  my ($self, $constrained_element_id) = @_;

  if (!defined($constrained_element_id)) {
    throw("undefined Constrained Element ID");
  }

  my $cons_ele_sql =
        qq{DELETE FROM constrained_element WHERE constrained_element_id = ?};
  
# Delete constrtained element entries by mlss_id
  my $sth = $self->prepare($cons_ele_sql);
  $sth->execute($constrained_element_id);
  $sth->finish;
}


=head2 fetch_all_by_MethodLinkSpeciesSet_Slice

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss_obj
  Arg  2     : Bio::EnsEMBL::Slice $slice_obj
  Example    : my $listref_of_constrained_elements = $constrained_element_adaptor->
  		fetch_all_by_MethodLinkSpeciesSet_Slice($mlss_obj, $slice_obj);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::ConstrainedElement object listref
  Returntype : listref of Bio::EnsEMBL::Compara::ConstrainedElement objects
  Exceptions : throw if Arg-1 is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
	       throw if Arg-2 is not a Bio::EnsEMBL::Slice object
  Caller     : object::methodname

=cut

sub fetch_all_by_MethodLinkSpeciesSet_Slice {
	my ($self, $mlss_obj, $slice_obj) = @_;
        assert_ref($mlss_obj, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet', 'mlss_obj');
        assert_ref($slice_obj, 'Bio::EnsEMBL::Slice', 'slice_obj');

        my $filter_projections = 1;
        my $projection_segments = $slice_obj->adaptor->fetch_normalized_slice_projection($slice_obj, $filter_projections);
        return [] if(!@$projection_segments);

        my $constrained_elements;
        foreach my $this_projection_segment (@$projection_segments) {
            my $offset    = $this_projection_segment->from_start();
            
            my $this_slice = $this_projection_segment->to_Slice;
            
            #print $this_slice->seq_region_name . " " . $this_slice->start . " " . $this_slice->end . " offset=$offset\n";
            
            my $dnafrag_adp = $self->db->get_DnaFragAdaptor;
            my $dnafrag = $dnafrag_adp->fetch_by_Slice($this_slice);
            next unless $dnafrag; # Some contigs may not be mapped to any top-level regions
            my $sql = qq{
		WHERE
		method_link_species_set_id = ?
		AND
		dnafrag_id = ? 
	    };
            my ($lower_bound);

            if(defined($this_slice->start) && defined($this_slice->end) && 
               ($this_slice->start <= $this_slice->end)) {
                my $max_alignment_length = $mlss_obj->max_alignment_length;
                $lower_bound = $this_slice->start - $max_alignment_length;
                $sql .= qq{
				AND
				dnafrag_end >= ?
				AND
				dnafrag_start <= ?
				AND
				dnafrag_start >= ?
			};
	}
            
            my $these_constrained_elements = $self->_fetch_all_ConstrainedElements($sql,
                                                  $mlss_obj->dbID, $dnafrag->dbID, $this_slice->start, $this_slice->end, $lower_bound, $this_slice, $offset);

            push @$constrained_elements, @$these_constrained_elements;
        }

	return $constrained_elements;
}

=head2 fetch_all_by_MethodLinkSpeciesSet_DnaFrag

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet mlss_obj
  Arg  2     : Bio::EnsEMBL::Compara::DnaFrag dnafrag_obj
  Example    : my $listref_of_constrained_elements = $constrained_element_adaptor->
  		fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss_obj, $dnafrag_obj);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::ConstrainedElement object listref
  Returntype : listref of Bio::EnsEMBL::Compara::ConstrainedElement objects
  Exceptions : throw if Arg-1 is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet mlss_obj object
	       throw if Arg-2 is not a Bio::EnsEMBL::Compara::DnaFrag object
  Caller     : object::methodname

=cut

sub fetch_all_by_MethodLinkSpeciesSet_DnaFrag {
	my ($self, $mlss_obj, $dnafrag_obj, $dnafrag_start, $dnafrag_end) = @_;
        assert_ref($mlss_obj, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet', 'mlss_obj');
        assert_ref($dnafrag_obj, 'Bio::EnsEMBL::Compara::DnaFrag', 'dnafrag_obj');

	my (@constrained_elements, $lower_bound);
	my $sql = qq{
		WHERE
		method_link_species_set_id = ?
		AND
		dnafrag_id = ?
	};
 
	if (defined($dnafrag_start) && defined($dnafrag_end) && ($dnafrag_start <= $dnafrag_end)) {
		my $max_alignment_length = $mlss_obj->max_alignment_length;
		$lower_bound = $dnafrag_start - $max_alignment_length;
	} else {
		$dnafrag_start = 1;
		$dnafrag_end = $dnafrag_obj->length;
		$lower_bound = $dnafrag_start;
	}
	$sql .= qq{
		AND
		dnafrag_end >= ?
		AND
		dnafrag_start <= ?
		AND
		dnafrag_start >= ?
	};
	return $self->_fetch_all_ConstrainedElements($sql,
			$mlss_obj->dbID, $dnafrag_obj->dbID, $dnafrag_start, $dnafrag_end, $lower_bound);
}


sub _fetch_all_ConstrainedElements {#used when getting constrained elements by slice or dnafrag
	my ($self) = shift;
	my ($sql, $mlss_id, $dnafrag_id, $start, $end, $lower_bound, $slice, $offset) = @_;

        $offset = 0 unless (defined $offset);
	$sql = qq{
       		SELECT
       		constrained_element_id,
       		dnafrag_start,
       		dnafrag_end,
                dnafrag_strand,
      		score,
      		p_value
       		FROM
       		constrained_element} . $sql;

	my @constrained_elements;
	my $sth = $self->prepare($sql);
	$sth->execute($mlss_id, $dnafrag_id, $start, $end, $lower_bound);
	my ($dbID, $ce_start, $ce_end, $ce_strand, $score, $p_value);
	$sth->bind_columns(\$dbID, \$ce_start, \$ce_end, \$ce_strand, \$score, \$p_value);
	while ($sth->fetch()) {
		my $constrained_element = Bio::EnsEMBL::Compara::ConstrainedElement->new_fast (
			{
				'adaptor' => $self,
				'dbID' => $dbID,
				'slice' => $slice,
				'start' =>  ($ce_start - $start + $offset), 
				'end' => ($ce_end - $start + $offset),
			        'strand' => $ce_strand,
				'method_link_species_set_id' => $mlss_id,
				'score' => $score,
				'p_value' => $p_value,
				'reference_dnafrag_id' => $dnafrag_id,
			}
		);
		push(@constrained_elements, $constrained_element);
	}
       return \@constrained_elements;
}	

=head2 fetch_all_by_dbID_list

  Arg  1     : listref of constrained_element_ids
  Example    : my $listref_of_constrained_elements = $constrained_element_adaptor->fetch_all_by_dbID_list($list_ref_of_constrained_element_ids);
  Description: Retrieve the corresponding constrained_elements from a given list of constrained_element_ids 
  Returntype : listref of Bio::EnsEMBL::Compara::ConstrainedElement constrained_elements 
  Exceptions : throw if Arg-1 is not a listref
  Caller     : object::methodname

=cut

sub fetch_all_by_dbID_list {
	my ($self, $constrained_element_ids) = @_;
	if(defined($constrained_element_ids)) {
		throw("Arg-1 needs to be a listref of dbIDs") unless (
			ref($constrained_element_ids) eq "ARRAY");
	}
	my @constrained_elements;
	my $sql = qq{
		WHERE
		ce.constrained_element_id = ?
	};
	return $self->_fetch_all_ConstrainedElements_by_dbID($sql, $constrained_element_ids);
}

=head2 fetch_by_dbID

  Arg  1     : int constrained_element_id
  Example    : my $constrained_element = $constrained_element_adaptor->
               fetch_by_dbID($constrained_element_id);
  Description: Retrieve the corresponding constrained_element.
  Returntype : Bio::EnsEMBL::Compara::ConstrainedElement object
  Exceptions : -none-
  Caller     : object::methodname

=cut

sub fetch_by_dbID {
  my ($self, $constrained_element_id) = @_;
  return ($self->fetch_all_by_dbID_list([$constrained_element_id]))->[0];
}

sub _fetch_all_ConstrainedElements_by_dbID {#used when getting constrained elements by constrained_element_id
	my ($self) = shift;
	my ($sql, $dbIDs) = @_;
        
	$sql = qq{
       		SELECT
       		ce.constrained_element_id,
       		ce.dnafrag_id,
       		ce.dnafrag_start,
       		ce.dnafrag_end,
		ce.dnafrag_strand,
       		ce.method_link_species_set_id,
      		ce.score,
      		ce.p_value,
		gdb.name,
		df.name
       		FROM
       		constrained_element ce
		INNER JOIN 
		dnafrag df 
		ON
		df.dnafrag_id = ce.dnafrag_id
		INNER JOIN 
		genome_db gdb
		ON 
		gdb.genome_db_id = df.genome_db_id} . $sql;

	my $sth = $self->prepare($sql);
	my @constrained_elements;
	foreach my $constrained_element_id (@{ $dbIDs }) {
		my (%general_attributes, @alignment_segments);
		$sth->execute( $constrained_element_id );
		my ($dbID, $dnafrag_id, $ce_start, $ce_end, $ce_strand, $mlssid, $score, $p_value, $species_name, $dnafrag_name);
	 	$sth->bind_columns(\$dbID, \$dnafrag_id, \$ce_start, \$ce_end, \$ce_strand, \$mlssid, 
					\$score, \$p_value, \$species_name, \$dnafrag_name);	
		while ($sth->fetch()) {
			$general_attributes{dbID} = $dbID;
			$general_attributes{mlssid} = $mlssid;
			$general_attributes{score} = $score;
			$general_attributes{p_value} = $p_value;
			push(@alignment_segments, [ $dnafrag_id, $ce_start, $ce_end, $ce_strand, $species_name, $dnafrag_name ]);
		}
		my $constrained_element = Bio::EnsEMBL::Compara::ConstrainedElement->new_fast (
			{
				'adaptor' => $self,
				'dbID' => $general_attributes{dbID},
				'alignment_segments' => \@alignment_segments,
				'method_link_species_set_id' => $general_attributes{mlssid},
				'score' => $general_attributes{score},
				'p_value' => $general_attributes{p_value},
			}
		);
		push(@constrained_elements, $constrained_element) if @alignment_segments;
	}
	return \@constrained_elements;
}

sub count_by_mlss_id {
    my ($self, $mlss_id) = @_;

    my $sql = "SELECT count(*) FROM constrained_element WHERE method_link_species_set_id=?";
    my $sth = $self->prepare($sql);
    $sth->execute($mlss_id);
    my ($count) = $sth->fetchrow_array();
    $sth->finish();

    return $count;
}

1;
