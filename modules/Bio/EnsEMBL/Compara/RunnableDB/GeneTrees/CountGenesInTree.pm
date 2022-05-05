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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CountGenesInTree

=head1 DESCRIPTION

Wraps count_genes_in_tree.pl script.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CountGenesInTree;

use strict;
use warnings;

use JSON qw(decode_json);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift @_;

    my $db_url = $self->compara_dba->url;
    my $mlss_id = $self->param_required('mlss_id');
    my $genome_db_id = $self->param_required('genome_db_id');
    my $gene_count_exe = $self->param_required('gene_count_exe');

    my $cmd = [ $gene_count_exe, '-url', $db_url, '-mlss_id', $mlss_id, '-genome_db_id', $genome_db_id ];
    Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec($cmd, { die_on_failure => 1 });
}


1;
