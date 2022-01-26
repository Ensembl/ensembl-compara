=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::gene_legend;

### Legend for gene colours

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::legend);

sub _init {
  my $self     = shift;
  my $features = $self->{'legend'}{[split '::', ref $self]->[-1]};
  # Let them accumulate in structure if accumulating and not last
  my $Config         = $self->{'config'};
  return if ($self->my_config('accumulate') eq 'yes' &&
             $Config->get_parameter('more_slices'));
  # Clear features (for next legend)
  $self->{'legend'}{[split '::', ref $self]->[-1]} = {};
  return unless $features;

  $self->init_legend();
  my (%sections,%headings,%priorities, @legend_check);

  foreach my $type (sort { $features->{$a}{'priority'} <=> $features->{$b}{'priority'} } keys %$features) {
    my $connection  = $type eq 'connections';
    my @colours = $connection ? map { $_, $features->{$type}{'legend'}{$_} } sort keys %{$features->{$type}{'legend'}} : @{$features->{$type}{'legend'}};
  
    $self->newline(1);

    while (my ($legend, $colour) = splice @colours, 0, 2) {
      
      #making sure not duplicating legend (issue arised with gencode basic track)
      next if(grep(/^$legend$/, @legend_check));
      push @legend_check, $legend;
      
      my $section = undef;
      if(ref($colour) eq 'ARRAY') {
        $section = $colour->[1];
        $colour = $colour->[0];
      } else {
        $section = { name => 'Other', key => '_missing' };
      }
      
      my $entry = {
                    legend => $legend,
                    colour => $colour,
                    style  => $connection ? 'line' : 'box',
                  };
      $entry->{'height'} = 2 if $connection;      
      push @{$sections{$section->{'key'}}||=[]}, $entry;
      $headings{$section->{'key'}} = $section->{'name'};
      $priorities{$section->{'key'}} = $section->{'priority'};
    }
  }
  
  foreach my $key (sort { $priorities{$b} <=> $priorities{$a} } keys %sections) {      
    $self->add_vgroup_to_legend($sections{$key},$headings{$key});
  }

  $self->add_space;
}

1;
        
