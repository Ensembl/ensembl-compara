package EnsEMBL::Web::Component::Account::UpdateFailed;

### Module to create user login form 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
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
  return qq(<p>Sorry - we were unable to update your account. If the problem persists, please contact <a href="/Help/Contact" class="popup">contact our helpdesk</a>. Thank you.</p>
<p><a href="/Account/Details" class="modal_link">Return to your account home page</a>);

}

1;
