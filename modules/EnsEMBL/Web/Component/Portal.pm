# $Id$

package EnsEMBL::Web::Component::Portal;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  
  $self->cacheable(1);
  $self->ajaxable(0);
  
  $self->{'buttons'} = [];
}

sub content {
  my $self = shift;
  my $html;
  
  foreach (@{$self->{'buttons'}}) {
    if ($_->{'url'}) {
      $html .= qq(<a href="$_->{'url'}" title="$_->{'title'}"><img src="/img/$_->{'img'}.gif" class="portal" alt="" /></a>);
    } else {
      $html .= qq|<img src="/img/$_->{'img'}_off.gif" class="portal" alt="" title="$_->{'title'} (NOT AVAILABLE)" />|;
    }
  }
  
  return qq{<div>$html</div>};
}

1;
