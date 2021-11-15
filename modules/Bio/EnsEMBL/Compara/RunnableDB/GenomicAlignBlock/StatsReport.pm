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

Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::StatsReport

=head1 DESCRIPTION

Wraps msa_stats.pl script and stores its output in the shared MSA stats folder. The TSV file has
the method type of the given MLSS ID as prefix.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::StatsReport;

use strict;
use warnings;

use File::Path qw/make_path/;

use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;
use Bio::EnsEMBL::Compara::Utils::FlatFile qw( dump_string_into_file );

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $mlss_id = $self->param_required('mlss_id');
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    $self->param('method_name', lc $mlss->method->type);

    make_path($self->param_required('msa_stats_shared_dir'));
}


sub run {
    my $self = shift @_;

    # Run epo_stats.pl and capture the output
    my $stats_exe = $self->param_required('stats_exe');
    my $db_url    = $self->compara_dba->url;
    my $stats_cmd = [ $stats_exe, '-url', $db_url, '-mlss_id', $self->param('mlss_id') ];
    my $output = $self->get_command_output($stats_cmd);

    $self->param('stats_table', $output);
}


sub write_output {
    my $self = shift @_;

    my $stats_table = $self->param('stats_table');
    my $dump_file = $self->param('msa_stats_shared_dir') . '/' . $self->param('method_name') . '.tsv';
    dump_string_into_file($dump_file, $stats_table);
}


1;
