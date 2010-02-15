#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Data::Dumper;  # NB: this one is not for testing but for actual data structure stringification
use Bio::EnsEMBL::Hive::DBSQL::DBAdaptor;

sub bk_url {
    my $db_conn = shift @_;

    return "mysql://$db_conn->{-user}:$db_conn->{-pass}\@$db_conn->{-host}:$db_conn->{-port}/$db_conn->{-dbname}";
}

sub main {

    Bio::EnsEMBL::Registry->no_version_check(1);

    my $config_file = 'family_pipeline.conf';

    GetOptions(
               'conf=s'     => \$config_file,
    );

    my $self = bless { do $config_file };

    foreach my $cmd (@{$self->{-pipeline_create_commands}}) {
        warn "Running the command:\n\t$cmd\n";
        if(my $retval = system($cmd)) {
            die "Return value = $retval, possibly an error\n";
        } else {
            warn "Done.\n\n";
        }
    }

    my $hive_dba              = new Bio::EnsEMBL::Hive::DBSQL::DBAdaptor(%{$self->{-pipeline_db}});
    my $analysis_adaptor      = $hive_dba->get_AnalysisAdaptor;
    my $ctrl_rule_adaptor     = $hive_dba->get_AnalysisCtrlRuleAdaptor;
#
## not yet being used by the family pipeline:
#   my $dataflow_rule_adaptor = $hive_dba->get_DataflowRuleAdaptor;

        # tune Data::Dumper module to produce the output we want:
    $Data::Dumper::Indent = 0;  # we want everything on one line
    $Data::Dumper::Terse  = 1;   # and we want it without dummy variable names

    foreach my $aha (@{$self->{-pipeline_analyses}}) {
        my ($logic_name, $module, $parameters, $input_ids, $blocked, $wait_for, $batch_size, $hive_capacity) =
            ($aha->{-logic_name}, $aha->{-module}, $aha->{-parameters}, $aha->{-input_ids},
             $aha->{-blocked}, $aha->{-wait_for}, $aha->{-batch_size}, $aha->{-hive_capacity});

        warn "Creating '$logic_name'...\n";

        my $analysis = Bio::EnsEMBL::Analysis->new (
            -db              => '',
            -db_file         => '',
            -db_version      => '1',
            -logic_name      => $logic_name,
            -module          => $module,
            -parameters      => Dumper($parameters),
        );

        $analysis_adaptor->store($analysis);

        my $stats = $analysis->stats();
        $stats->batch_size( $batch_size )       if(defined($batch_size));

            # ToDo: hive_capacity for some analyses is set to '-1'.
            # Do we want this behaviour by default?
        $stats->hive_capacity( $hive_capacity ) if(defined($hive_capacity));

            # some analyses will be waiting for human intervention in blocked state:
        $stats->status($blocked ? 'BLOCKED' : 'READY');
        $stats->update();

            # now create the corresponding jobs (if there are any):
        foreach my $input_id (@$input_ids) {

            Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
                -input_id       => Dumper($input_id),
                -analysis       => $analysis,
                -input_job_id   => 0, # jobs are created by the initialization script, not by another job
            );
        }

            # create control rules:
        foreach my $condition_logic_name (@$wait_for) {
            my $condition_analysis = $analysis_adaptor->fetch_by_logic_name($condition_logic_name);
            $ctrl_rule_adaptor->create_rule( $condition_analysis, $analysis);
        }
    }

    print "\n\n\tPlease run the following commands:\n\n";
    print "  beekeeper.pl -url ".bk_url($self->{-pipeline_db})." -sync\n";
    print "  beekeeper.pl -url ".bk_url($self->{-pipeline_db})." -loop\n";
}

main();

