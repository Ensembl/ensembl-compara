
=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
        %{ $self->SUPER::param_defaults },
        # Note that Examl needs MPI and has to be run through mpirun.lsf
        'cmd' => '#parse_examl_exe# -s #alignment_file# -m PROT -n #gene_tree_id# ; rm RAxML_info.#gene_tree_id# ; #raxml_exe# -y -m #best_fit_model# -p 99123746531 -s #alignment_file# -n #gene_tree_id# ; mpirun.lsf -np #examl_cores# -mca btl tcp,self #examl_exe# -s #gene_tree_id#.binary -t RAxML_parsimonyTree.#gene_tree_id# -m GAMMA -n #gene_tree_id# -S',

        'aln_format'           => 'phylip',
        'runtime_tree_tag'     => 'examl_runtime',
        'output_clusterset_id' => 'raxml',
        'output_file'          => 'ExaML_result.#gene_tree_id#',
    };
}

sub fetch_input {
    my $self = shift;

    # Auto-select the SSE3-only or AVX-enabled version
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

    return $self->SUPER::fetch_input();
}

## Because Examl is using MPI, it has to be run in a shared directory
#  Here we override the eHive method to use #examl_dir# instead
sub worker_temp_directory_name {
    my $self = shift @_;

    my $username = $ENV{'USER'};
    my $worker_id = $self->worker ? $self->worker->dbID : "standalone.$$";
    return $self->param('examl_dir')."/worker_${username}.${worker_id}/";
}


1;
