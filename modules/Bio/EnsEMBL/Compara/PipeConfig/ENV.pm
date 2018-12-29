=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::ENV

=head1 DESCRIPTION

Environment-dependent pipeline configuration,

=head1 CONTACT

  Please contact Compara or Ensembl Genomes with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ENV;

use strict;
use warnings;


=head2 shared_options

  Description : Options available within "default_options", i.e. $self->o(),
                on all Compara pipelines

=cut

sub shared_default_options {
    my ($self) = @_;
    return {
        # User details
        'email'                 => $ENV{'USER'}.'@ebi.ac.uk',

        # All the fixed parameters that depend on a "division" parameter
        'reg_conf'              => $self->check_file_in_ensembl('ensembl-compara/scripts/pipeline/production_reg_'.$self->o('division').'_conf.pl'),
        'genome_dumps_dir'      => '/hps/nobackup2/production/ensembl/compara_ensembl/genome_dumps/'.$self->o('division').'/',
    }
}


=head2 executable_locations

  Description : Locations to all the executables and other external dependencies.
                As executable_locations is included in "default_options", they are
                all available through $self->o().

=cut

sub executable_locations {
    my ($self) = @_;
    return {
        # External dependencies (via linuxbrew)
        'axtChain_exe'              => $self->check_exe_in_cellar('kent/v335_1/bin/axtChain'),
        'big_bed_exe'               => $self->check_exe_in_cellar('kent/v335_1/bin/bedToBigBed'),
        'big_wig_exe'               => $self->check_exe_in_cellar('kent/v335_1/bin/bedGraphToBigWig'),
        'bl2seq_exe'                => undef,   # We use blastn instead
        'blast_bin_dir'             => $self->check_dir_in_cellar('blast/2.2.30/bin'),
        'blastn_exe'                => $self->check_exe_in_cellar('blast/2.2.30/bin/blastn'),
        'blat_exe'                  => $self->check_exe_in_cellar('kent/v335_1/bin/blat'),
        'cafe_shell'                => $self->check_exe_in_cellar('cafe/2.2/bin/cafeshell'),
        'cdhit_exe'                 => $self->check_exe_in_cellar('cd-hit/4.6.8/bin/cd-hit'),
        'chainNet_exe'              => $self->check_exe_in_cellar('kent/v335_1/bin/chainNet'),
        'cmalign_exe'               => $self->check_exe_in_cellar('infernal/1.1.2/bin/cmalign'),
        'cmbuild_exe'               => $self->check_exe_in_cellar('infernal/1.1.2/bin/cmbuild'),
        'cmsearch_exe'              => $self->check_exe_in_cellar('infernal/1.1.2/bin/cmsearch'),
        'codeml_exe'                => $self->check_exe_in_cellar('paml43/4.3.0/bin/codeml'),
        'enredo_exe'                => $self->check_exe_in_cellar('enredo/0.5.0/bin/enredo'),
        'erable_exe'                => $self->check_exe_in_cellar('erable/1.0/bin/erable'),
        'esd2esi_exe'               => $self->check_exe_in_cellar('exonerate24/2.4.0/bin/esd2esi'),
        'estimate_tree_exe'         => $self->check_file_in_cellar('pecan/0.8.0/libexec/bp/pecan/utils/EstimateTree.py'),
        'examl_exe_avx'             => $self->check_exe_in_cellar('examl/3.0.17/bin/examl-AVX'),
        'examl_exe_sse3'            => $self->check_exe_in_cellar('examl/3.0.17/bin/examl'),
        'exonerate_exe'             => $self->check_exe_in_cellar('exonerate24/2.4.0/bin/exonerate'),
        'extaligners_exe_dir'       => $self->o('linuxbrew_home').'/bin/',   # We expect the latest version of each aligner to be symlinked there
        'fasta2esd_exe'             => $self->check_exe_in_cellar('exonerate24/2.4.0/bin/fasta2esd'),
        'fasttree_exe'              => $self->check_exe_in_cellar('fasttree/2.1.8/bin/FastTree'),
        'faToNib_exe'               => $self->check_exe_in_cellar('kent/v335_1/bin/faToNib'),
        'gerp_exe_dir'              => $self->check_dir_in_cellar('gerp/20080211_1/bin'),
        'getPatterns_exe'           => $self->check_exe_in_cellar('raxml-get-patterns/1.0/bin/getPatterns'),
        'halStats_exe'              => $self->check_exe_in_cellar('hal/1a89bd2/bin/halStats'),
        'hcluster_exe'              => $self->check_exe_in_cellar('hclustersg/0.5.0/bin/hcluster_sg'),
        'hmmer2_home'               => $self->check_dir_in_cellar('hmmer2/2.3.2/bin'),
        'hmmer3_home'               => $self->check_dir_in_cellar('hmmer/3.1b2_1/bin'),
        'java_exe'                  => $self->check_exe_in_linuxbrew_opt('jdk@8/bin/java'),
        'ktreedist_exe'             => $self->check_exe_in_cellar('ktreedist/1.0.0/bin/Ktreedist.pl'),
        'lastz_exe'                 => $self->check_exe_in_cellar('lastz/1.04.00/bin/lastz'),
        'lavToAxt_exe'              => $self->check_exe_in_cellar('kent/v335_1/bin/lavToAxt'),
        'mafft_exe'                 => $self->check_exe_in_cellar('mafft/7.305/bin/mafft'),
        'mafft_home'                => $self->check_dir_in_cellar('mafft/7.305'),
        'mash_exe'                  => $self->check_exe_in_cellar('mash/2.0/bin/mash'),
        'mcl_bin_dir'               => $self->check_dir_in_cellar('mcl/14-137/bin'),
        'mcoffee_home'              => $self->check_dir_in_cellar('t-coffee/9.03.r1336_3'),
        'mercator_exe'              => $self->check_exe_in_cellar('cndsrc/2013.01.11/bin/mercator'),
        'mpirun_exe'                => $self->check_exe_in_cellar('open-mpi/2.1.1/bin/mpirun'),
        'noisy_exe'                 => $self->check_exe_in_cellar('noisy/1.5.12/bin/noisy'),
        'notung_jar'                => $self->check_file_in_cellar('notung/2.6.0/libexec/Notung-2.6.jar'),
        'ortheus_bin_dir'           => $self->check_dir_in_cellar('ortheus/0.5.0_1/bin'),
        'ortheus_c_exe'             => $self->check_exe_in_cellar('ortheus/0.5.0_1/bin/ortheus_core'),
        'ortheus_lib_dir'           => $self->check_dir_in_cellar('ortheus/0.5.0_1'),
        'ortheus_py'                => $self->check_exe_in_cellar('ortheus/0.5.0_1/bin/Ortheus.py'),
        'pantherScore_path'         => $self->check_dir_in_cellar('pantherscore/1.03'),
        'parse_examl_exe'           => $self->check_exe_in_cellar('examl/3.0.17/bin/parse-examl'),
        'parsimonator_exe'          => $self->check_exe_in_cellar('parsimonator/1.0.2/bin/parsimonator-SSE3'),
        'pecan_exe_dir'             => $self->check_dir_in_cellar('pecan/0.8.0/libexec'),
        'prank_exe'                 => $self->check_exe_in_cellar('prank/140603/bin/prank'),
        'prottest_jar'              => $self->check_file_in_cellar('prottest3/3.4.2/libexec/prottest-3.4.2.jar'),
        'quicktree_exe'             => $self->check_exe_in_cellar('quicktree/2.1/bin/quicktree'),
        'r2r_exe'                   => $self->check_exe_in_cellar('r2r/1.0.5/bin/r2r'),
        'rapidnj_exe'               => $self->check_exe_in_cellar('rapidnj/2.3.2/bin/rapidnj'),
        'raxml_exe_avx'             => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-AVX'),
        'raxml_exe_sse3'            => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-SSE3'),
        'raxml_pthread_exe_avx'     => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-PTHREADS-AVX'),
        'raxml_pthread_exe_sse3'    => $self->check_exe_in_cellar('raxml/8.2.8/bin/raxmlHPC-PTHREADS-SSE3'),
        'samtools_exe'              => $self->check_exe_in_cellar('samtools/1.6/bin/samtools'),
        'semphy_exe'                => $self->check_exe_in_cellar('semphy/2.0b3/bin/semphy'), #semphy program
        'server_exe'                => $self->check_exe_in_cellar('exonerate24/2.4.0/bin/exonerate-server'),
        'treebest_exe'              => $self->check_exe_in_cellar('treebest/88/bin/treebest'),
        'trimal_exe'                => $self->check_exe_in_cellar('trimal/1.4.1/bin/trimal'),
        'xmllint_exe'               => $self->check_exe_in_linuxbrew_opt('libxml2/bin/xmllint'),

        # Internal dependencies (Compara scripts)
        'ancestral_dump_program'            => $self->check_exe_in_ensembl('ensembl-compara/scripts/ancestral_sequences/get_ancestral_sequence.pl'),
        'ancestral_stats_program'           => $self->check_exe_in_ensembl('ensembl-compara/scripts/ancestral_sequences/get_stats.pl'),
        'BuildSynteny_exe'                  => $self->check_file_in_ensembl('ensembl-compara/scripts/synteny/BuildSynteny.jar'),
        'compare_beds_exe'                  => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/compare_beds.pl'),
        'create_pair_aligner_page_exe'      => $self->check_exe_in_ensembl('ensembl-compara/scripts/report/create_pair_aligner_page.pl'),
        'dump_aln_program'                  => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/DumpMultiAlign.pl'),
        'dump_features_exe'                 => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/dump_features.pl'),
        'dump_species_tree_exe'             => $self->check_exe_in_ensembl('ensembl-compara/scripts/examples/species_getSpeciesTree.pl'),
        'DumpGFFAlignmentsForSynteny_exe'   => $self->check_exe_in_ensembl('ensembl-compara/scripts/synteny/DumpGFFAlignmentsForSynteny.pl'),
        'DumpGFFHomologuesForSynteny_exe'   => $self->check_exe_in_ensembl('ensembl-compara/scripts/synteny/DumpGFFHomologuesForSynteny.pl'),
        'emf2maf_program'                   => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/emf2maf.pl'),
        'epo_stats_report_exe'              => $self->check_exe_in_ensembl('ensembl-compara/scripts/production/epo_stats.pl'),
        'populate_new_database_exe'         => $self->check_exe_in_ensembl('ensembl-compara/scripts/pipeline/populate_new_database.pl'),
    };
}


1;

