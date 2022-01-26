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

package EnsEMBL::Draw::GlyphSet::biggenepred;

### Module for drawing data in bigGenePred format (either user-attached, or
### internally configured via an ini file or database record

### bigGenePred is an extension of the bigbed format, so we mostly just need
### some additional rendering styles

use strict;
use warnings;
no warnings 'uninitialized';

use parent qw(EnsEMBL::Draw::GlyphSet::bigbed);

sub render_as_collapsed_nolabel {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Feature::Transcript']);
  $self->{'my_config'}->set('collapsed', 1);
  $self->{'my_config'}->set('show_labels', 0);
  $self->draw_features;
}
 
sub render_as_collapsed_label {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Feature::Transcript']);
  $self->{'my_config'}->set('collapsed', 1);
  $self->{'my_config'}->set('show_labels', 1);
  $self->draw_features;
}

sub post_process {
  my ($self, $features) = @_;
  return unless scalar @$features;
  my $merged_features = {};

  ## Merge transcripts into genes if required
  if ($self->{'my_config'}->get('collapsed')) {
 
    foreach my $f (@$features) {
      #warn ">>> FEATURE ".$f->{'label'}." BELONGS TO GENE ".$f->{'gene'};

      ## Have we seen this gene already?
      my $merge = $merged_features->{$f->{'gene'}};

      ## Another transcript of an existing gene?
      if ($merge) {
        if ($f->{'strand'} == 1) {
          $merge->{'start'} = $f->{'start'} if $f->{'start'} < $merge->{'start'};
          $merge->{'end'}   = $f->{'end'} if $f->{'end'} > $merge->{'end'};
        }
        else {
          $merge->{'start'} = $f->{'start'} if $f->{'start'} > $merge->{'start'};
          $merge->{'end'}   = $f->{'end'} if $f->{'end'} < $merge->{'end'};
        }
      }
      else { ## New gene
        $f->{'label'} = $f->{'gene'};
        $merged_features->{$f->{'gene'}} = $f;
      }
    }
  }
  
  my @merged = sort {$a->{'start'} <=> $b->{'start'}} values $merged_features;
  return \@merged;
}

1;

