=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::Production::DBSQL::AnchorAlignAdaptor

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

=cut

use strict;
use warnings;


package Bio::EnsEMBL::Compara::Production::DBSQL::AnchorAlignAdaptor;

use Data::Dumper;

use Bio::EnsEMBL::Compara::Production::EPOanchors::AnchorAlign;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use Bio::EnsEMBL::Compara::Utils::CopyData qw(:insert);

use base qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);


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

  assert_ref($anchor_align, 'Bio::EnsEMBL::Compara::Production::EPOanchors::AnchorAlign', 'anchor_align');

  my $query = qq{
  INSERT INTO anchor_align
    (method_link_species_set_id, anchor_id, dnafrag_id, dnafrag_start,
    dnafrag_end, dnafrag_strand, score, num_of_organisms, num_of_sequences, evalue)
  VALUES (?,?,?,?,?,?,?,?,?,?)};

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
	$anchor_align->evalue,
        );
  if($insertCount>0) {
    #sucessful insert
    $anchor_align->dbID( $self->dbc->db_handle->last_insert_id(undef, undef, 'anchor_align', 'anchor_align_id') );
    $sth->finish;
  }

  $anchor_align->adaptor($self);

  return $anchor_align;
}

sub store_mapping_hits {
	my $self = shift;
	my $batch_records = shift;
	return bulk_insert($self->dbc, 'anchor_align', $batch_records, [qw(method_link_species_set_id anchor_id dnafrag_id dnafrag_start dnafrag_end dnafrag_strand score num_of_organisms num_of_sequences evalue anchor_status)]);
}

sub store_exonerate_hits {
        my $self = shift;
        my $batch_records = shift;
        return bulk_insert($self->dbc, 'anchor_align', $batch_records, [qw(method_link_species_set_id anchor_id dnafrag_id dnafrag_start dnafrag_end dnafrag_strand score num_of_organisms num_of_sequences)]);
}


###############################################################################
#
# fetch methods
#
###############################################################################


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
		anchor_id = ? AND method_link_species_set_id = ? AND anchor_status IS NULL};
	my $sth = $self->prepare($query);
	$sth->execute($anchor_id, $method_link_species_set_id) or die $self->errstr;
	return $sth->fetchall_hashref("anchor_align_id");
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
	my($self, $failed_anchor_hash_ref, $analysis_id_which_failed, $mlssid) = @_;
	unless (defined $failed_anchor_hash_ref ){
		throw( "No failed_anchor_id : update_failed_anchor failed");
	} 
	unless (defined $analysis_id_which_failed){
		throw("No analysis_id : update_failed_anchor failed");
	}
	unless (defined $mlssid) {
		throw("No mlssid : update_failed_anchor failed");
	}

	my $update = qq{
		UPDATE anchor_align SET anchor_status = ? WHERE anchor_id = ? AND method_link_species_set_id = ?};
	my $sth = $self->prepare($update);
	foreach my $failed_anchor(%{$failed_anchor_hash_ref}) {
		$sth->execute($analysis_id_which_failed, $failed_anchor, $mlssid) or die $self->errstr;
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
		SELECT DISTINCT(aa.dnafrag_id), df.genome_db_id FROM anchor_align aa
		INNER JOIN dnafrag df on aa.dnafrag_id = df.dnafrag_id 
		WHERE aa.method_link_species_set_id = ?};
#		WHERE df.genome_db_id = ?};  
	my $sth = $self->prepare($dnafrag_query);
	$sth->execute($mlssid);
	while(my@row = $sth->fetchrow_array) {
		push(@{$return_hashref->{$row[1]}}, $row[0]);
	}
	return $return_hashref;
}

=head2 fetch_all_anchors_by_genome_db_id_and_mlssid 

  Arg[0]     : genome_db_id, string
  Arg[1]     : mlssid, string
  Example    : 
  Description: 
  Returntype : arrayref 
  Exceptions : none
  Caller     : general

=cut

#HACK

sub fetch_all_anchors_by_genome_db_id_and_mlssid {
	my($self, $genome_db_id, $mlssid) = @_;
	unless (defined $genome_db_id && defined $mlssid) {
		throw("fetch_all_anchors_by_genome_db_id_and_mlssid must have a genome_db_id and a mlssid");
	}
	my $dnafrag_query = qq{
		SELECT aa.dnafrag_id, aa.anchor_align_id, aa.anchor_id, aa.dnafrag_start, aa.dnafrag_end 
		FROM anchor_align aa
		INNER JOIN dnafrag df ON df.dnafrag_id = aa.dnafrag_id 
		WHERE df.genome_db_id = ? AND aa.method_link_species_set_id = ? AND anchor_status 
		IS NULL ORDER BY dnafrag_start, dnafrag_end};
	my $sth = $self->prepare($dnafrag_query);
	$sth->execute($genome_db_id, $mlssid) or die $self->errstr;
	return $sth->fetchall_arrayref();
}


=head2 fetch_all_by_MethodLinkSpeciesSet

  Arg [1]    : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss
  Example    :
  Description: Returns all the AnchorAlign obejcts for this MethodLinkSpeciesSet
  Returntype : listref of Bio::EnsEMBL::Compara::Production::EPOanchors::AnchorAlign objects
  Exceptions :
  Caller     : general

=cut

sub fetch_all_by_MethodLinkSpeciesSet {
  my ($self, $method_link_species_set) = @_;

  assert_ref($method_link_species_set, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet', 'method_link_species_set');

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "aa.method_link_species_set_id = ". $method_link_species_set->dbID;

  return $self->generic_fetch($constraint);
}


############################
#
# INTERNAL METHODS
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



sub _objs_from_sth {
  my ($self, $sth) = @_;

  my @anchor_aligns = ();

  while( my $row_hashref = $sth->fetchrow_hashref()) {
    my $this_anchor_align = Bio::EnsEMBL::Compara::Production::EPOanchors::AnchorAlign->new();

    $this_anchor_align->adaptor($self);
    $this_anchor_align->dbID($row_hashref->{'anchor_align_id'});
    $this_anchor_align->method_link_species_set_id($row_hashref->{'method_link_species_set_id'});
    $this_anchor_align->anchor_id($row_hashref->{'anchor_id'});
    $this_anchor_align->dnafrag_id($row_hashref->{'dnafrag_id'});
    $this_anchor_align->dnafrag_start($row_hashref->{'dnafrag_start'});
    $this_anchor_align->dnafrag_end($row_hashref->{'dnafrag_end'});
    $this_anchor_align->dnafrag_strand($row_hashref->{'dnafrag_strand'});
    $this_anchor_align->score($row_hashref->{'score'});
    $this_anchor_align->num_of_organisms($row_hashref->{'num_of_organisms'});
    $this_anchor_align->num_of_sequences($row_hashref->{'num_of_sequences'});
    $this_anchor_align->anchor_status($row_hashref->{'anchor_status'});

    push @anchor_aligns, $this_anchor_align;
  }
  $sth->finish;

  return \@anchor_aligns;
}


1;
