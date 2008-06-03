package EnsEMBL::Web::Component::User::LoginCheck;

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
  return 'Login';
}

sub content {
## Interstitial page - confirms login then uses JS redirect to page where logged in
  my $self = shift;

  my $url = $self->object->param('url') || '/index.html';

  my $html;
  if ($ENV{'ENSEMBL_USER_ID'}) {
    if ($self->object->param('updated') eq 'yes') {
      $html .= qq(<p>Thank you. Your changes have been saved.</p>);
    }
    else {
      $html .= qq(<p>Thank you for logging into Ensembl</p>);
    }
    $html .= qq(
<script type="text/javascript">
<!--
window.setTimeout('backToEnsembl()', 5000);

function backToEnsembl(){
  window.location = "$url"
}
//-->
</script>
<p>Please <a href="$url">click here</a> if you are not returned to your starting page within five seconds.</p>
  );
  }
  else {
    $html .= qq(<p>Sorry, we were unable to log you in. Please check that your browser can accept cookies.</p>
<p><a href="$url">Click here</a> to return to your starting page.</p>
);
  }

  return $html;
}

1;
