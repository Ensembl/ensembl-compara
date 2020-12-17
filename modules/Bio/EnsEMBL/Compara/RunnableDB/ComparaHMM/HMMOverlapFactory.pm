
package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMOverlapFactory;

use strict;
use warnings;

use File::Path;
use File::Spec;

use Bio::EnsEMBL::Hive::AnalysisJob;
use Bio::EnsEMBL::Hive::Utils ('dir_revhash');

use base ('Bio::EnsEMBL::Hive::Process');

my $job_index = 0;
sub param_defaults {
    return {
        'filename'      => 'overlaps.#label#.txt',
        'filename'      => 'hits.#label#.txt',
        'output_file'   => '#output_dir#/#filename#',
    };
}
sub run {
    my $self = shift;

    my @chunk_paths = ();
    open(my $fh, '<', $self->param_required('chunk_list'));
    while(my $line = <$fh>) {
        chomp $line;
        push @chunk_paths, $line;
    }
    close $fh;

    my $filename = $self->param_required('filename');
    my @input_files = map {File::Spec->catfile($_, $filename)} @chunk_paths;

    $job_index = 0;
    $self->create_jobs(\@input_files);
}

sub create_jobs {
    my $self = shift;
    my $list = shift;
    my $funnelest_funnel = $self->rec_split($self->param_required('n'), $list)->[0];
    $funnelest_funnel->{'parameters'}->{'output_file'} = $self->param_required('output_file');
    use Data::Dumper;
    warn Dumper($funnelest_funnel);
    #return;

    my $analysis_collection = $self->input_job->hive_pipeline->collection_of('Analysis');
    my $analysis_recursive = $analysis_collection->find_one_by('name', $self->param_required('anaysis_name_recursive'));
    
    $self->rec_store_jobs($funnelest_funnel, $analysis_recursive);
}

sub rec_store_jobs {
    my $self = shift;
    my $job_description = shift;
    my $analysis = shift;
    my $controlled_semaphore = shift;

    my $emitting_job = $self->input_job;
    my $job_adaptor  = $emitting_job->adaptor;
    
    my $job = Bio::EnsEMBL::Hive::AnalysisJob->new(
        'prev_job'          => $emitting_job,
        'analysis'          => $analysis,
        'hive_pipeline'     => $emitting_job->hive_pipeline,
        'param_id_stack'    => '',
        'accu_id_stack'     => '',
        'input_id'          => $job_description->{'parameters'},
        'controlled_semaphore'  => $controlled_semaphore // $emitting_job->controlled_semaphore,
    );

    if (my @previous_jobs = @{$job_description->{'previous_jobs'}}) {
        my ($semaphore_id, $funnel_job_id, @fan_job_ids) = $job_adaptor->store_a_semaphored_group_of_jobs($job, []);
        my $semaphore = $job_adaptor->db->get_SemaphoreAdaptor->fetch_by_dbID($semaphore_id);
        my @fan_jobs = map {$self->rec_store_jobs($_, $analysis, $semaphore)} @previous_jobs;
        $job_adaptor->semaphore_job_by_id($funnel_job_id);
    } else {
        my ($job_id) = $job_adaptor->store_jobs_and_adjust_counters([$job], 0);
    }
    return $job;
}

sub split {
    my $self = shift;
    my $n = shift;
    my $list = shift;

    my $work_dir = $self->param_required('work_dir');
    my $label = $self->param_required('label');

    my @in = (@$list,);
    my @out;
    while (@in) {
        $job_index++;
        my $out_dir = File::Spec->catfile($work_dir, dir_revhash($job_index));
        mkpath($out_dir);
        my @input_list = splice(@in, 0, $n);
        if (scalar(@input_list) == 1) {
            push @out, @input_list;
        } else {
            push @out, {
                'previous_jobs' => [grep {ref($_)} @input_list],
                'parameters'    => {
                    'input_list'    => [map {ref($_) ? $_->{'parameters'}->{'output_file'} : $_} @input_list],
                    'output_file'   => File::Spec->catfile($out_dir, "temp_overlaps.$label.$job_index.txt"),
                },
            };
        }
    }
    return \@out;
}

sub rec_split {
    my $self = shift;
    my $n = shift;
    my $list = shift;
    while (scalar(@$list) > 1) {
        $list = $self->split($n, $list);
    }
    return $list;
}

1;
