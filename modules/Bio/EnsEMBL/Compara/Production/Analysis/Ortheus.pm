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
  $runnable->run_ortheus;

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

use Capture::Tiny qw(tee_merged);
use Data::Dumper;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;

use Bio::EnsEMBL::Compara::Utils::RunCommand;



=head2 run_ortheus

  Arg [1]   : -workdir => "/path/to/working/directory"
  Arg [2]   : -fasta_files => "/path/to/fasta/file"
  Arg [3]   : -tree_string => "/path/to/tree/file" (optional)
  Arg [4]   : -parameters => "parameter" (optional)

=cut

sub run_ortheus {
  my ($class,@args) = @_;
  my ($workdir, $fasta_files, $tree_string, $species_tree, $species_order, $parameters, $pecan_exe_dir,
    $exonerate_exe, $java_exe, $ortheus_bin_dir, $ortheus_lib_dir, $semphy_exe, $options,) =
        rearrange(['WORKDIR', 'FASTA_FILES', 'TREE_STRING', 'SPECIES_TREE',
            'SPECIES_ORDER', 'PARAMETERS', 'PECAN_EXE_DIR', 'EXONERATE_EXE', 'JAVA_EXE', 'ORTHEUS_BIN_DIR', 'ORTHEUS_LIB_DIR', 'SEMPHY_EXE', 'OPTIONS'], @args);

 unless (defined $ortheus_bin_dir) {
  die "\northeus_bin_dir is not defined\n";
 }

  unless (defined $exonerate_exe) {
    die "\nexonerate exe is not defined\n";
  }

  my $ORTHEUS = $ortheus_bin_dir . '/Ortheus.py';
  chdir $workdir if $workdir;
  #my @debug = qw(-a -b);

  throw("Ortheus [$ORTHEUS] does not exist") unless ($ORTHEUS && -e $ORTHEUS);

  local $ENV{'PATH'} = $ortheus_bin_dir . ':' . $ENV{'PATH'};
  local $ENV{'CLASSPATH'}  = $pecan_exe_dir;
  local $ENV{'PYTHONPATH'} = $ortheus_lib_dir;

  # Ortheus.py is executable but calls "python", which may be python3 on some systems
  my @command = ('python2', $ORTHEUS);

  #add debugging
  #push @command, @debug;

  push @command, '-l', '#-j 0';

  if (@{$fasta_files}) {
    push @command, '-e', @{$fasta_files};
  }

  my $java_params = $parameters // '';

  #Add -X to fix -ve indices in array bug suggested by BP
  push @command, '-m', "$java_exe $java_params", '-k', ' -J '.$exonerate_exe.' -X';

  if (defined $tree_string) {
    push @command, '-d', $tree_string;
  } elsif ($species_tree and $species_order and @{$species_order}) {
    push @command, '-s', $semphy_exe, '-z', $species_tree, '-A', @{$species_order};
  } else {
    push @command, '-s', $semphy_exe;
  }
  push @command, '-f', "output.$$.mfa", '-g', "output.$$.tree";

  #append any additional options to command
  if ($options) {
      push @command, @{$options};
  }

  print "Running ortheus: " . Bio::EnsEMBL::Compara::Utils::RunCommand::join_command_args(@command) . "\n";

  #Capture output messages when running ortheus instead of throwing
  my $output = tee_merged { system(@command) };

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

1;
