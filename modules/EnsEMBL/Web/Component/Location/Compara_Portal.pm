# $Id$

package EnsEMBL::Web::Component::Location::Compara_Portal;

use strict;

use base qw(EnsEMBL::Web::Component::Portal);

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $availability = $self->object->availability;
  my $slice        = $availability->{'slice'};
  my $alignments   = $availability->{'has_alignments'};
  my $gene         = $hub->param('g') ? $hub->url({ type => 'Gene',  action => 'Compara' }) : '';

  $self->{'buttons'} = [
    { title => 'Alignments (image)', img => 'compara_image', url => $slice && $alignments                                           ? $hub->url({ action => 'Compara_Alignments', function => 'Image' }) : '' },
    { title => 'Alignments (text)',  img => 'compara_text',  url => $slice && $alignments                                           ? $hub->url({ action => 'Compara_Alignments'                      }) : '' },
    { title => 'Region Comparison',  img => 'compara_multi', url => $slice && $availability->{'has_pairwise_alignments'}            ? $hub->url({ action => 'Multi'                                   }) : '' },
    { title => 'Synteny',            img => 'compara_syn',   url => $availability->{'chromosome'} && $availability->{'has_synteny'} ? $hub->url({ action => 'Synteny'                                 }) : '' },
  ];

  my $html  = $self->SUPER::content;
     $html .= '<p>';
  
  if ($gene) {
    $html .= qq{More views of comparative genomics data, such as orthologues and paralogues, are available on the <a href="$gene">Gene</a> page.};
  } else {
    $html .= 'Additional comparative genomics views are available for individual genes.';
  }
     
  return "$html</p>";
}

1;
