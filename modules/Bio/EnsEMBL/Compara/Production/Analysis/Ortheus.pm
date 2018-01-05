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

Bio::EnsEMBL::Analysis::Runnable::Ortheus

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


sub run_ortheus {
  my $self = shift;

  local $ENV{'PATH'} = $self->param_required('ortheus_bin_dir') . ':' . $ENV{'PATH'};
  local $ENV{'CLASSPATH'}  = $self->param_required('pecan_exe_dir');
  local $ENV{'PYTHONPATH'} = $self->param_required('ortheus_lib_dir');

  my $ORTHEUS = $self->param('ortheus_bin_dir') . '/Ortheus.py';
  #my @debug = qw(-a -b);

  throw("Ortheus [$ORTHEUS] does not exist") unless ($ORTHEUS && -e $ORTHEUS);

  # Ortheus.py is executable but calls "python", which may be python3 on some systems
  my @command = ('python2', $ORTHEUS);

  #add debugging
  #push @command, @debug;

  push @command, '-l', '#-j 0';

  if (@{$self->param('fasta_files')}) {
    push @command, '-e', @{$self->param('fasta_files')};
  }

  #Add -X to fix -ve indices in array bug suggested by BP
  push @command, '-m', $self->require_executable('java_exe').' '.($self->param('java_options') // ''), '-k', ' -J '.$self->require_executable('exonerate_exe').' -X';

  if (defined $self->param('tree_string')) {
    push @command, '-d', $self->param('tree_string');
  } elsif ($self->param('species_order') and @{$self->param('species_order')}) {
    my $species_tree = $self->get_species_tree->newick_format('ryo', '%{^-g}:%{d}');
    push @command, '-s', $self->require_executable('semphy_exe'), '-z', $species_tree, '-A', @{$self->param('species_order')};
  } else {
    push @command, '-s', $self->require_executable('semphy_exe')
  }
  push @command, '-f', "output.$$.mfa", '-g', "output.$$.tree";

  #append any additional options to command
  if ($self->param('options')) {
      push @command, @{$self->param('options')};
  }

  print "Running ortheus: " . Bio::EnsEMBL::Compara::Utils::RunCommand::join_command_args(@command) . "\n";

  #Capture output messages when running ortheus instead of throwing
  my $prev_dir = chdir $self->worker_temp_directory;
  my $output = tee_merged { system(@command) };
  chdir $prev_dir;

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
