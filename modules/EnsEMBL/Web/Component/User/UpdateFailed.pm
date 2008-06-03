package EnsEMBL::Web::Component::User::UpdateFailed;

### Module to create user login form 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::User);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Update Failed';
}

sub content {
### Generic message component for failed user_db update
  my $self = shift;
  return qq(<p>Sorry - we were unable to update your account. If the problem persists, please contact <a href="mailto:webmaster\@ensembl.org">webmaster\@ensembl.org</a>. Thank you.</p>
<p><a href="/User/Account">Return to your account home page</a>);

}

1;
