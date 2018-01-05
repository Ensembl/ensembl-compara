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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Synteny::BuildSynteny

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

This module runs the java program BuildSynteny.jar. This can fail if the input file is already sorted on position. If such a failure is detected, the input will be sorted on a different field in an attempt to sufficiently un-sort it and the command is automatically rerun.

Supported keys:
      'program' => <path>
         Path to executable

      'gff_file' => <path>
          Location of input gff file

      'maxDist1' => <number>
          Maximum gap allowed between alignments within a syntenic block

      'minSize1' => <number>
          Minimum length a syntenic block must have, shorter blocks are discarded

      'maxDist2' => <number>
          Maximum gap allowed between alignments within a syntenic block for second genome. Only maxDist1 needs to be defined if maxDist1 equals maxDist2

      'minSize2' => <number>
          Minimum length a syntenic block must have, shorter blocks are discarded for the second genome. Only minSize1 needs to be defined in minSize1 equals minSize2

      'orient' => <false>
           "false" is only needed for human/mouse, human/rat and mouse/rat NOT for elegans/briggsae (it can be ommitted).

      'output_file' => <path>
           output file

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Synteny::BuildSynteny;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub run {
  my( $self) = @_;

  my $cmd = _create_cmd($self->param('program'), $self->param('gff_file'), $self->param('maxDist1'), $self->param('minSize1'), $self->param('maxDist2'), $self->param('minSize2'), $self->param('orient'), $self->param('output_file'));

  my $command = $self->run_command($cmd);

  #Check error output 
  if ($command->err =~ /QuickSort/) {

      #Need to re-sort gff_file and rerun
      my $gff_file = $self->param('gff_file');
      my $gff_sort = $gff_file . ".sort";
      `sort -n -k 6,6 $gff_file > $gff_sort`;

      $self->warning("Needed to sort $gff_file");
      my $sort_cmd =  _create_cmd($self->param('program'), $gff_sort, $self->param('maxDist1'), $self->param('minSize1'), $self->param('maxDist2'), $self->param('minSize2'), $self->param('orient'), $self->param('output_file'));
      my $command = $self->run_command($sort_cmd);

      #recheck err file
      if ($command->err =~ /QuickSort/) {
          $self->warning("Error even after sorting gff_file");
          my $j = $self->dataflow_output_id(undef, -1);
          unless (@$j) {
              die "No more _himem analysis. Giving up";
          }
      }
  }

  return 1;
}

sub _create_cmd {
    my ($program, $gff_file, $maxDist1, $minSize1, $maxDist2, $minSize2, $orient, $output_file) = @_;

    my $cmd = $program;
    $cmd .= " $gff_file";
    $cmd .= " $maxDist1";
    $cmd .= " $minSize1";
    $cmd .= " $maxDist2" if (defined $maxDist2);
    $cmd .= " $minSize2" if (defined $minSize2);
    $cmd .= " $orient";
    $cmd .= " > $output_file";

    return $cmd;
}

1;


