=head1 LICENSE

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::Production::Analysis::Pecan

=head1 DESCRIPTION

Mavid expects to run the program mavid, a global multiple aligner for large genomic sequences,
using a fasta file and a tree file (Newick format), and eventually a constraints file.
The output (multiple alignment) is parsed and return as a Bio::EnsEMBL::Compara::GenomicAlignBlock object.

=head1 METHODS

=cut


package Bio::EnsEMBL::Compara::Production::Analysis::Pecan;

use strict;
use warnings;

use Capture::Tiny qw(tee_merged);

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;

use Bio::EnsEMBL::Compara::Utils::RunCommand;


sub run_pecan {
  my $self = shift;

  my $prev_dir = chdir $self->worker_temp_directory;

  my @fasta_files = @{$self->param('fasta_files')};
  my $tree_string = $self->param('pecan_tree_string');
  unless (defined $tree_string) {
    # Use EstimateTree.py program to get a tree from the sequences
    my @est_command = ('python2', $self->param_required('estimate_tree_exe'), @fasta_files);
    my $ret_cmd = $self->run_command(\@est_command, { 'die_on_failure' => 1} );
    my @estimate = split "\n", $ret_cmd->out;
    if (($estimate[0] !~ /^FINAL_TREE: \(.+\);/) or ($estimate[2] !~ /^ORDERED_SEQUENCES: (.+)/)) {
      throw "Error while running EstimateTree program for Pecan";
    }
    ($tree_string) = $estimate[0] =~ /^FINAL_TREE: (\(.+\);)/;
    # print "THIS TREE $tree_string\n";
    my ($files) = $estimate[2] =~ /^ORDERED_SEQUENCES: (.+)/;
    @fasta_files = split(" ", $files);
    # print "THESE FILES ", join(" ", @fasta_files), "\n";
    ## Build newick tree which can be stored in the meta table
    foreach my $this_file (@fasta_files) {
      my $header = qx"head -1 $this_file";
      my ($dnafrag_id, $name, $start, $end, $strand) = $header =~ /^>DnaFrag(\d+)\|([^\.+])\.(\d+)\-(\d+)\:(\-?1)/;
      # print "HEADER: $dnafrag_id, $name, $start, $end, $strand  $header";
      $strand = 0 if ($strand != 1);
      $tree_string =~ s/(\W)\d+(\W)/$1${dnafrag_id}_${start}_${end}_${strand}$2/;
    }
    $self->param('tree_to_save', $tree_string);
    # print "TREE_TO_SAVE: $tree_string\n";
  }

  my @command = ($self->require_executable('java_exe'));
  if ($self->param('java_options')) {
      # FIXME: encode java_options as an array in the PipeConfigs
      push @command, split(/ /, $self->param('java_options'));
  }
  push @command, '-cp', $self->param_required('pecan_exe_dir'), $self->param_required('default_java_class');

  if (@fasta_files) {
    push @command, '-F', @fasta_files;
  }

  #Remove -X option. Transitive anchoring is now switched off by default
  #push @command, '-J', $self->param_required('exonerate_exe'), '-X';
  push @command, '-J', $self->param_required('exonerate_exe');
  if ($tree_string) {
    push @command, '-E', $tree_string;
  }
  push @command, '-G', 'pecan.mfa';

  print "Running pecan " . Bio::EnsEMBL::Compara::Utils::RunCommand::join_command_args(@command) . "\n";

  #Capture output messages when running pecan instead of throwing
  my $java_error = tee_merged { system(@command) };
  chdir $prev_dir;

  if ($java_error) {
      die ($java_error);
  }

  my $alignment_file = $self->worker_temp_directory . "/pecan.mfa";
  my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock;

  open(my $fh, '<', $alignment_file) || throw("Could not open $alignment_file");
  my $seq = "";
  my $this_genomic_align;
print "Reading $alignment_file...\n";
  while (<$fh>) {
    next if (/^\s*$/);
    chomp;
    ## FASTA headers are defined in the Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Pecan
    ## module (or any other module you use to create this Pecan analysis job). Here is an example:
    ## >DnaFrag1234|X.10001-20000:-1
    ## This will correspond to chromosome X, which has dnafrag_id 1234 and the region goes from
    ## position 10001 to 20000 on the reverse strand.
    if (/^>/) {
      if (/^>DnaFrag(\d+)\|(.+)\.(\d+)\-(\d+)\:(\-?1)$/) {
        if (defined($this_genomic_align) and  $seq) {
          $this_genomic_align->aligned_sequence($seq);
          $this_genomic_align_block->add_GenomicAlign($this_genomic_align);
        }
        $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign;
        $this_genomic_align->dnafrag_id($1);
        $this_genomic_align->dnafrag_start($3);
        $this_genomic_align->dnafrag_end($4);
        $this_genomic_align->dnafrag_strand($5);
        $seq = "";
      } else {
        throw("Error while parsing the FASTA header. It must start by \">DnaFrag#####\" where ##### is the dnafrag_id\n$_");
      }
    } else {
      $seq .= $_;
    }
  }
  close $fh;
  $this_genomic_align->aligned_sequence($seq);
  $this_genomic_align_block->add_GenomicAlign($this_genomic_align);
  
  return [$this_genomic_align_block];
}


1;
