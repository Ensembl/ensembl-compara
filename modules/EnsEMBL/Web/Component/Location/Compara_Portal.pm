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

package EnsEMBL::Web::Component::Location::Compara_Portal;

use strict;

use parent qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;

  $self->cacheable(1);
  $self->ajaxable(0);
}

sub content {
  my $self          = shift;
  my $hub           = $self->hub;
  my $availability  = $self->object->availability;
  my $slice         = $availability->{'slice'};
  my $alignments    = $availability->{'has_alignments'};
  my $gene          = $hub->param('g') ? $hub->url({ type => 'Gene',  action => 'Compara' }) : '';

  my $buttons       = [
    { title => 'Synteny',            img => '80/compara_syn.gif',   url => $availability->{'chromosome'} && $availability->{'has_synteny'} ? $hub->url({ action => 'Synteny'                                 }) : '' },
    { title => 'Alignments (image)', img => '80/compara_image.gif', url => $slice && $alignments                                           ? $hub->url({ action => 'Compara_Alignments', function => 'Image' }) : '' },
    { title => 'Alignments (text)',  img => '80/compara_text.gif',  url => $slice && $alignments                                           ? $hub->url({ action => 'Compara_Alignments'                      }) : '' },
    { title => 'Region Comparison',  img => '80/compara_multi.gif', url => $slice && $availability->{'has_pairwise_alignments'}            ? $hub->url({ action => 'Multi'                                   }) : '' },
  ];

  my $html  = $self->button_portal($buttons, 'portal-small');
     $html .= '<p>';

  if ($gene) {
    $html .= qq{More views of comparative genomics data, such as orthologues and paralogues, are available on the <a href="$gene">Gene</a> page.};
  } else {
    $html .= 'Additional comparative genomics views are available for individual genes.';
  }

  return "$html</p>";
}

1;
