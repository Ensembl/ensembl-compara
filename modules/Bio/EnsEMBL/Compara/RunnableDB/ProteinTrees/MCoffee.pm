=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee

=head1 DESCRIPTION

This RunnableDB implements Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA
by calling MCoffee. It needs the following parameters:
 - mcoffee_exe

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee;

use strict;

use IO::File;

use base ('Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA');


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'mafft_bin_dir'         => '/bin/',                 # where to find the mafft binaroes from $mafft_home
        'mcoffee_exe_name'      => 't_coffee',              # where to find the t_coffee executable from $mcoffee_home/$mcoffee_exe_dir
        'mcoffee_exe_dir'       => '/bin/',                 # where to find the t_coffee executable rirectory from $mcoffee_home
        'mcoffee_bin_dir'       => '/plugins/linux',        # where to find the mcoffee binaries from $mcoffee_home
        'method'                => 'fmcoffee',              # the style of MCoffee to be run for this alignment
        'options'               => '',
        'cutoff'                => 2,                       # for filtering
    };
}


#
# Redefined methods from the base class (MSA)
########################################################

sub parse_and_store_alignment_into_proteintree {
    my $self = shift;

    my $aln_ok = $self->SUPER::parse_and_store_alignment_into_proteintree();
    return 0 unless $aln_ok;

    my $mcoffee_scores = $self->param('mcoffee_scores');
    return 0 unless defined $mcoffee_scores;

    #
    # Read in the scores file manually.
    #
    my %score_hash;
    my $FH = IO::File->new();
    unless ($FH->open($mcoffee_scores)) {
        $self->warning("Could not open alignment scores file [$mcoffee_scores]");
        return 0;
    }
    <$FH>; #skip header
    my $i=0;
    while(<$FH>) {
        $i++;
        next if ($i < 7); # skip first 7 lines.
            next if($_ =~ /^\s+/);  #skip lines that start with space
            if ($_ =~ /:/) {
                my ($id,$overall_score) = split(/:/,$_);
                $id =~ s/^\s+|\s+$//g;
                $overall_score =~ s/^\s+|\s+$//g;
                print "___".$id."___".$overall_score."___\n";
                next;
            }
        chomp;
        my ($id, $align) = split;
        $score_hash{$id} ||= '';
        $score_hash{$id} .= $align;
    }
    $FH->close;

    #
    # Align cigar_lines to members and store
    #
    my $aln_score = $self->param('protein_tree')->deep_copy;
    $aln_score->aln_method('mcoffee_score');
    foreach my $member (@{$aln_score->get_all_Members}) {
        my $score_string = $score_hash{$member->sequence_id} || '';
        $score_string =~ s/[^\d-]/9/g;   # Convert non-digits and non-dashes into 9s. This is necessary because t_coffee leaves some leftover letters
        printf("Updating the score of %s : %s\n",$member->stable_id,$score_string) if ($self->debug);
        $member->cigar_line($score_string);
    }
    $self->compara_dba->get_GeneAlignAdaptor->store($aln_score);
    $self->param('protein_tree')->store_tag('mcoffee_scores', $aln_score->gene_align_id);
    $aln_score->root->release_tree;
    $aln_score->clear;
    return 1;
}



#
# Abstract methods from the base class (MSA) 
##############################################

sub get_msa_command_line {
    my $self = shift;
    my $input_fasta = $self->param('input_fasta');

    my $tempdir = $self->worker_temp_directory;

    my $msa_output = $self->param('msa_output');

    # (Note: t_coffee automatically uses the .mfa output as the basename for the score output)
    my $mcoffee_scores = $msa_output . '.score_ascii';
    $mcoffee_scores =~ s/\/\//\//g;
    $self->param('mcoffee_scores', $mcoffee_scores);

    my $tree_temp = $tempdir . 'tree_temp.dnd';
    $tree_temp =~ s/\/\//\//g;

    my $method_string = '-method=';
    if ($self->param('method') and ($self->param('method') eq 'cmcoffee') ) {
        # CMCoffee, slow, comprehensive multiple alignments.
        $method_string .= "mafftgins_msa, muscle_msa, kalign_msa, t_coffee_msa "; #, probcons_msa";
    } elsif ($self->param('method') eq 'fmcoffee') {
        # FMCoffee, fast but accurate alignments.
        $method_string .= "mafft_msa, muscle_msa, clustalw_msa, kalign_msa";
    } elsif ($self->param('method') eq 'mafft') {
        # MAFFT FAST: very quick alignments.
        $method_string .= "mafft_msa";
    } elsif ($self->param('method') eq 'prank') {
        # PRANK: phylogeny-aware alignment.
        $method_string .= "prank_msa";
    } elsif ($self->param('redo_alnname') and ($self->param('method') eq 'unalign') ) {
        my $cutoff = $self->param('cutoff') || 2;
        # Unalign module
        $method_string = " -other_pg seq_reformat -in " . $self->param('redo_alnname') ." -action +aln2overaln unalign 2 30 5 15 0 1>$msa_output";
        $self->param('mcoffee_scores', undef); #these wont have scores
    } else {
        throw ("Improper method parameter: ".$self->param('method'));
    }

    #
    # Output the params file.
    #
    my $paramsfile = $tempdir. 'temp.params';
    $paramsfile =~ s/\/\//\//g;  # converts any // in path to /
    open(OUTPARAMS, ">$paramsfile") or $self->throw("Error opening $paramsfile for write");

    my $extra_output = '';
    $method_string .= "\n";

    print OUTPARAMS $method_string;
    print OUTPARAMS "-mode=mcoffee\n";
    print OUTPARAMS "-output=fasta_aln,score_ascii" . $extra_output . "\n";
    print OUTPARAMS "-outfile=$msa_output\n";
    print OUTPARAMS "-n_core=1\n";
    print OUTPARAMS "-newtree=$tree_temp\n";
    close OUTPARAMS;

    my $t_env_filename = $tempdir . "t_coffee_env";
    open(TCOFFEE_ENV, ">$t_env_filename")
        or $self->throw("Error opening $t_env_filename for write");
    print TCOFFEE_ENV "http_proxy_4_TCOFFEE=\n";
    print TCOFFEE_ENV "EMAIL_4_TCOFFEE=cedric.notredame\@europe.com\n";
    close TCOFFEE_ENV;

    my $cmd       = '';
    my $prefix    = '';

    my $mcoffee_home = $self->param_required('mcoffee_home');
    my $mcoffee_bin_dir = $self->param_required('mcoffee_bin_dir');
    my $mcoffee_exe_name = $self->param_required('mcoffee_exe_name');
    my $mcoffee_exe_dir = $self->param_required('mcoffee_exe_dir');
    die "Cannot find directory '$mcoffee_bin_dir' in '$mcoffee_home'" unless(-d $mcoffee_home.'/'.$mcoffee_bin_dir);
    
    my $mafft_home = $self->param_required('mafft_home');
    my $mafft_bin_dir = $self->param_required('mafft_bin_dir');
    die "Cannot find directory '$mafft_bin_dir' in '$mafft_home'" unless(-d $mafft_home.'/'.$mafft_bin_dir);

    $cmd = "$mcoffee_home/$mcoffee_exe_dir/$mcoffee_exe_name";
    if ($self->param('redo_alnname') and ($self->param('method') eq 'unalign') ) {
        $cmd .= ' '. $self->param('options');
        $cmd .= ' '. $method_string;
    } else {
        $cmd .= ' '.$input_fasta;
        $cmd .= ' '. $self->param('options');
        $cmd .= " -parameters=$paramsfile";
    }

    # Output some environment variables for tcoffee
    $prefix = "export HOME_4_TCOFFEE=\"$tempdir\";" if ! $ENV{HOME_4_TCOFFEE};
    $prefix .= "export DIR_4_TCOFFEE=\"$tempdir\";" if ! $ENV{DIR_4_TCOFFEE};
    $prefix .= "export TMP_4_TCOFFEE=\"$tempdir\";";
    $prefix .= "export CACHE_4_TCOFFEE=\"$tempdir\";";
    $prefix .= "export NO_ERROR_REPORT_4_TCOFFEE=1;";

    # Add the paths to the t_coffee built-in binaries + mafft (installed on its own)
    $prefix .= "export PATH=$mafft_home/$mafft_bin_dir:\$PATH:$mcoffee_home/$mcoffee_exe_dir/:$mcoffee_home/$mcoffee_bin_dir;";

    return "$prefix $cmd";
}


1;
