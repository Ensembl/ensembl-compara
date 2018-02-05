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

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::EmailStatsReport;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;

use base ('Bio::EnsEMBL::Hive::RunnableDB::NotifyByEmail', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

my $txt = <<EOF;
<html>
<h1>Statistics of EPO pipeline</h1>

#stats_table#

</html>
EOF

sub param_defaults {
    return {
        is_html => 1,
        text => $txt,
        subject => 'EPO pipeline report',
    }
}

sub fetch_input {
	my $self = shift;

	# build epo_stats.pl command
	my $stats_exe = $self->param_required('stats_exe');
	my $epo_url   = $self->compara_dba->dbc->url;
	my $stats_cmd = "$stats_exe -url $epo_url -html";

        if ($self->param('mlss_id')) {
            $stats_cmd .= " -mlss_id ".$self->param('mlss_id');
        }

	# run command, capture output
        warn "CMD: $stats_cmd\n" if $self->debug;
	my $stats_string = `$stats_cmd`;

	# save to param to be added into email body
	$self->param('stats_table', $stats_string);
}

1;
