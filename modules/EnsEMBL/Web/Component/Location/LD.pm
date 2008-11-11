package EnsEMBL::Web::Component::Location::LD;

### Generic component for use in test sites where  
### content has not yet been ported

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;

  my $html = qq(<div class="tinted-box center">
<h3>UNDER CONSTRUCTION</h3>
<p>This page has not yet been ported to the new code. Thank you for your patience.</p>
</div>);

  return $html;
}

1;
