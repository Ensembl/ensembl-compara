# $Id$

package EnsEMBL::Web::Component::Location::Compara_Portal;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  my $hub  = $self->hub;
  
  $self->cacheable(1);
  $self->ajaxable(0);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my $object    = $self->object;
  my $avail     = $object->availability;

  my ($text_url, $image_url, $multi_url, $syn_url);
  if ($avail->{'slice'}) {
    if ($avail->{'has_alignments'}) {
      $image_url  = $hub->url({'action' => 'Compara_Alignments', 'function' => 'Image'});
      $text_url   = $hub->url({'action' => 'Compara_Alignments'});
    }
    if ($avail->{'has_pairwise_alignments'}) {
      $multi_url   = $hub->url({'action' => 'Multi'});
    }
  }
  if ($avail->{'chromosome'} && $avail->{'has_synteny'}) {
    $syn_url    = $hub->url({'action' => 'Synteny'});
  }

  my @buttons = (
    {'title' => 'Alignments (image)', 'img' => '/img/compara_image.gif', 'url' => $text_url},
    {'title' => 'Alignments (text)',  'img' => '/img/compara_text.gif',   'url' => $image_url},
    {'title' => 'Multi-species view', 'img' => '/img/compara_multi.gif',  'url' => $multi_url},
    {'title' => 'Synteny',            'img' => '/img/compara_syn.gif',    'url' => $syn_url},
  );

  my $html = qq(
    <div class="centered">
  );
  foreach my $button (@buttons) {
    my $title = $button->{'title'};
    my $img = $button->{'img'};
    my $url = $button->{'url'};
    if ($url) {
      $html .= qq(<a href="$url" title="$title"><img src="$img" class="portal" alt="" /></a>);
    }
    else {
      $title .= ' (NOT AVAILABLE)';
      $html .= qq(<img src="$img" class="portal" alt="" title="$title" />);
    }
  }
  $html .= qq(
    </div>
  );
 
  return $html;
}


1;
