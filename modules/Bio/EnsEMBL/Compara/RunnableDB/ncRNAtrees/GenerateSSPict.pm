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


=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GenerateSSPict

=head1 DESCRIPTION

This Hive analysis will create secondary structure plots based on the
secondary structures (in bracket notation) created by Infernal.
In addition to secondary structure plots for the whole alignments 
of the family, plots for individual members are also created.

=head1 CONTACT

   Please email comments or questions to the public Ensembl
   developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

   Questions may also be sent to the Ensembl help desk at
   <http://www.ensembl.org/Help/Contact>

=head1 APPENDIX

The rest of the documentation details each of the object methods.

Internal methods are usually preceded with an underscore (_)

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GenerateSSPict;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my ($self) = @_;

    my $nc_tree_id = $self->param_required('gene_tree_id');

    my $nc_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($nc_tree_id) or die "Could not fetch nc_tree with id=$nc_tree_id\n";
    $self->param('nc_tree', $nc_tree);

    my $model_name = $nc_tree->get_value_for_tag('model_name');
    $self->param('model_name', $model_name);

    my $ss_cons = $nc_tree->get_value_for_tag('ss_cons');
    $self->param('ss_cons', $ss_cons);

    my $input_aln = $self->_fetchMultipleAlignment();
    $self->param('input_aln', $input_aln);

    my $ss_model_picts_dir = $self->param('ss_picts_dir') . "/" . $model_name;
    mkdir($ss_model_picts_dir);
    $self->param('ss_model_picts_dir', $ss_model_picts_dir);

    return;
}

sub run {
    my ($self) = @_;

    $self->_dumpMultipleAlignment();
    $self->get_plot();
    return;
}

sub _fetchMultipleAlignment {
    my ($self) = @_;

    my $tree = $self->param('nc_tree');

    my $sa = $tree->get_SimpleAlign( -id => 'MEMBER' );
    return $sa;
}

sub _dumpMultipleAlignment {
    my ($self) = @_;
    my $aln = $self->param('input_aln');
    my $model_name = $self->param('model_name');
    my $ss_cons = $self->param('ss_cons');

    if ($ss_cons =~ /^\.d+$/) {
        $self->input_job->autoflow(0);
        $self->complete_early("tree " . $self->param('gene_tree_id') . " has no structure: $ss_cons\n");
    }

    my $ss_model_picts_dir = $self->param('ss_model_picts_dir');
    my $aln_filename = "${ss_model_picts_dir}/${model_name}.sto";

    print STDERR "ALN FILE IS: $aln_filename\n" if ($self->debug);

    open my $aln_fh, ">", $aln_filename or die $!;
    print $aln_fh "# STOCKHOLM 1.0\n";
    for my $aln_seq ($aln->each_seq) {
        printf $aln_fh ("%-20s %s\n", $aln_seq->display_id, $aln_seq->seq);
    }
    printf $aln_fh  ("%-20s\n", "#=GF R2R keep allpairs");
    printf $aln_fh  ("%-20s %s\n//\n", "#=GC SS_cons", $ss_cons);

    close($aln_fh);
    $self->param('aln_file', $aln_filename);
    return;
}

sub get_cons_aln {
    my ($self) = @_;
    my $aln_file = $self->param('aln_file');
    my $out_aln_file = $aln_file . ".cons";
    ## For information about these options, check http://breaker.research.yale.edu/R2R/R2R-manual-1.0.3.pdf";
    $self->run_r2r_and_check("--GSC-weighted-consensus", $aln_file, $out_aln_file, "3 0.97 0.9 0.75 4 0.97 0.9 0.75 0.5 0.1");
    return;
}

sub get_plot {
    my ($self) = @_;

    my $r2r_exe = $self->param_required('r2r_exe');
    my $aln_file = $self->param('aln_file');
    my $tree = $self->param('nc_tree');

    my $out_aln_file = $aln_file . ".cons";
    $self->get_cons_aln();

    ## First we create the thumbnails
    my $meta_file_thumbnail = $aln_file . "-thumbnail.meta";
    my $svg_thumbnail_pic = "${out_aln_file}.thumbnail.svg";
    $self->_spurt($meta_file_thumbnail, "$out_aln_file\tskeleton-with-pairbonds\n");
    $self->run_r2r_and_check("", $meta_file_thumbnail, $svg_thumbnail_pic, "");

    my $meta_file = $aln_file . ".meta";
    ## One svg pic per member
    for my $member (@{$tree->get_all_Members}) {
        my $seq_member_id = $member->name();
        $self->_spurt($meta_file, "$out_aln_file\n$aln_file\toneseq\t$seq_member_id\n");
        my $svg_pic_filename = "${out_aln_file}-${seq_member_id}.svg";
        $self->run_r2r_and_check("", $meta_file, $svg_pic_filename, "");
    }
    return;
}

sub fix_aln_file {
    my ($self, $msg) = @_;

    my @columns = $msg =~ /\[(\d+),(\d+)\]/g;

    my $aln_file = $self->param('aln_file');
    open my $aln_fh, "<", $aln_file or die $!;
    my $label_line = sprintf("%-21s",   "#=GC R2R_LABEL");
    my $keep_line  = sprintf("%-21s\n", "#=GF R2R keep p");
    my $new_aln = "";
    while (<$aln_fh>) {
        $new_aln .= $_;
        chomp;
        if (/^#=GC\s+SS_cons\s+(.+)$/) {
            print STDERR "GC SS_CONS LINE: $_\n";
            my $cons_seq_len = length($1);
            $label_line .= "." x $cons_seq_len;
            for my $pos (@columns) {
                substr($label_line, $pos, 1, "p");
            }
            $new_aln .= "$label_line\n";
            $new_aln .= "$keep_line";
        }
    }
    close($aln_fh);
    $self->_spurt($aln_file, $new_aln);
    $self->param('fixed_aln', 1);
    $self->get_cons_aln();
}

sub run_r2r_and_check {
    my ($self, $opts, $infile, $outfile, $extra_params) = @_;

    my $r2r_exe = $self->param_required('r2r_exe');
    my $cmd = "$r2r_exe $opts $infile $outfile $extra_params";
    my $runCmd = $self->run_command($cmd);

    if ($runCmd->exit_code) {
        if ($self->param('fixed_aln')) {
            die "Problem running r2r: " . $runCmd->out . "\n";
        } else {
            $self->fix_aln_file($runCmd->out);
            $self->run_r2r_and_check($opts, $infile, $outfile, $extra_params);
        }
    }
    if (! -e $outfile) {
        die "Problem running r2r: $outfile doesn't exist\n";
    }
    return;
}

1;
