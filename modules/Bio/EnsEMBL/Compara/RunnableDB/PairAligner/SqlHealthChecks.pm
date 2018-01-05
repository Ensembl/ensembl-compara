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


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SqlHealthChecks.

=head1 DESCRIPTION

This runnable offers various groups of healthchecks to check the
integrity of a PairAligner production database

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SqlHealthChecks;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck');



my $config = {


    ### Blocks partially written
    ############################

    gab_inconsistencies => {
        params => [ 'method_link_species_set_id' ],
        tests => [
            {
                description => 'genomic_align_block entries must be linked to genomic_align',
                query => 'SELECT gab.genomic_align_block_id FROM genomic_align_block gab LEFT JOIN genomic_align ga USING (genomic_align_block_id) WHERE ga.genomic_align_block_id IS NULL AND gab.method_link_species_set_id = #method_link_species_set_id#',
            },
            {
                description => 'genomic_align_block entries must be linked to at least two genomic_align entries',
                query => 'SELECT gab.genomic_align_block_id, ga.genomic_align_id FROM genomic_align_block gab JOIN genomic_align ga USING (genomic_align_block_id) WHERE gab.method_link_species_set_id = #method_link_species_set_id# GROUP BY genomic_align_block_id HAVING COUNT(*) < 2',
            },
            
        ],
    },

};


sub fetch_input {
    my $self = shift;

    my $mode = $self->param_required('mode');
    die unless exists $config->{$mode};
    my $this_config = $config->{$mode};

    foreach my $param_name (@{$this_config->{params}}) {
        $self->param_required($param_name);
    }
    $self->param('tests', $this_config->{tests});
    $self->_validate_tests;
}


1;

