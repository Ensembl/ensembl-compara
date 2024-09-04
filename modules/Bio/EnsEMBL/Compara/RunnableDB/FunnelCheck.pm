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

use List::Util qw(min);

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

    my $helper = $self->db->dbc->sql_helper;

    my $factory_sql = q/
        SELECT
            factory_job.status IN ('DONE', 'PASSED_ON')
        FROM
            job AS funnel_job
        JOIN
            job AS factory_job ON factory_job.job_id = funnel_job.prev_job_id
        WHERE
            funnel_job.job_id = ?
    /;

    my $factory_job_resolved = $helper->execute_single_result(-SQL => $factory_sql, -PARAMS => [$job_id]);

    if (!$factory_job_resolved) {
        $self->die_no_retry("funnel check failure - unresolved factory job");
    }

    my $fan_sql = q/
        SELECT
            job.job_id AS job_id,
            job.status AS status
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

    # We may need to retry to ensure all fan jobs are resolved.
    my $max_retry_count = $self->input_job->analysis->max_retry_count // 3;

    my @unresolved_job_ids;
    my $time_before_next_retry;
    foreach my $attempt_index (0 .. $max_retry_count) {

        my $results = $helper->execute(-SQL => $fan_sql, -PARAMS => [$job_id], -USE_HASHREFS => 1);

        @unresolved_job_ids = map { $_->{'job_id'} } @$results;
        if (scalar(@unresolved_job_ids) == 0) {
            last;
        } else {
            my @failed_job_ids = map { $_->{'job_id'} } grep { $_->{'status'} eq 'FAILED' } @$results;
            if (scalar(@failed_job_ids) > 0) {
                $self->die_no_retry(
                    sprintf(
                        "apparent semaphore failure - %d failed fan jobs (e.g. %s)",
                        scalar(@failed_job_ids), join(', ', @failed_job_ids[0 .. 2])
                    )
                );
            }
        }

        if ($attempt_index < $max_retry_count) {
            $time_before_next_retry = min(30 * (2 ** $attempt_index), 3600);
            $self->warning(
                sprintf(
                    "%d unresolved fan jobs found on attempt %d, retrying in %d seconds",
                    scalar(@unresolved_job_ids), ($attempt_index + 1), $time_before_next_retry
                )
            );
            sleep($time_before_next_retry);
        }
    }

    if (scalar(@unresolved_job_ids) > 0) {
        my @example_unresolved_job_ids = scalar(@unresolved_job_ids) > 3 ? @unresolved_job_ids[0 .. 2] : @unresolved_job_ids;
        $self->die_no_retry(
            sprintf(
                "apparent semaphore failure due to %d unresolved fan jobs: (e.g. %s); please wait until all fan jobs have completed before retrying",
                scalar(@unresolved_job_ids), join(', ', @example_unresolved_job_ids)
            )
        );
    }
}


1;
