=head1 LICENSE

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
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

=head1 AUTHORS

Benedict Paten bjp@ebi.ac.uk

=head1 NAME

Bio::EnsEMBL::Analysis::Runnable::Ortheus - 

=head1 SYNOPSIS

  my $runnable = new Bio::EnsEMBL::Analysis::Runnable::Ortheus
     (-workdir => $workdir,
      -fasta_files => $fasta_files,
      -tree_string => $tree_string,
      -program => "/path/to/program");
  $runnable->run;
  my @output = @{$runnable->output};

=head1 DESCRIPTION

Ortheus expects to run the ortheus, a program for reconstructing the ancestral history
of a set of sequences. It is able to infer a tree (or one may be provided) and then
create a tree alignment of the sequences that includes ML reconstructions of the
ancestral sequences. Ortheus is based upon a probabilistic transducer model and handles
the evolution of both substitutions, insertions and deletions.


=head1 METHODS

=cut


package Bio::EnsEMBL::Compara::Production::Analysis::Ortheus;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlignTree;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Data::Dumper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 new

  Arg [1]   : -workdir => "/path/to/working/directory"
  Arg [2]   : -fasta_files => "/path/to/fasta/file"
  Arg [3]   : -tree_string => "/path/to/tree/file" (optional)
  Arg [4]   : -parameters => "parameter" (optional)

  Function  : contruct a new Bio::EnsEMBL::Analysis::Runnable::Mlagan
  runnable
  Returntype: Bio::EnsEMBL::Analysis::Runnable::Mlagan
  Exceptions: none
  Example   :

=cut


sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($workdir, $fasta_files, $tree_string, $species_tree, $species_order, $parameters, $pecan_exe_dir,
    $exonerate_exe, $java_exe, $ortheus_py, $ortheus_lib_dir, $semphy_exe, $options,) =
        rearrange(['WORKDIR', 'FASTA_FILES', 'TREE_STRING', 'SPECIES_TREE',
            'SPECIES_ORDER', 'PARAMETERS', 'PECAN_EXE_DIR', 'EXONERATE_EXE', 'JAVA_EXE', 'ORTHEUS_PY', 'ORTHEUS_LIB_DIR', 'SEMPHY_EXE', 'OPTIONS'], @args);

  $self->workdir($workdir) if (defined $workdir);
  chdir $self->workdir;
  $self->fasta_files($fasta_files) if (defined $fasta_files);
  if (defined $tree_string) {
    $self->tree_string($tree_string)
  } elsif ($species_tree and $species_order and @$species_order) {
    $self->species_tree($species_tree);
    $self->species_order($species_order);
  }
  $self->parameters($parameters) if (defined $parameters);
  $self->options($options) if (defined $options);
  $self->java_exe($java_exe) if (defined $java_exe);
  $self->exonerate_exe($exonerate_exe) if (defined $exonerate_exe);
  $self->ortheus_lib_dir($ortheus_lib_dir) if (defined $ortheus_lib_dir);
  $self->pecan_exe_dir($pecan_exe_dir) if (defined $pecan_exe_dir);

  $self->semphy_exe($semphy_exe) if (defined $semphy_exe);
  #overwrite default $ORTHEUS location if defined.
#  if (defined $analysis->program_file) {
#      $ORTHEUS = $analysis->program_file;
#  }

 if (defined $ortheus_py) {
    $self->ortheus_py($ortheus_py);
 } else {
  die "\northeus_py is not defined\n";
 }

  unless (defined $self->exonerate_exe) {
    die "\nexonerate exe is not defined\n";
  }

  return $self;
}

sub workdir {
  my $self = shift;
  $self->{'_workdir'} = shift if(@_);
  return $self->{'_workdir'};
}

sub fasta_files {
  my $self = shift;
  $self->{'_fasta_files'} = shift if(@_);
  return $self->{'_fasta_files'};
}

sub tree_string {
  my $self = shift;
  $self->{'_tree_string'} = shift if(@_);
  return $self->{'_tree_string'};
}

sub species_tree {
  my $self = shift;
  $self->{'_species_tree'} = shift if(@_);
  return $self->{'_species_tree'};
}

sub species_order {
  my $self = shift;
  $self->{'_species_order'} = shift if(@_);
  return $self->{'_species_order'};
}

sub parameters {
  my $self = shift;
  $self->{'_parameters'} = shift if(@_);
  return $self->{'_parameters'};
}

sub pecan_exe_dir {
  my $self = shift;
  $self->{'_pecan_exe_dir'} = shift if(@_);
  return $self->{'_pecan_exe_dir'};
}

sub exonerate_exe {
  my $self = shift;
  $self->{'_exonerate_exe'} = shift if(@_);
  return $self->{'_exonerate_exe'};
}

sub java_exe {
  my $self = shift;
  $self->{'_java_exe'} = shift if(@_);
  return $self->{'_java_exe'};
}

sub ortheus_py {
  my $self = shift;
  $self->{'_ortheus_py'} = shift if(@_);
  return $self->{'_ortheus_py'};
}

sub ortheus_lib_dir {
  my $self = shift;
  $self->{'_ortheus_lib_dir'} = shift if(@_);
  return $self->{'_ortheus_lib_dir'};
}

sub semphy_exe {
  my $self = shift;
  $self->{'_semphy_exe'} = shift if(@_);
  return $self->{'_semphy_exe'};
}

sub options {
  my $self = shift;
  $self->{'_options'} = shift if(@_);
  return $self->{'_options'};
}

sub output {
  my $self = shift;
  $self->{'_output'} = shift if(@_);
  return $self->{'_output'};
}

=head2 run_analysis

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::Mlagan
  Arg [2]   : string, program name
  Function  : create and open a commandline for the program trf
  Returntype: none
  Exceptions: throws if the program in not executable or if the results
  file doesnt exist
  Example   : 

=cut

sub run_analysis {
  my ($self, $program) = @_;

  return $self->run_ortheus;

  #move this to compara module instead because it is easier to keep track
  #of the 2x composite fragments. And also it removes the need to create
  #compara objects in analysis module.
  #$self->parse_results;
  #return 1;
}

sub run_ortheus {
  my $self = shift;
  my $ORTHEUS = $self->ortheus_py;
  my $JAVA = $self->java_exe;
  chdir $self->workdir;
  #my $debug = " -a -b";

#   throw("Python [$PYTHON] is not executable") unless ($PYTHON && -x $PYTHON);
  throw("Ortheus [$ORTHEUS] does not exist") unless ($ORTHEUS && -e $ORTHEUS);

  $ENV{'CLASSPATH'}  = $self->pecan_exe_dir;
  $ENV{'PYTHONPATH'} = $self->ortheus_lib_dir;

  my $command = "python $ORTHEUS";

  #add debugging
  #$command .= $debug;

  $command .= " -l \"#-j 0\" "; #-R\"select[mem>6000] rusage[mem=6000]\" -M6000000 ";

  if (@{$self->fasta_files}) {
    $command .= " -e";
    foreach my $fasta_file (@{$self->fasta_files}) {
      $command .= " $fasta_file";
    }
  }

  #add more java memory by using java parameters set in $self->parameters
  my $java_params = "";
  if ($self->parameters) {
      $java_params = $self->parameters;
  }

  #Add -X to fix -ve indices in array bug suggested by BP
  $command .= " -m \"$JAVA " . $java_params . "\" -k \" -J " . $self->exonerate_exe . " -X\"";

  if ($self->tree_string) {
    $command .= " -d '" . $self->tree_string . "'";
  } elsif ($self->species_tree and $self->species_order and @{$self->species_order}) {
    $command .= " -s ". $self->semphy_exe." -z '".$self->species_tree."' -A ".join(" ", @{$self->species_order});
  } else {
    $command .= " -s ".$self->semphy_exe;
  }
  $command .= " -f output.$$.mfa -g output.$$.tree ";

  #append any additional options to command
  if ($self->options) {
      $command .= " " . $self->options;
  }

  print "Running ortheus: " . $command . "\n";

  #Capture output messages when running ortheus instead of throwing
  open(ORTHEUS, "$command 2>&1 |") or die "Failed: $!\n";
  my $output = "";
  while (<ORTHEUS>){
      $output .= $_;
  }
  close ORTHEUS;

  #if ( $self->debug ) {
      #print "\nOUTPUT TREE:\n";
      #system("cat output.$$.tree");
      #print "\n\n";
  #}

  return $output;

  #unless (system($command) == 0) {
   # throw("ortheus execution failed\n");
  #}
}

=head2 parse_results

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::Mlagan
  Function  : parse the specifed file and produce RepeatFeatures
  Returntype: nine
  Exceptions: throws if fails to open or close the results file
  Example   : 

=cut


sub parse_results{
  my ($self, $run_number) = @_;

  ## The output file contains one fasta aligned sequence per original sequence + ancestral sequences.
  ## The first seq. corresponds to the fist leaf of the tree, the second one will be an internal
  ## node, the third is the second leaf and so on. The fasta header in the result file correspond
  ## to the names of the leaves for the leaf nodes and to the concatenation of the names of all the
  ## underlying leaves for internal nodes. For instance:
  ## ----------------------------------
  ## >0
  ## ACTTGG--CCGT
  ## >0_1
  ## ACTTGGTTCCGT
  ## >1
  ## ACTTGGTTCCGT
  ## >1_2_3
  ## ACTTGCTTCCGT
  ## >2
  ## CCTTCCTTCCGT
  ## ----------------------------------
  ## The sequence of fasta files and leaves in the tree have the same order. If Ortheus is run
  ## with a given tree, the sequences in the file follow the tree. If Ortheus estimate the tree,
  ## the tree output file contains also the right order of files:
  ## ----------------------------------
  ## ((1:0.0157,0:0.0697):0.0000,2:0.0081);
  ## /tmp/file3.fa /tmp/file1.fa /tmp/file2.fa
  ## ----------------------------------


#   $self->workdir("/home/jherrero/ensembl/worker.8139/");
  my $tree_file = $self->workdir . "/output.$$.tree";


  if (-e $tree_file) {
    ## Ortheus estimated the tree. Overwrite the order of the fasta files and get the tree
    open(F, $tree_file) || throw("Could not open tree file <$tree_file>");
    my ($newick, $files) = <F>;
    close(F);
    $newick =~ s/[\r\n]+$//;
    $self->tree_string($newick);
    $files =~ s/[\r\n]+$//;
    my $all_files = [split(" ", $files)];
    $self->fasta_files($all_files);
    print STDERR "NEWICK: $newick\nFILES: ", join(" -- ", @$all_files), "\n";
  }


#   $self->tree_string("((0:0.06969,1:0.015698):1e-05,2:0.008148):1e-05;");
#   $self->fasta_files(["/home/jherrero/ensembl/worker.8139/seq1.fa", "/home/jherrero/ensembl/worker.8139/seq2.fa", "/home/jherrero/ensembl/worker.8139/seq3.fa"]);


  my (@ordered_leaves) = $self->tree_string =~ /[(,]([^(:)]+)/g;
  print STDERR "NEWICK: ", $self->tree_string, "\nLEAVES: ", join(" -- ", @ordered_leaves), "\nFILES: ", join(" -- ", @{$self->fasta_files}), "\n";
  my $alignment_file = $self->workdir . "/output.$$.mfa";
#   my $alignment_file = $self->workdir . "/output.8139.mfa";
  my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock;

  open(F, $alignment_file) || throw("Could not open $alignment_file");
  my $seq = "";
  my $this_genomic_align;
  my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($self->tree_string);
  $tree->print_tree(100);
  print $tree->newick_format("simple"), "\n";
  print join(" -- ", map {$_->name} @{$tree->get_all_leaves}), "\n";
print "Reading $alignment_file...\n";
  my $ids;
  foreach my $this_file (@{$self->fasta_files}) {
    push(@$ids, qx"head -1 $this_file");
    push(@$ids, undef); ## There is an internal node after each leaf..
  }
  pop(@$ids); ## ...except for the last leaf which is the end of the tree
#print join(" :: ", @$ids), "\n\n";
  while (<F>) {
    next if (/^\s*$/);
    chomp;
    ## FASTA headers correspond to the tree and the order of the leaves in the tree corresponds
    ## to the order of the files
    if (/^>/) {
      print "PARSING $_\n";
  print $tree->newick_format(), "\n";
      my ($name) = $_ =~ /^>(.+)/;
      if (defined($this_genomic_align) and  $seq) {
        $this_genomic_align->aligned_sequence($seq);
        $this_genomic_align_block->add_GenomicAlign($this_genomic_align);
      }
      my $header = shift(@$ids);
      $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign;
      if (!defined($header)) {
        print "INTERNAL NODE $name\n";
        my $this_node;
        foreach my $this_leaf_name (split("_", $name)) {
          if ($this_node) {
            my $other_node = $tree->find_node_by_name($this_leaf_name);
            if (!$other_node) {
              throw("Cannot find node <$this_leaf_name>\n");
            }
            $this_node = $this_node->find_first_shared_ancestor($other_node);
          } else {
            print $tree->newick_format();
            print "LEAF: $this_leaf_name\n";
            $this_node = $tree->find_node_by_name($this_leaf_name);
          }
        }
        print join("_", map {$_->name} @{$this_node->get_all_leaves}), "\n";
        ## INTERNAL NODE: dnafrag_id and dnafrag_end must be edited somewhere else
        $this_genomic_align->dnafrag_id(-1);
        $this_genomic_align->dnafrag_start(1);
        $this_genomic_align->dnafrag_end(0);
        $this_genomic_align->dnafrag_strand(1);
        bless($this_node, "Bio::EnsEMBL::Compara::GenomicAlignTree");
        $this_node->genomic_align($this_genomic_align);
        $this_node->name($name);
    } elsif ($header =~ /^>DnaFrag(\d+)\|(.+)\.(\d+)\-(\d+)\:(\-?1)$/) {
        print "leaf_name?? $name\n";
        my $this_leaf = $tree->find_node_by_name($name);
        if (!$this_leaf) {
          print $tree->newick_format(), "\n";
          die "";
        }
        print "$this_leaf\n";
#         print "****** $name -- $header -- ";
#         if ($this_leaf) {
#           $this_leaf->print_node();
#         } else {
#           print "[none]\n";
#         }

	#information extracted from fasta header
        $this_genomic_align->dnafrag_id($1);
        $this_genomic_align->dnafrag_start($3);
        $this_genomic_align->dnafrag_end($4);
        $this_genomic_align->dnafrag_strand($5);

        bless($this_leaf, "Bio::EnsEMBL::Compara::GenomicAlignTree");
        $this_leaf->genomic_align($this_genomic_align);
      } else {
        throw("Error while parsing the FASTA header. It must start by \">DnaFrag#####\" where ##### is the dnafrag_id\n$_");
      }
      $seq = "";
    } else {
      $seq .= $_;
    }
  }
  close F;
  if ($this_genomic_align->dnafrag_id == -1) {
  } else {
    $this_genomic_align->aligned_sequence($seq);
    $this_genomic_align_block->add_GenomicAlign($this_genomic_align);
  }
  print $tree->newick_format("simple"), "\n";
  print join(" -- ", map {$_->node_id."+".$_->genomic_align->dnafrag_id} (@{$tree->get_all_nodes()})), "\n";
  $self->output([$tree]);

}


1;
