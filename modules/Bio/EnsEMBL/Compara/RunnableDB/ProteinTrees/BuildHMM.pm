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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a ProteinTree as input
This must already have a multiple alignment run on it. It uses that alignment
as input create a HMMER HMM profile

input_id/parameters format eg: "{'gene_tree_id'=>1234}"
    gene_tree_id : use 'id' to fetch a cluster from the ProteinTree

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::AlignedMemberSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadModels', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');

sub param_defaults {
    return {
        'cdna'              => 0,

        'hmmer_version'     => 2,       # 2 or 3
        'hmmbuild_exe'      => '#hmmer_home#/hmmbuild',
        'hmmcalibrate_exe'  => '#hmmer_home#/hmmcalibrate',
        'hmmemit_exe'       => '#hmmer_home#/hmmemit',
    };
}



sub fetch_input {
    my $self = shift @_;

    my $protein_tree_id     = $self->param_required('gene_tree_id');
    my $protein_tree        = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID( $protein_tree_id )
                                        or die "Could not fetch protein_tree with gene_tree_id='$protein_tree_id'";
    $self->param('protein_tree', $protein_tree);

    my $hmm_type = 'tree_hmm_';
    $hmm_type .= $self->param('cdna') ? 'dna' : 'aa';
    $hmm_type .= '_v'.$self->param_required('hmmer_version');

    if ($self->param('notaxon')) {
        $hmm_type .= "_notaxon" . "_" . $self->param('notaxon');
    }
    if ($self->param('taxon_ids')) {
        $hmm_type .= "_" . join(':', @{$self->param('taxon_ids')});
    }
    $self->param('type', $hmm_type);

    my $members = $protein_tree->alignment->get_all_Members;
    if ($self->param('notaxon')) {
        my $newmembers = [];
        foreach my $member (@$members) {
            push @$newmembers, $member unless ($member->taxon_id eq $self->param('notaxon'));
        }
        $members = $newmembers;
    }

    if ($self->param('taxon_ids')) {
        my $taxon_ids_to_keep;
        foreach my $taxon_id (@{$self->param('taxon_ids')}) {
            $taxon_ids_to_keep->{$taxon_id} = 1;
        }
        my $newmembers = [];
        foreach my $member (@$members) {
            push @$newmembers, $member  if (defined($taxon_ids_to_keep->{$member->taxon_id}));
        }
        $members = $newmembers;
    }

    if (scalar @$members < 2) {
        $self->complete_early(sprintf('No HMM will be buid (only %d members).', scalar(@$members)));
    }

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->compara_dba->get_SequenceAdaptor, $protein_tree->member_type, $members);

    $self->param('protein_align', Bio::EnsEMBL::Compara::AlignedMemberSet->new(-dbid => $self->param('gene_tree_id'), -members => $members));
    $self->param('protein_align')->{'_member_type'} = $protein_tree->member_type;

    $self->require_executable('hmmbuild_exe');
    $self->require_executable('hmmcalibrate_exe') if $self->param('hmmer_version') eq '2';
    $self->require_executable('hmmemit_exe');

}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs hmmbuild
    Returns :   none
    Args    :   none

=cut


sub run {
    my $self = shift @_;
    $self->run_buildhmm;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores hmmprofile
    Returns :   none
    Args    :   none

=cut


sub write_output {
    my $self = shift @_;

    $self->db->dbc->disconnect_if_idle();
    $self->store_hmmprofile($self->param('hmm_file'), $self->param('protein_tree')->stable_id || $self->param('gene_tree_id'));
}



##########################################
#
# internal methods
#
##########################################


sub run_buildhmm {
    my $self = shift;

    $self->param('hidden_genes', [] );
    $self->merge_split_genes($self->param('protein_tree')) if $self->param('check_split_genes');


    my $aln_file;
    if ( $self->param('include_thresholds') ) {

        my %thresholds = ();
        if ( $self->param('protein_tree')->has_tag('trusted_cutoff') ) {
            $thresholds{'TC'} = $self->param('protein_tree')->get_value_for_tag('trusted_cutoff') . " " .  $self->param('protein_tree')->get_value_for_tag('trusted_cutoff');
        }

        if ( $self->param('protein_tree')->has_tag('noise_cutoff') ) {
            $thresholds{'NC'} = $self->param('protein_tree')->get_value_for_tag('noise_cutoff') . " " . $self->param('protein_tree')->get_value_for_tag('noise_cutoff');
        }

        $aln_file = $self->dumpTreeMultipleAlignmentToWorkdir( $self->param('protein_align'), 'stockholm', {-ANNOTATIONS => \%thresholds} );
    }
    else {
        $aln_file = $self->dumpTreeMultipleAlignmentToWorkdir( $self->param('protein_align'), $self->param('hmmer_version') == 2 ? 'fasta' : 'stockholm' );
    }

    my $hmm_file = $self->param('hmm_file', $aln_file . '_hmmbuild.hmm');

    ## as in treefam
    # $hmmbuild --amino -g -F $file.hmm $file >/dev/null
    my $cmd = join(' ',
            $self->param('hmmbuild_exe'),
            ($self->param('cdna') ? ($self->param_required('hmmer_version') eq '2' ? '--nucleic' : '--dna') : '--amino'),
            $self->param_required('hmmer_version') eq '2' ? '-F' : '',
            '-n', $self->param('protein_tree')->stable_id || $self->param('gene_tree_id'),
            $hmm_file,
            $aln_file
    );
    my $cmd_out = $self->run_command($cmd, { die_on_failure => 1 });
    unless ((-e $hmm_file) and (-s $hmm_file)) {
        # The file is not there / empty ... MEMLIMIT going on ? Let's have
        # a break and give LSF the chance to kill us
        sleep 30;
    }

    my $runtime_msec = $cmd_out->runtime_msec;
    if ($self->param_required('hmmer_version') eq '2') {
        my $success = 0;
        my $num;
        my $use_cpu_option = 1;
        do {
            $cmd = join(' ',
                $self->param('hmmcalibrate_exe'),
                $use_cpu_option ? '--cpu 1' : '',
                $num ? sprintf(' --num %d', $num) : '',
                $hmm_file);
            my $cmd_out2 = $self->run_command($cmd);
            if ($cmd_out2->exit_code) {
                if ($cmd_out2->err =~ /fit failed; --num may be set too small/) {
                    $num = 5000 unless $num; # default in hmmcalibrate
                    $num *= 3;
                    if ($num > 1e8) {
                        $self->input_job->transient_error(0);
                        die "Cannot calibrate the HMM (tried --num values up until 1e8)";
                    }
                    $self->warning("Increasing --num to $num");
                } elsif ($cmd_out2->err =~ /Posix threads support is not compiled into HMMER/) {
                    $use_cpu_option = 0;
                } else {
                    die sprintf("Could not run hmmcalibrate\n%s\n%s", $cmd_out2->out, $cmd_out2->err);
                }
            } else {
                $success = 1;
            }
            $runtime_msec += $cmd_out2->runtime_msec
        } until ($success);
    }

    $self->param('protein_tree')->store_tag('BuildHMM_runtime_msec', $runtime_msec);
}


1;
