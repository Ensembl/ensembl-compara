
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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ExaML;

use strict;
use warnings;
use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML');

sub param_defaults {
    my $self = shift;
    return {
        # Note that Examl needs MPI and has to be run through mpirun
        %{ $self->SUPER::param_defaults },
		'newest_checkPointFile'=> undef,
		'cmd_checkpoint'       => 'cp #examl_dir#/#worker_dir#/#gene_tree_id#.binary . ; cp #newest_checkPointFile# latest_ExaML_binaryCheckpoint.#gene_tree_id# ; sleep 10 ; #mpirun_exe# #examl_exe# -s #gene_tree_id#.binary -R latest_ExaML_binaryCheckpoint.#gene_tree_id# -m GAMMA -n #gene_tree_id# -S',
		'cmd_from_scratch'     => '#parse_examl_exe# -s align.#gene_tree_id#.phylip -m #sequence_type# -n #gene_tree_id# ; sleep 10 ; #mpirun_exe# #examl_exe# -s #gene_tree_id#.binary -t gene_tree_#gene_tree_id#.nhx -m GAMMA -n #gene_tree_id# -S',
        'aln_format'           => 'phylip',
        'runtime_tree_tag'     => 'examl_runtime',
        'output_clusterset_id' => 'raxml',
        'input_clusterset_id'  => 'raxml_parsimony',
        'output_file'          => 'ExaML_result.#gene_tree_id#',
        'info_file'            => 'ExaML_info.#gene_tree_id#',
        'sequence_type'        => '#expr(#use_dna_for_phylogeny# ? "DNA" : "PROT")expr#',
        'remove_columns'       => 1,
        'ryo_gene_tree'     => '%{-m}%{"_"-x}',

    };
}

sub fetch_input {
    my $self = shift;

	#We should inherit from GenericRunnable here since we will need the gene_tree object.
    $self->SUPER::fetch_input();

    # Auto-select for the SSE3-only or AVX-enabled version
    my $avx = `grep avx /proc/cpuinfo`;
    if ($avx) {
        $self->param( 'examl_exe', $self->param('examl_exe_avx') );
        $avx = "AVX";
    }
    else {
        $self->param( 'examl_exe', $self->param('examl_exe_sse3') );
        $avx = "SSE3";
    }

    print "CPU type: $avx\n" if ( $self->debug );

	#Best-fit model	
    my $best_fit_model = $self->set_raxml_model();
    $self->param( 'best_fit_model', $best_fit_model );
    print "best-fit model: " . $self->param('best_fit_model') . "\n" if ( $self->debug );

	# Auto select if there are any checkpoints for a particular root_id
	my $root_id = $self->param('gene_tree_id');
	my $source_dir = $self->param('examl_dir');

	my @dir = `find $source_dir -name $root_id.binary | xargs ls -t`;
	my @tok = split(/\//,$dir[0]);
	my $worker_dir = $tok[-2];
	my @list = `ls -t $source_dir/$worker_dir/ExaML_binaryCheckpoint*`;
	if ((scalar(@list) > 0) && (!-z $list[0])){
		chomp($list[0]);
		$self->param('newest_checkPointFile',$list[0]);
	}
	$self->param('worker_dir',$worker_dir);

    if ($self->param('newest_checkPointFile')) {
		$self->param('cmd',$self->param('cmd_checkpoint'));

        my $restarts = $self->param('default_gene_tree')->get_value_for_tag('examl_restarts') + 1;
        $self->param('default_gene_tree')->store_tag('examl_restarts', $restarts);

        print "ExaML will run on Check Point mode using the file " . $self->param('newest_checkPointFile') . " as a checkpoint\n" if ($self->debug);
		print "CMD:" . $self->param('cmd_checkpoint') . "\n" if ($self->debug);
    }
    else {
		$self->param('cmd',$self->param('cmd_from_scratch'));

        $self->param('default_gene_tree')->store_tag('examl_restarts', 0);

        print "No checkpoint was found running on standard mode\n" if ($self->debug);
		print "CMD:" . $self->param('cmd_from_scratch') . "\n" if ($self->debug);
    }

}

sub write_output {
    my $self = shift;

    my $overall_time;
    open( my $info_file, "<", $self->worker_temp_directory.'/'.$self->param('info_file') ) || die "Could not open info_file";
    while (<$info_file>) {
        if ( $_ =~ /^Overall accumulated Time/ ) {
            print $_;
			my @tok = split (/\s/,$_);
			$overall_time = $tok[7];
        }
    }

    #We need to have the run times in milliseconds
    $overall_time *= 1000;

    print "overall_running_time: $overall_time\n" if $self->debug;
    $self->param('runtime_msec',$overall_time);

    $self->SUPER::write_output();
}


## Because Examl is using MPI, it has to be run in a shared directory
#  Here we override the eHive method to use #examl_dir# instead
sub worker_temp_directory_name {
    my $self = shift @_;

    my $username = $ENV{'USER'};
    my $worker_id = $self->worker ? $self->worker->dbID : "standalone.$$";
    my $worker_dir = $self->param('examl_dir')."/worker_${username}.${worker_id}/";
    #system("chmod 775 -R $worker_id");
    return $self->param('examl_dir')."/worker_${username}.${worker_id}/";
}


1;
