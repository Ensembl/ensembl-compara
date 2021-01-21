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

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory

=head1 DESCRIPTION

Fetch list of member_ids per genome_db_id in db and create jobs for BlastAndParsePAF.

=over

=item step
Optional. How many sequences to write into the blast query file. Default: 200.

=back

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector qw/ collect_reference_classification match_query_to_reference_taxonomy collect_species_set_dirs /;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Data::Dumper;

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'step' => 200,
    };
}


sub fetch_input {
    my $self = shift @_;

    my $ref_master = $self->param_required('rr_ref_db');
    my $genome_dbs = $self->compara_dba->get_GenomeDBAdaptor->fetch_all();
    my ( @genome_db_ids, @query_members );

    foreach my $genome_db (@$genome_dbs) {
        my $genome_db_id = $genome_db->dbID;
        # Fetch canonical proteins into array
        my $some_members = $self->compara_dba->get_SeqMemberAdaptor->_fetch_all_representative_for_blast_by_genome_db_id($genome_db_id);
        my @mlsss        = @{$self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type_GenomeDB('ENSEMBL_HOMOLOGUES', $genome_db)};
        # There should only be one mlss in the pipeline_db for each genome_db - these are generated on the fly
        # but just in case:
        $self->warning("There are multiple mlsss for $genome_db ENSEMBL_HOMOLOGUES when we only expect 1") if ( scalar(@mlsss) > 1 );

        my @genome_members = map {$_->dbID} @$some_members;
        # Necessary to collect the reference taxonomy because this decides which reference species_set is used
        push @query_members, { 'genome_db_id' => $genome_db_id, 'mlss_id' => $mlsss[0]->dbID, 'member_ids' => \@genome_members, 'ref_taxa' => $self->match_query_to_reference_taxonomy($genome_db, $ref_master) };
    }

    $self->param('query_members', \@query_members);
}

sub write_output {
    my $self = shift @_;

    my $step              = $self->param('step');
    my @query_member_list = @{$self->param('query_members')};

    foreach my $genome ( @query_member_list ) {

        my $genome_db_id  = $genome->{'genome_db_id'};
        my $mlss_id       = $genome->{'mlss_id'};
        my $query_members = $genome->{'member_ids'};
        # There is a default species set if a clade specific species set does not exist for a species
        my $ref_taxa      = $genome->{'ref_taxa'} ? $genome->{'ref_taxa'} : "default";
        my $ref_dump_dir  = $self->param_required('ref_dumps_dir');
        # Returns all the directories (fasta, split_fasta & diamond pre-indexed db) under all the references
        my $ref_dirs      = collect_species_set_dirs($self->param_required('rr_ref_db'), $ref_taxa);

        foreach my $ref ( @$ref_dirs ) {
            # Obtain the diamond indexed file for the reference, this is the only file we need from
            # each reference at this point
            my $ref_dmnd_path = $ref_dump_dir . '/' . $ref->{'ref_dmnd'};
            while (@$query_members) {
                my @job_array = splice(@$query_members, 0, $step);
                # A job is output for every $step query members against each reference diamond db
                my $output_id = { 'member_id_list' => \@job_array, 'mlss_id' => $mlss_id, 'all_blast_db' => $ref_dmnd_path };
                $self->dataflow_output_id($output_id, 2);
            }
            $self->dataflow_output_id( { 'genome_db_id' => $genome_db_id, 'ref_taxa' => $ref_taxa }, 1 );
        }
    }
}

1;
