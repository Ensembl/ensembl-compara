=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::Align;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $hub     = $self->hub;
  my $r       = $hub->param('r');
  my $break   = $hub->param('break');
  my $caption = 'AlignSlice';
  
  my @location = split /\b/, $r;
  my ($start, $end) = ($location[2], $location[4]);
  
  my ($start_type, $end_type);
  my $length = abs($end - $start);
  my @entries;
  
  if ($break) {
    $length--;
    $start_type = 'From';
    $end_type   = 'To';
    $caption   .= ' Break';
    
    @entries = ([ 'Info', 'There is a gap in the original chromosome between these two alignments', 1 ]);
  } else {
    my $strand   = $hub->param('strand');
    my $interval = $hub->param('interval');
    
    my ($i_start, $i_end) = split '-', $interval;
    
    $length++;
    $start_type = 'Start';
    $end_type   = 'End';
    
    @entries = (
      [ 'Strand',          $strand > 0 ? '+' : '-',    3  ],
      [ 'Interval Start',  $i_start,                   8  ],
      [ 'Interval End',    $i_end,                     9  ],
      [ 'Interval Length', abs($i_end - $i_start) + 1, 10 ]
    );
  }
  
  push @entries, (
    [ 'Chromosome', $location[0], 2 ],
    [ $start_type,  $start,       4 ],
    [ $end_type,    $end,         5 ],
    [ 'Length',     $length,      6 ]
  );
  
  foreach (grep $_->[1], @entries) {
    $self->add_entry({
      type  => $_->[0],
      label => $_->[1],
      order => $_->[2],
    });
  }
  
  $self->add_entry({
    type  => 'Link',
    label => 'Region in detail',
    link  => $hub->url({ action => 'View' }),
    order => 7
  });
  
  $self->caption($caption);
}

1;
