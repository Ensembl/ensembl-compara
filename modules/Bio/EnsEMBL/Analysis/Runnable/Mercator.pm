=head1 LICENSE

# Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

Bio::EnsEMBL::Analysis::Runnable::Mercator - 

=head1 SYNOPSIS

  my $runnable = new Bio::EnsEMBL::Analysis::Runnable::Mercator
     (-input_dir => $input_dir,
      -output_dir => $output_dir,
      -genome_names => ["homo_sapiens","mus_musculus","rattus_norvegicus"],
      -program => "/path/to/program");
  $runnable->run;
  my @output = @{$runnable->output};

=head1 DESCRIPTION

Mercator expects to run the program Mercator (http://hanuman.math.berkeley.edu/~cdewey/mercator/)
given a input directory (containing the expected files) and an output directory, where output files
are temporaly stored and parsed.

=head1 METHODS

=cut


package Bio::EnsEMBL::Analysis::Runnable::Mercator;

use strict;
use warnings;

use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;

our @ISA = qw(Bio::EnsEMBL::Analysis::Runnable);


=head2 new

  Arg [1]   : -input_dir => "/path/to/input/directory"
  Arg [2]   : -output_dir => "/path/to/output/directory"
  Arg [3]   : -genome_names => ["homo_sapiens","mus_musculus","rattus_norvegicus"]
  Function  : contruct a new Bio::EnsEMBL::Analysis::Runnable::Mercator
  runnable
  Returntype: Bio::EnsEMBL::Analysis::Runnable::Mercator
  Exceptions: none
  Example   :

=cut


sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
   my ($input_dir, $output_dir, $genome_names, $pre_map) = rearrange(['INPUT_DIR', 'OUTPUT_DIR', 'GENOME_NAMES', 'PRE_MAP'], @args);
#  my ($input_dir, $output_dir, $genome_names, $strict_map) = rearrange(['INPUT_DIR', 'OUTPUT_DIR', 'GENOME_NAMES', 'STRICT_MAP'], @args);

  unless (defined $self->program) {
    $self->program('/software/ensembl/compara/mercator');
  }
  $self->input_dir($input_dir) if (defined $input_dir);
  $self->output_dir($output_dir) if (defined $output_dir);
  $self->genome_names($genome_names) if (defined $genome_names);
  if (ref($genome_names) eq "ARRAY") {
    print "GENOME_NAMES: ", join(", ", @{$genome_names}), "\n";
  } else {
    print "GENOME_NAMES: $genome_names\n";
  }
   if (defined $pre_map){
     $self->pre_map($pre_map);
  } else {
     $self->pre_map(1);
  }
  
  return $self;
}

sub input_dir {
    my ($self, $arg) = @_;

    $self->{'_input_dir'} = $arg if defined $arg;
    
    return $self->{'_input_dir'};
}

sub output_dir {
    my ($self, $arg) = @_;

    $self->{'_output_dir'} = $arg if defined $arg;
    return $self->{'_output_dir'};
}

sub genome_names {
    my ($self, $arg) = @_;

    $self->{'_genome_names'} = $arg if defined $arg;
    return $self->{'_genome_names'};
}

sub pre_map {
    my ($self, $arg) = @_;

    $self->{'_pre_map'} = $arg if defined $arg;
    return $self->{'_pre_map'};
}
=head2 run_analysis

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::TRF
  Arg [2]   : string, program name
  Function  : create and open a commandline for the program trf
  Returntype: none
  Exceptions: throws if the program in not executable or if the results
  file doesnt exist
  Example   : 

=cut



sub run_analysis{
  my ($self, $program) = @_;
  if(!$program){
    $program = $self->program;
  }

  throw($program." is not executable Mercator::run_analysis ") 
    unless($program && -x $program);

  my $command = "$program -i " . $self->input_dir . " -o " . $self->output_dir;
  print "genome_names: ".join(", ", @{$self->genome_names})."\n";
  foreach my $species (@{$self->genome_names}) {
    $command .= " $species";
  }
  print "Running analysis ".$command."\n";
  unless (system($command) == 0) {
    throw("mercator execution failed\n");
  }
  $self->parse_results;
}


=head2 parse_results

  Arg [1]   : Bio::EnsEMBL::Analysis::Runnable::Mercator
  Arg [2]   : string, results filename
  Function  : parse the specifed file and produce RepeatFeatures
  Returntype: nine
  Exceptions: throws if fails to open or close the results file
  Example   : 

=cut


sub parse_results{
  my ($self) = @_;

  my $map_file = $self->output_dir . "/pre.map";
  unless ($self->pre_map) {
    $map_file = $self->output_dir . "/map";
  }
  my $genomes_file = $self->output_dir . "/genomes";
  open F, $genomes_file ||
    throw("Can't open $genomes_file\n");

  my @species;
  while (<F>) {
    @species = split;
    last;
  }
  close F;

  open F, $map_file ||
    throw("Can't open $map_file\n");

  my %hash;
  while (<F>) {
    my @synteny_region = split;
    my $species_idx = 0;
    for (my $i = 1; $i < scalar @species*4 - 2; $i = $i + 4) {
      my $species = $species[$species_idx];
      my ($name, $start, $end, $strand) = map {$synteny_region[$_]} ($i, $i+1, $i+2, $i+3);
      push @{$hash{$synteny_region[0]}}, [$synteny_region[0], $species, $name, $start, $end, $strand];
      $species_idx++;
    }
  }
  close F;
  my $output = [ values %hash ];
  print "scalar output", scalar @{$output},"\n";
  print "No synteny regions found" if (scalar @{$output} == 0);
  $self->output($output);
}

1;
