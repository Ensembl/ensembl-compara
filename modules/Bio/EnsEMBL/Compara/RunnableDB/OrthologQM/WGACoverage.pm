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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::WGACoverage

=head1 SYNOPSIS

Wrapper around all the Runnables that compute the WGA coverage score to
compute everything within one job.

See those for a description of the algorithm and their input parameters.

Below, "IN" and "OUT" represent the job parameters that are used and set.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::WGACoverage;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs;
use Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CalculateWGACoverage;
use Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::ReuseWGAScore;
use Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::AssignQualityScore;

# Need to use these as parent classes to allow their functions to be called with $self->
use base ('Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs', 'Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CalculateWGACoverage');

sub fetch_input {
    my $self = shift;

    # IN: species1_id
    # IN: species2_id
    # IN: homology_flatfile
    # IN: previous_wga_file
    # IN: homology_mapping_flatfile
    # IN: new_alignment
    # IN: alt_homology_db
    # OUT: orth_objects
    # OUT: reuse
    # OUT: member_info
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs::fetch_input($self);
}

sub run {
    my $self = shift;

    # IN: member_info
    # IN: orth_objects
    # OUT: orth_info
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareOrthologs::run($self);

    # IN: orth_info
    # IN: aln_mlss_ids
    # IN: alt_homology_db
    # IN: mlss_db_mapping
    # OUT: aln_ranges
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CalculateWGACoverage::fetch_input($self);

    # IN: orth_info
    # IN: mlss_db_mapping
    # IN: aln_ranges
    # OUT: orth_ids
    # OUT: qual_summary
    # OUT: max_quality
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CalculateWGACoverage::run($self);
}

sub write_output {
    my $self = shift;

    if ( $self->param('reuse') ){
        # IN: previous_wga_file
        # IN: homology_mapping_flatfile
        # IN: reuse_file (for writing)
        Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::ReuseWGAScore::write_output($self);
    }

    # IN: max_quality
    # IN: member_type
    # IN: mlss_db_mapping
    # IN: aln_mlss_ids
    # IN: output_file
    # IN: reuse_file (for reading)
    Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::AssignQualityScore::write_output($self);

    # If we want to record the scores in the ortholog_quality table
    #$self->dataflow_output_id( $self->param('qual_summary'), 3 );
}

1;
