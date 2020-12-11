=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::EmailStatsReport;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::NotifyByEmail');

my $txt = <<EOF;
<html>
<h1>Statistics of #method_name# pipeline</h1>

#stats_table#

</html>
EOF

sub param_defaults {
    return {
        is_html => 1,
        text => $txt,
        'subject'   => "#pipeline_name# has completed",
    }
}

sub fetch_input {
	my $self = shift;

        $self->SUPER::fetch_input();    # To initialize pipeline_name

        # In case it is still a Bio::EnsEMBL::DBSQL::DBConnection
        bless $self->compara_dba->dbc, 'Bio::EnsEMBL::Hive::DBSQL::DBConnection';

	# build epo_stats.pl command
	my $stats_exe = $self->param_required('stats_exe');
	my $epo_url   = $self->compara_dba->dbc->url;
	my $stats_cmd = [$stats_exe, '-url', $epo_url, '-html'];

    my $method_name = 'the';
    if (my $mlss_id = $self->param('mlss_id')) {
        push @$stats_cmd, '-mlss_id', $mlss_id;
        my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
        $method_name = $mlss->method->display_name;
    }

	# run command, capture output
	my $stats_string = $self->get_command_output($stats_cmd);

	# save to params to be added into email body
    $self->param('method_name', $method_name);
	$self->param('stats_table', $stats_string);
}

1;
