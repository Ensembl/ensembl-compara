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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks.

=head1 DESCRIPTION

This runnable offers various groups of healthchecks to check the
integrity of a Family production database

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Families::SqlHealthChecks;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks');



my $config = {


    ### Members
    #############

    nonref_members => {
        params => [  ],
        tests => [
            {
                description => 'LRGs must have been loaded for human',
                query => 'SELECT * FROM gene_member JOIN genome_db USING (genome_db_id) WHERE name = "homo_sapiens" AND stable_id LIKE "LRG%"',
                expected_size => '> 0',
            },
            {
                description => 'Human must have patches',
                query => 'SELECT * FROM gene_member JOIN genome_db USING (genome_db_id) JOIN dnafrag USING (dnafrag_id) WHERE genome_db.name = "homo_sapiens" AND is_reference = 0 AND stable_id NOT LIKE "LRG%"',
                expected_size => '> 0',
            },
            {
                description => 'Mouse must have patches',
                query => 'SELECT * FROM gene_member JOIN genome_db USING (genome_db_id) JOIN dnafrag USING (dnafrag_id) WHERE genome_db.name = "mus_musculus" AND is_reference = 0',
                expected_size => '> 0',
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

