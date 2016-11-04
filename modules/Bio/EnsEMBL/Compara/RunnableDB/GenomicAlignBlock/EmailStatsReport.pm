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
	my $epo_url   = $self->dbc->url;
	my $stats_cmd = "$stats_exe -url $epo_url -html";

	# run command, capture output
	my $stats_string = `$stats_cmd`;

	# save to param to be added into email body
	$self->param('stats_table', $stats_string);
}

1;