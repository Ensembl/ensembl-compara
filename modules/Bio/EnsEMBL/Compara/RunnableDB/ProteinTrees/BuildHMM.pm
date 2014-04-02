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

use Bio::EnsEMBL::Compara::AlignedMemberSet;
use Bio::EnsEMBL::Compara::HMMProfile;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree', 'Bio::EnsEMBL::Compara::RunnableDB::RunCommand');

sub param_defaults {
    return {
        'cdna'              => 0,
        'calibrate'         => 1,
        'hmmer_version'     => 2,       # 2 or 3
        'hmmbuild_exe'      => '#hmmer_home#/hmmbuild',
        'hmmcalibrate_exe'  => '#hmmer_home#/hmmcalibrate',
    };
}



sub fetch_input {
    my $self = shift @_;

    die "HMMER v3 does not need a calibration" if $self->param('calibrate') and $self->param_required('hmmer_version') eq '3';

    my $protein_tree_id     = $self->param_required('gene_tree_id');
    my $protein_tree        = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID( $protein_tree_id )
                                        or die "Could not fetch protein_tree with gene_tree_id='$protein_tree_id'";
    $self->param('protein_tree', $protein_tree);

    my $hmm_type = $self->param('cdna') ? 'dna' : 'aa';

    if ($self->param('notaxon')) {
        $hmm_type .= "_notaxon" . "_" . $self->param('notaxon');
    }
    if ($self->param('taxon_ids')) {
        $hmm_type .= "_" . join(':', @{$self->param('taxon_ids')});
    }
    $self->param('hmm_type', $hmm_type);

    my $members = $self->compara_dba->get_AlignedMemberAdaptor->fetch_all_by_GeneTree($protein_tree);
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
        $self->input_job->incomplete(0);
        die "No HMM will be buid (only ", scalar @$members, ") members\n";
    }

    $self->param('protein_align', Bio::EnsEMBL::Compara::AlignedMemberSet->new(-dbid => $self->param('gene_tree_id'), -members => $members));

    $self->require_executable('hmmbuild_exe');
    $self->require_executable('hmmcalibrate_exe') if $self->param('calibrate');

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

    $self->store_hmmprofile;
}



##########################################
#
# internal methods
#
##########################################


sub run_buildhmm {
    my $self = shift;

    my $aln_file = $self->dumpAlignedMemberSet($self->param('protein_align'), $self->param('hmmer_version') == 2 ? 'fasta' : 'stockholm');
    my $hmm_file = $self->param('hmm_file', $aln_file . '_hmmbuild.hmm');

    ## as in treefam
    # $hmmbuild --amino -g -F $file.hmm $file >/dev/null
    my $cmd = join(' ',
            $self->param('hmmbuild_exe'),
            ($self->param('cdna') ? '--dna' : '--amino'),
            $hmm_file,
            $aln_file
    );
    my $cmd_out = $self->run_command($cmd);
    die "Could not run hmmbuild: ", $cmd_out->out if ($cmd_out->exit_code);

    if ($self->param('calibrate')) {
        $cmd = sprintf('%s %s', $self->param('hmmcalibrate_exe'), $hmm_file);
        my $cmd_out2 = $self->run_command($cmd);
        die "Could not run hmmcalibrate: ", $cmd_out2->out if ($cmd_out2->exit_code);
        $cmd_out->runtime_msec += $cmd_out2->runtime_msec
    }

    $self->param('protein_tree')->store_tag('BuildHMM_runtime_msec', $cmd_out->runtime_msec);
}


########################################################
#
# ProteinTree input/output section
#
########################################################

sub store_hmmprofile {
  my $self = shift;
  my $hmm_file =  $self->param('hmm_file');

  #parse hmmer file
  print("load from file $hmm_file\n") if($self->debug);
  my $hmm_text = $self->_slurp($hmm_file);

#  my $model_id = sprintf('%d_%s', $self->param('gene_tree_id'), $self->param('hmm_type'));
  my $model_id = $self->param('gene_tree_id');
  my $type = "tree_hmm_" . $self->param('hmm_type');

  my $hmmProfile = Bio::EnsEMBL::Compara::HMMProfile->new();
  $hmmProfile->model_id($model_id);
  $hmmProfile->name($model_id);
  $hmmProfile->type($type);
  $hmmProfile->profile($hmm_text);

  $self->compara_dba->get_HMMProfileAdaptor()->store($hmmProfile);

}

1;
