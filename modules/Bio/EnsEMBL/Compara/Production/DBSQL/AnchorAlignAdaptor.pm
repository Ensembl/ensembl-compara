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

use strict;
use warnings;

use Data::Dumper;

use DBI qw(:sql_types);

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

    my $dbID = $self->generic_insert('anchor_align', {
            'method_link_species_set_id'    => $anchor_align->method_link_species_set_id,
            'anchor_id'                     => $anchor_align->anchor_id,
            'dnafrag_id'                    => $anchor_align->dnafrag_id,
            'dnafrag_start'                 => $anchor_align->dnafrag_start,
            'dnafrag_end'                   => $anchor_align->dnafrag_end,
            'dnafrag_strand'                => $anchor_align->dnafrag_strand,
            'score'                         => $anchor_align->score,
            'num_of_organisms'              => $anchor_align->num_of_organisms,
            'num_of_sequences'              => $anchor_align->num_of_sequences,
            'evalue'                        => $anchor_align->evalue,
            'anchor_status'                 => $anchor_align->anchor_status,
            }, 'anchor_align_id');
    $self->attach($anchor_align, $dbID);
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






=head2 fetch_all_by_anchor_id_and_mlss_id

  Arg[1]     : anchor_id, string
  Arg[2]     : method_link_species_set_id, string
  Example    : my $anchor_aligns = $anchor_align_adaptor->fetch_all_by_anchor_id_and_mlss_id($self->input_anchor_id,$self->method_link_species_set_id);
  Returntype : arrayref of AnchorAlign objects
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_anchor_id_and_mlss_id {
	my ($self, $anchor_id, $method_link_species_set_id) = @_;
	unless (defined $anchor_id && defined $method_link_species_set_id) {
		throw("fetch_all_by_anchor_id_and_mlss_id must have an anchor_id and a method_link_species_set_id");
	}
        my $constraint = 'anchor_id = ? AND method_link_species_set_id = ?';
        $self->bind_param_generic_fetch($anchor_id, SQL_INTEGER);
        $self->bind_param_generic_fetch($method_link_species_set_id, SQL_INTEGER);
        return $self->generic_fetch($constraint);
}


=head2 update_anchor_status

  Arg[1]     : anchor_id, arrayref
  Arg[2]     : integer: new "anchor_status" value
  Example    : $anchor_align_adaptor->update_anchor_status($array_of_anchor_ids, 3333);
  Description: updates anchor_status field
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub update_anchor_status {
	my($self, $failed_anchor_array_ref, $new_status, $mlssid) = @_;
	unless (defined $failed_anchor_array_ref){
		throw( "No failed_anchor_id : update_anchor_status failed");
	} 
	unless (defined $new_status ){
		throw("No status : update_anchor_status failed");
	}
	unless (defined $mlssid) {
		throw("No mlssid : update_anchor_status failed");
	}

	my $update = qq{
		UPDATE anchor_align SET anchor_status = ? WHERE anchor_id = ? AND method_link_species_set_id = ?};
	my $sth = $self->prepare($update);
	foreach my $failed_anchor(@{$failed_anchor_array_ref}) {
		$sth->execute($new_status, $failed_anchor, $mlssid) or die $self->errstr;
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
    return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::Production::EPOanchors::AnchorAlign', [
            'dbID',
            '_method_link_species_set_id',
            '_anchor_id',
            'dnafrag_id',
            'dnafrag_start',
            'dnafrag_end',
            'dnafrag_strand',
            '_score',
            '_num_of_organisms',
            '_num_of_sequences',
            '_anchor_status',
        ] );
}


1;
