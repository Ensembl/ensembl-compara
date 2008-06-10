package EnsEMBL::Web::Component::Account::Links;

### Module to create user bookmark list

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return undef;
}

sub content {
  my $self = shift;
  my $html;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  
  $html .= qq#
<div class="twocol-left">
<p>Bookmarks:</p>
<ul>
<li><a href="">Bookmark 1</a></li>
<li><a href="">Bookmark 2</a></li>
<li><a href="">Bookmark 3</a></li>
</ul>
<p><a href="javascript:bookmark_link()">Bookmark this page</a></p>
</div>

<div class="twocol-right">
<p>Page configurations:</p>
<ul>
<li>Config 1: <a href="">Load in page</a> | <a href="">Go to saved page and load</a></li>
<li>Config 2: <a href="">Load in page</a> | <a href="">Go to saved page and load</a></li>
<li>Config 3: <a href="">Load in page</a> | <a href="">Go to saved page and load</a></li>
</ul>
</div>
#;


  return $html;
}

1;
