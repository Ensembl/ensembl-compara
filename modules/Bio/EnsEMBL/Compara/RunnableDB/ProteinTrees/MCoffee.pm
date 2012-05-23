=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a protein_tree cluster as input
Run an MCOFFEE multiple alignment on it, and store the resulting alignment
back into the protein_tree_member table.

input_id/parameters format eg: "{'protein_tree_id'=>726093}"
    protein_tree_id       : use family_id to run multiple alignment on its members
    options               : commandline options to pass to the 'mcoffee' program

=head1 SYNOPSIS

my $db     = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $mcoffee = Bio::EnsEMBL::Compara::RunnableDB::Mcoffee->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id,
                                                    -analysis   => $analysis );
$mcoffee->fetch_input(); #reads from DB
$mcoffee->run();
$mcoffee->output();
$mcoffee->write_output(); #writes to DB

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
        'method'                => 'fmcoffee',              # the style of MCoffee to be run for this alignment
        'options'               => '',
        'cutoff'                => 2,                       # for filtering
    };
}


#
# Redefined methods from the base class (MSA)
########################################################

sub write_output {
    my $self = shift @_;

    $self->SUPER::write_output(@_);

    # Alignment redo mapping.
    my ($from_clusterset_id, $to_clusterset_id) = split(':', $self->param('redo'));
    my $redo_tag = "MCoffee_redo_".$from_clusterset_id."_".$to_clusterset_id;
    $self->param('protein_tree')->tree->store_tag("$redo_tag",$self->param('protein_tree_id')) if ($self->param('redo'));
}

sub parse_and_store_alignment_into_proteintree {
    my $self = shift;

    $self->SUPER::parse_and_store_alignment_into_proteintree();

    return if ($self->param('single_peptide_tree'));
    my $mcoffee_scores = $self->param('mcoffee_scores');
    return unless defined $mcoffee_scores;

    #
    # Read in the scores file manually.
    #
    my %score_hash;
    my $FH = IO::File->new();
    $FH->open($mcoffee_scores) || $self->throw("Could not open alignment scores file [$mcoffee_scores]");
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
    foreach my $member (@{$self->param('protein_tree')->get_all_leaves}) {
        my $score_string = $score_hash{$member->sequence_id} || '';
        $score_string =~ s/[^\d-]/9/g;   # Convert non-digits and non-dashes into 9s. This is necessary because t_coffee leaves some leftover letters
        printf("Updating the score of %s : %s\n",$member->stable_id,$score_string) if ($self->debug);
        $member->store_tag('aln_score', $score_string);
    }
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
    } elsif (defined($self->param('redo')) and ($self->param('method') eq 'unalign') ) {
        my $cutoff = $self->param('cutoff') || 2;
        # Unalign module
        $method_string = " -other_pg seq_reformat -in " . $self->param('redo_alnname') ." -action +aln2overaln unalign 2 30 5 15 0 1>$msa_output";
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
    if ($self->param('use_exon_boundaries')) {
        if (1 == $self->param('use_exon_boundaries')) {
            $method_string .= ", exon_pair";
            my $exon_file = $self->param('input_fasta_exons');
            print OUTPARAMS "-template_file=$exon_file\n";
        } elsif (2 == $self->param('use_exon_boundaries')) {
            $self->param('mcoffee_scores', undef);
            $extra_output .= ',overaln  -overaln_param unalign -overaln_P1 99999 -overaln_P2 1'; # overaln_P1 150 and overaln_P2 30 was dealigning too aggressively
        }
    }
    $method_string .= "\n";

    print OUTPARAMS $method_string;
    print OUTPARAMS "-mode=mcoffee\n";
    print OUTPARAMS "-output=fasta_aln,score_ascii" . $extra_output . "\n";
    print OUTPARAMS "-outfile=$msa_output\n";
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

    my $mcoffee_exe = $self->param('mcoffee_exe')
        or die "'mcoffee_exe' is an obligatory parameter";

    die "Cannot execute '$mcoffee_exe'" unless(-x $mcoffee_exe);

    $cmd = $mcoffee_exe;
    $cmd .= ' '.$input_fasta unless ($self->param('redo'));
    $cmd .= ' '. $self->param('options');
    if (defined($self->param('redo')) and ($self->param('method') eq 'unalign') ) {
        $self->param('mcoffee_scores', undef); #these wont have scores
        $cmd .= ' '. $method_string;
    } else {
        $cmd .= " -parameters=$paramsfile";
    }

    # Output some environment variables for tcoffee
    $prefix = "export HOME_4_TCOFFEE=\"$tempdir\";" if ! $ENV{HOME_4_TCOFFEE};
    $prefix .= "export DIR_4_TCOFFEE=\"$tempdir\";" if ! $ENV{DIR_4_TCOFFEE};
    $prefix .= "export TMP_4_TCOFFEE=\"$tempdir\";";
    $prefix .= "export CACHE_4_TCOFFEE=\"$tempdir\";";
    $prefix .= "export NO_ERROR_REPORT_4_TCOFFEE=1;";

    print "Using default mafft location\n" if $self->debug();
    $prefix .= 'export MAFFT_BINARIES=/software/ensembl/compara/tcoffee-7.86b/install4tcoffee/bin/linux ;';
    # path to t_coffee components:
    $prefix .= 'export PATH=$PATH:/software/ensembl/compara/tcoffee-7.86b/install4tcoffee/bin/linux ;';

    return "$prefix $cmd";
}


1;
