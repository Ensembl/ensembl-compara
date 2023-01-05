=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RemoveOverlappingDataByMember

=head1 DESCRIPTION

When we infer protein trees for a complementary collection, we end up with some redundant homology data,
which currently needs to be removed from the pipeline database of the complementary collection so that it
does not clash with or duplicate the data in its reference collection(s). This runnable can be used to
remove member-associated redundant homology data from a complementary collection pipeline database.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RemoveOverlappingDataByMember;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::MasterDatabase;
use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $master_dba = $self->get_cached_compara_dba('master_db');
    my $collection_name = $self->param_required('collection');

    my $ref_collection_names;
    if ( $self->param_is_defined('ref_collection') && $self->param_is_defined('ref_collection_list') ) {
        $self->throw("Only one of parameters 'ref_collection' or 'ref_collection_list' can be defined")
    } elsif ( $self->param_is_defined('ref_collection') ) {
        $ref_collection_names = [$self->param('ref_collection')];
    } elsif ( $self->param_is_defined('ref_collection_list') ) {
        $ref_collection_names = destringify($self->param('ref_collection_list'));
    } else {
        $self->throw("One of parameters 'ref_collection' or 'ref_collection_list' must be defined")
    }

    my $overlapping_species = Bio::EnsEMBL::Compara::Utils::MasterDatabase::find_overlapping_genome_db_ids($master_dba,
                                                                                                           $collection_name,
                                                                                                           $ref_collection_names);
    my $overlap_genome_db_ids = '(' . join(',', @{$overlapping_species}) . ')';

    my $hmm_annot_sql = qq/
        DELETE 
            hmm_annot
        FROM
            hmm_annot
        JOIN
            seq_member
        USING
            (seq_member_id)
        WHERE
            seq_member.genome_db_id IN $overlap_genome_db_ids
    /;
    $self->compara_dba->dbc->do($hmm_annot_sql);

    my $peptide_align_feature_sql = qq/
        DELETE 
            peptide_align_feature
        FROM
            peptide_align_feature
        JOIN
            seq_member qmember
        ON
            qmember_id = qmember.seq_member_id
        JOIN
            seq_member hmember
        ON
            hmember_id = hmember.seq_member_id
        WHERE
            qmember.genome_db_id IN $overlap_genome_db_ids
        AND
            hmember.genome_db_id IN $overlap_genome_db_ids
    /;
    $self->compara_dba->dbc->do($peptide_align_feature_sql);
}

1;
