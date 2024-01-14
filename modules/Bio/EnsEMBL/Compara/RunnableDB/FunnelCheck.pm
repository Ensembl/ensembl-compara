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

Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck

=head1 DESCRIPTION

Checks status of semaphore which was set to block the current funnel job.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'manual_ok' => 0,  # set to 1 to skip the funnel check
    }
}

sub run {
    my $self = shift;

    if ($self->param('manual_ok')) {
        $self->complete_early("manual_ok - skipping funnel check");
    }

    my $job_id = $self->input_job->dbID;

    if (!defined $job_id) {
        $self->die_no_retry("cannot check semaphore of job - job_id undefined");
    }

    my $sql = q/
        SELECT
            job.job_id AS job_id
        FROM
            job
        JOIN
            semaphore ON job.controlled_semaphore_id = semaphore.semaphore_id
        JOIN
            job AS dep_job ON semaphore.dependent_job_id = dep_job.job_id
        WHERE
            dep_job.job_id = ?
        AND
            job.status NOT IN ('DONE', 'PASSED_ON')
    /;

    my $helper             = $self->db->dbc->sql_helper;
    my $result             = $helper->execute_simple(-SQL => $sql, -PARAMS => [$job_id]);
    my @unresolved_job_ids = @{$result};

    if (scalar(@unresolved_job_ids) > 0) {
        $self->die_no_retry(
            sprintf(
                "apparent semaphore failure - %d unresolved fan jobs: %s",
                scalar(@unresolved_job_ids), join(', ', @unresolved_job_ids)
            )
        );
    }
}


1;
