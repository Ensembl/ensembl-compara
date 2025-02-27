=head1 LICENSE

# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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

=head1 NAME

Bio::EnsEMBL::Compara::Production::Analysis::Mercator

=head1 SYNOPSIS

  my $output = Bio::EnsEMBL::Compara::Production::Analysis::Mercator::run_mercator($self);

=head1 DESCRIPTION

Mercator expects to run the program Mercator (https://www.biostat.wisc.edu/~cdewey/mercator/)
given a input directory (containing the expected files) and an output directory, where output files
are temporaly stored and parsed.

=head1 METHODS

=cut


package Bio::EnsEMBL::Compara::Production::Analysis::Mercator;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;


sub run_mercator {
  my ($self) = @_;

  my @command = ($self->param('mercator_exe'), '-i', $self->param('input_dir'), '-o', $self->param('output_dir'));
  push @command, @{$self->param('genome_db_ids')};

  $self->run_command(\@command, { 'die_on_failure' => 1} );

  my $map_file = $self->param('output_dir') . "/pre.map";
  my $genomes_file = $self->param('output_dir') . "/genomes";
  open my $fh, '<', $genomes_file ||
    throw("Can't open $genomes_file\n");

  my @species;
  while (<$fh>) {
    @species = split;
    last;
  }
  close $fh;

  open $fh, '<', $map_file ||
    throw("Can't open $map_file\n");

  my %hash;
  while (<$fh>) {
    my @synteny_region = split;
    my $species_idx = 0;
    for (my $i = 1; $i < scalar @species*4 - 2; $i = $i + 4) {
      my $species = $species[$species_idx];
      my ($name, $start, $end, $strand) = map {$synteny_region[$_]} ($i, $i+1, $i+2, $i+3);
      push @{$hash{$synteny_region[0]}}, [$synteny_region[0], $species, $name, $start, $end, $strand];
      $species_idx++;
    }
  }
  close $fh;
  my $output = [ values %hash ];
#  print "scalar output", scalar @{$output},"\n"  if($self->debug);
  print "No synteny regions found" if (scalar @{$output} == 0);
  return $output;
}

1;
