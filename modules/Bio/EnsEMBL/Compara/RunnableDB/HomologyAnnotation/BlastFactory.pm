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

=item rr_ref_db

Mandatory. Rapid release Compara reference database. Can be an alias or an URL.

=item ref_dump_dir

Mandatory. Reference dump directory path.

=item species_list

Mandatory. Query species name list.

=item step

Optional. How many sequences to write into the blast query file. Default: 200.

=back

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector qw(:all);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


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
    my $species = $self->param_required('species_list');
    my $gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
    my ( @genome_db_ids, @query_members );

    foreach my $species_name (@$species) {
        # We want to get the GenomeDB of the query species, not the reference
        my @genome_dbs = sort { $a->dbID <=> $b->dbID } @{ $gdb_adaptor->fetch_all_by_name($species_name) };
        my $genome_db = $genome_dbs[0];
        my $genome_db_id = $genome_db->dbID;
        # Fetch canonical proteins into array
        my $some_members = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_canonical_by_GenomeDB($genome_db_id);

        my @genome_members = map {$_->dbID} @$some_members;
        # Necessary to collect the reference taxonomy because this decides which reference species_set is used
        push @query_members, { 'genome_db_id' => $genome_db_id, 'member_ids' => \@genome_members, 'ref_taxa' => match_query_to_reference_taxonomy($genome_db, $ref_master) };
    }

    $self->param('query_members', \@query_members);
}

sub write_output {
    my $self = shift @_;

    my $step              = $self->param('step');
    my @query_member_list = @{$self->param('query_members')};
    my $gdb_adaptor       = $self->compara_dba->get_GenomeDBAdaptor;
    my @funnel_output;

    foreach my $genome ( @query_member_list ) {

        my $genome_db_id  = $genome->{'genome_db_id'};
        my $query_members = $genome->{'member_ids'};
        # There is a default reference species set if a clade-specific reference species set does not exist for a species
        my $ref_taxa      = $genome->{'ref_taxa'} ? $genome->{'ref_taxa'} : "default";
        my $ref_dump_dir  = $self->param_required('ref_dump_dir');
        # Returns all the directories (fasta, split_fasta & diamond pre-indexed db) under all the references
        my $ref_dirs      = collect_species_set_dirs($self->param_required('rr_ref_db'), $ref_taxa, $ref_dump_dir);

        $self->dataflow_output_id( { 'genome_db_id' => $genome_db_id, 'ref_taxa' => $ref_taxa }, 1 );

        foreach my $ref ( @$ref_dirs ) {
            # Skip the reference genome if it is the same as the query genome
            next if $ref->{'ref_gdb'}->name eq $gdb_adaptor->fetch_by_dbID($genome_db_id)->name;
            # Obtain the diamond indexed file for the reference, this is the only file we need from
            # each reference at this point
            my $ref_dmnd_path = $ref->{'ref_dmnd'};
            my $target_genome_db_id = $ref->{'ref_gdb'}->dbID;
            for ( my $i = 0; $i < @$query_members; $i+=($step+1) ) {
                my @job_list = @$query_members[$i..$i+$step];
                my @job_array  = grep { defined && m/[^\s]/ } @job_list; # because the array is very rarely going to be exactly divisible by $step
                # A job is output for every $step query members against each reference diamond db
                my $output_id = { 'member_id_list' => \@job_array, 'blast_db' => $ref_dmnd_path, 'genome_db_id' => $genome_db_id, 'target_genome_db_id' => $target_genome_db_id, 'ref_taxa' => $ref_taxa };
                $self->dataflow_output_id($output_id, 2);
            }
            push @funnel_output, { 'ref_genome_db_id' => $target_genome_db_id, 'genome_db_id' => $genome_db_id };
        }
    }
    $self->dataflow_output_id( { 'genome_db_pairs' => \@funnel_output }, 3 );
}

1;
