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

=cut


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::SqlHealthChecks.

=head1 DESCRIPTION

This runnable offers various groups of healthchecks to check the
integrity of a master database which has been updated with the
PrepareMasterDatabaseForRelease pipeline

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::SqlHealthChecks;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck');



my $config = {


    ## ensure no duplicate names ##
    ###############################

    taxonomy => {
        # params => [ 'method_link_species_set_id' ],
        tests => [
            {
                description => 'taxon has duplicate names',
                query => 'SELECT taxon_id,name,name_class,count(*) FROM ncbi_taxa_name GROUP BY taxon_id,name,name_class HAVING count(*) > 1',
                expected_size => 0,
            },
            {
                description => 'genome_db taxon_ids are valid',
                query => 'SELECT genome_db.* FROM genome_db LEFT JOIN ncbi_taxa_node USING (taxon_id) WHERE genome_db.taxon_id IS NOT NULL AND ncbi_taxa_node.taxon_id IS NULL',
                expected_size => 0,
            }
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
