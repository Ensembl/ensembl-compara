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

Bio::EnsEMBL::Compara::Production::Analysis::LowCoverageGenomeAlignment

=head1 DESCRIPTION

This module creates a new tree for those alignments which contain a segmental duplication. The module will runs treeBest where there are more than 3 sequences in an alignment, otherwise it will run semphy. This module is still under development.


=head1 METHODS

=cut


package Bio::EnsEMBL::Compara::Production::Analysis::LowCoverageGenomeAlignment;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlignTree;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Data::Dumper;
use File::Basename;


=head2 run_analysis

  Arg [1]    : Bio::EnsEMBL::Compara::Production::Analysis::LowCoverageGenomeAlignment
  Arg [2]    : string, program name
  Description: run treebest if more than 3 sequences in the alignment else run 
               semphy
  Returntype : none
  Exceptions : throws if the program in not executable or if the results
  file doesnt exist
  Example    : 
  Status     : At risk

=cut

sub run_analysis {
  my ($self) = @_;

  #find how many sequences are in the mfa file
  my $num_sequences = get_num_sequences($self->param('multi_fasta_file'));
  
  #treebest phyml needs at least 4 sequences to run. If I have less than
  #4, then run semphy instead.
  if ($num_sequences < 4) {
      run_semphy_2x($self);
  } else {
      run_treebest_2x($self);
  }
}

#Find how many sequences in mfa file
sub get_num_sequences {
    my ($mfa) = @_;
 
    my $cnt = 0;
    open (MFA, "$mfa") || throw("Couldn't open $mfa");
    while (<MFA>) {
	$cnt++ if (/^>/);
    }
    close(MFA);

    return $cnt;
}

=head2 run_treebest_2x

  Arg [1]    : none
  Description: create and open a commandline for the program treebest
  Returntype : none
  Exceptions : throws if the program in not executable or if the results
  file doesnt exist
  Example    : 
  Status     : At risk

=cut

sub run_treebest_2x {
    my ($self) = @_;


    #Check I don't already have a tree
    return if ($self->tree_string);
     
    chdir $self->worker_temp_directory;
    my $tree_file = "output.$$.tree";

    #write species tree (with taxon_ids) to file in workdir
    my $species_tree_file = "species_tree.$$.tree";
    open(F, ">$species_tree_file") || throw("Couldn't open $species_tree_file for writing");
    print (F $self->taxon_species_tree);
    close(F);

    #Run treebeset
    my $command = $self->param('treebest_exe') ." phyml -Snf $species_tree_file " . $self->param('multi_fasta_file') . " | " . $self->param('treebest_exe') . " sdi -rs $species_tree_file - > $tree_file";

    print "Running treebest $command\n";

    #run treebest to create tree
    $self->run_command($command, { die_on_failure => 1 });
     
    #read in new tree
    if (-e $tree_file) {
	  ## Treebest estimated the tree. Overwrite the order of the fasta files and get the tree
	  open(F, $tree_file) || throw("Could not open tree file <$tree_file>");
	  my $newick;
	  while (<F>) {
	      $newick .= $_;
	  }
	  close(F);
	  $newick =~ s/[\r\n]+$//;
	  rearrange_multi_fasta_file($newick, $self->param('multi_fasta_file'));
      }
}


=head2 run_semphy_2x

  Arg [1]    : none
  Description: create and open a commandline for the program semphy
  Returntype : none
  Exceptions : throws if the program in not executable or if the results
  file doesnt exist
  Example    : 
  Status     : At risk

=cut

sub run_semphy_2x {
    my ($self) = @_;

    #Check I don't already have a tree
    return if ($self->tree_string);

    chdir $self->worker_temp_directory;
    my $tree_file = "output.$$.tree";

    #Run semphy directly
    my $command = $self->param('semphy_exe') . " --treeoutputfile=" . $tree_file . " -a 4 --hky -J -H -S --ACGprob=0.300000,0.200000,0.200000 --sequence=" . $self->param('multi_fasta_file');

    print "Running semphy $command\n";

    #run semphy to create tree
    $self->run_command($command, { die_on_failure => 1 });
      
    #read in new tree
    if (-e $tree_file) {
	  ## Semphy estimated the tree. Overwrite the order of the fasta files and get the tree
	  open(F, $tree_file) || throw("Could not open tree file <$tree_file>");
	  my ($newick) = <F>;
	  close(F);
	  $newick =~ s/[\r\n]+$//;
	  rearrange_multi_fasta_file($newick, $self->param('multi_fasta_file'));
      }
    #print "FINAL tree string $tree_string\n";
}


sub rearrange_multi_fasta_file {
    my ($tree_string, $mfa_file) = @_;

    my (@ordered_leaves) = $tree_string =~ /(seq[^:]+)/g;
    

    my $ordered_names;
    for (my $i = 0; $i < @ordered_leaves; $i++) {

	my $item;
	$item->{name} = ">" . $ordered_leaves[$i];
	$item->{leaf} = $ordered_leaves[$i];
	push @$ordered_names, $item;
     }

    my %mfa_data;
    open(MFA, $mfa_file) || throw("Could not open mfa file <$mfa_file>");

    my $name;
    my $seq;
    while (<MFA>) {
	next if (/^\s*$/);
	chomp;
	
	if (/^>/) {
	    if ($name) {
		$mfa_data{$name} = $seq;
		$seq = "";
	    }
	    $name = $_;
	} else {
	    $seq .= $_;
	}
    }
    $mfa_data{$name} = $seq;
    close(MFA);

    #overwrite existing mfa file
    open MFA, ">$mfa_file" || throw("Couldn't open $mfa_file");

    foreach my $ordered_name (@$ordered_names) {
	#for ancestral 
	next if (!defined $mfa_data{$ordered_name->{name}});

	print MFA ">".$ordered_name->{leaf} . "\n";
	my $seq = $mfa_data{$ordered_name->{name}};
	$seq =~ s/(.{80})/$1\n/g;
	
	chomp $seq;
	print MFA $seq,"\n";
    }
    close MFA;
}

1;
