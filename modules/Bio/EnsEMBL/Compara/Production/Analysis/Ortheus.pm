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
    $exonerate_exe, $java_exe, $ortheus_bin_dir, $ortheus_lib_dir, $semphy_exe, $options,) =
        rearrange(['WORKDIR', 'FASTA_FILES', 'TREE_STRING', 'SPECIES_TREE',
            'SPECIES_ORDER', 'PARAMETERS', 'PECAN_EXE_DIR', 'EXONERATE_EXE', 'JAVA_EXE', 'ORTHEUS_BIN_DIR', 'ORTHEUS_LIB_DIR', 'SEMPHY_EXE', 'OPTIONS'], @args);

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

 if (defined $ortheus_bin_dir) {
    $self->ortheus_bin_dir($ortheus_bin_dir);
 } else {
  die "\northeus_bin_dir is not defined\n";
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

sub ortheus_bin_dir {
  my $self = shift;
  $self->{'_ortheus_bin_dir'} = shift if(@_);
  return $self->{'_ortheus_bin_dir'};
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


sub run_ortheus {
  my $self = shift;
  my $ORTHEUS = $self->ortheus_bin_dir . '/Ortheus.py';
  my $JAVA = $self->java_exe;
  chdir $self->workdir;
  #my @debug = qw(-a -b);

#   throw("Python [$PYTHON] is not executable") unless ($PYTHON && -x $PYTHON);
  throw("Ortheus [$ORTHEUS] does not exist") unless ($ORTHEUS && -e $ORTHEUS);

  $ENV{'PATH'} = $self->ortheus_bin_dir . ':' . $ENV{'PATH'};
  $ENV{'CLASSPATH'}  = $self->pecan_exe_dir;
  $ENV{'PYTHONPATH'} = $self->ortheus_lib_dir;

  my @command = ('python2', $ORTHEUS);

  #add debugging
  #push @command, @debug;

  push @command, '-l', '#-j 0';

  if (@{$self->fasta_files}) {
    push @command, '-e';
    foreach my $fasta_file (@{$self->fasta_files}) {
      push @command, $fasta_file;
    }
  }

  #add more java memory by using java parameters set in $self->parameters
  my $java_params = "";
  if ($self->parameters) {
      $java_params = $self->parameters;
  }

  #Add -X to fix -ve indices in array bug suggested by BP
  push @command, '-m', "$JAVA $java_params", '-k', ' -J '.$self->exonerate_exe.' -X';

  if ($self->tree_string) {
    push @command, '-d', $self->tree_string;
  } elsif ($self->species_tree and $self->species_order and @{$self->species_order}) {
    push @command, '-s', $self->semphy_exe, '-z', $self->species_tree, '-A', @{$self->species_order};
  } else {
    push @command, '-s', $self->semphy_exe;
  }
  push @command, '-f', "output.$$.mfa", '-g', "output.$$.tree";

  #append any additional options to command
  if ($self->options) {
      push @command, @{$self->options};
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
