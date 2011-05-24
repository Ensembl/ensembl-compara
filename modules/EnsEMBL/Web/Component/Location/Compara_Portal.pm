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
    {'title' => 'Alignments (image)', 'img' => 'compara_image', 'url' => $image_url},
    {'title' => 'Alignments (text)',  'img' => 'compara_text',   'url' => $text_url},
    {'title' => 'Multi-species view', 'img' => 'compara_multi',  'url' => $multi_url},
    {'title' => 'Synteny',            'img' => 'compara_syn',    'url' => $syn_url},
  );

  my $html = qq(
    <div class="centered">
  );
  foreach my $button (@buttons) {
    my $title = $button->{'title'};
    my $img = $button->{'img'};
    my $url = $button->{'url'};
    if ($url) {
      $img .= '.gif';
      $html .= qq(<a href="$url" title="$title"><img src="/img/$img" class="portal" alt="" /></a>);
    }
    else {
      $img   .= '_off.gif';
      $title .= ' (NOT AVAILABLE)';
      $html .= qq(<img src="/img/$img" class="portal" alt="" title="$title" />);
    }
  }
  $html .= qq(
    </div>
  );

  if ($hub->param('g')) {
    my $url = $hub->url({'type'=>'Gene','action'=>'Compara'});
    $html .= qq(<p>More views of comparative genomics data, such as orthologues and paralogues, are available on the <a href="$url">Gene</a> page.</p>);
  }
  else {
    $html .= qq(<p>Additional comparative genomics views are available for individual genes.</p>);
  }
 
  return $html;
}


1;
