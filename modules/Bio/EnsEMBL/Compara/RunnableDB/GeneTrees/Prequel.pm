=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::Prequel

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to calculate ancestral sequences for a given gene tree
via the PHAST's prequel tool (http://compgen.bscb.cornell.edu/phast/)

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::Prequel;

use strict;
use warnings;
use Data::Dumper;

## The order is important
use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::AncestralReconstruction', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

my $min_leap = 0.2;
my %nt_symbols = (
               'A' => 'A',
               'C' => 'C',
               'G' => 'G',
               'T' => 'T',
               'AT' => 'W',
               'CG' => 'S',
               'AC' => 'M',
               'GT' => 'K',
               'AG' => 'R',
               'CT' => 'Y',
               'CGT' => 'B',
               'AGT' => 'D',
               'ACT' => 'H',
               'ACG' => 'V',
               'ACGT' => 'N',
              );

sub _runAncestralReconstruction {
    my ($self) = @_;

    # In Parameters
    my $work_temp_dir = $self->worker_temp_directory;
    my $root_id = $self->param('gene_tree_id');
    my $aln_file  = $self->param('aln_file');
    my $tree_file = $self->param('tree_file');
    my $phylofit_exe = $self->param('phylofit_exe');
    my $prequel_exe = $self->param('prequel_exe');

    print STDERR "ALN FILE: $aln_file\n" if ($self->debug);
    print STDERR "TREE FILE: $tree_file\n" if ($self->debug);

    # First run the phyloFit program
    #phyloFit --out-root ENSGT00530000067184 --tree ENSGT00530000067184.nwk ENSGT00530000067184.aln
    my $cmd = "cd $work_temp_dir; $phylofit_exe --out-root $root_id --tree $tree_file $aln_file";
    my $runCmd = $self->run_command($cmd);
    if ($runCmd->exit_code) {
        $self->throw("error running phyloFit: $!\n");
    }

    my $mod_file = "$work_temp_dir/${root_id}.mod";
    die "mod file $mod_file doesn't exist\n" unless (-e $mod_file);

    # Then run prequel
    # prequel ENSGT00530000067184.aln ENSGT00530000067184.mod anc

    $cmd = "cd $work_temp_dir; $prequel_exe $aln_file $mod_file anc";
    $runCmd = $self->run_command($cmd);
    if ($runCmd->exit_code) {
        $self->throw("error running prequel: $!\n");
    }

    return;
}

sub _parseAncestralReconstruction {
    my ($self) = @_;

    my $work_dir = $self->worker_temp_directory;

    my @prob_files = glob("$work_dir/anc*.probs");

    my $anc_seqs;
    for my $prob_file (@prob_files) {
        my ($node_id) = $prob_file =~ /anc\.(\d+)\.prob/;
        my $anc_seq = $self->_get_ancestral_sequence($prob_file);
        print STDERR "ANCESTRAL SEQUENCE FOR $node_id IS $anc_seq\n" if ($self->debug);
        $anc_seqs->{$node_id} = $anc_seq;
    }

    # Out Parameters
    $self->param('ancestral_sequences', $anc_seqs);
    return;
}

sub _get_ancestral_sequence {
    my ($self, $file) = @_;

    my $anc_seq;

    open my $fh, "<", $file or die $!;
    # Discard first header line
    # #p(A)   p(C)    p(G)    p(T)
    <$fh>;

    # Read the rest
    while (my $line = <$fh>) {
        chomp ($line);
        my ($probA, $probC, $probG, $probT) = split(/\s+/, $line);
        my %probs =  (
                      'A' => $probA,
                      'C' => $probC,
                      'G' => $probG,
                      'T' => $probT
                     );
        my @nts;
        for my $nt (sort {$probs{$b} <=> $probs{$a}} keys %probs) {
            if (scalar @nts == 0) {
                push @nts, $nt
            } else {
                my $firstnt = $nts[0];
                if ($probs{$firstnt} - $min_leap > $probs{$nt}) {
                    last;
                } else {
                    push @nts, $nt;
                }
            }
        }

        $anc_seq .= $self->_get_symbol_from_nts([@nts]);
    }

    return $anc_seq;
}

sub _get_symbol_from_nts {
    my ($self, $nts) = @_;

    my $key = join "", sort {$a cmp $b} map {uc $_} @$nts;

    return $nt_symbols{$key};
}

sub aln_options {
    return (-cdna => 1);
}

1;
