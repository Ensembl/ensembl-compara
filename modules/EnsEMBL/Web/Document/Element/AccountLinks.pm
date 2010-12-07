# $Id$

package EnsEMBL::Web::Document::Element::AccountLinks;

### Generates links to user account (currently in masthead)

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub logins  :lvalue { $_[0]{'logins'};  }

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $species = $hub->species;
     $species = !$species || $species eq 'Multi' || $species eq 'common' ? 'Multi' : $species;
  my $html;;
  
  if ($self->logins) {
    if ($hub->user) {
      $html .= sprintf '<a class="constant modal_link" style="display:none" href="%s">Account</a>',  $hub->url({ __clear => 1, species => $species, type => 'Account', action => 'Links'  });
      $html .= sprintf ' &middot; <a class="constant" href="%s">Logout</a>',                                   $hub->url({ __clear => 1, species => $species, type => 'Account', action => 'Logout' });
    } else {
      $html .= sprintf '<a class="constant modal_link" style="display:none" href="%s">Login</a>',    $hub->url({ __clear => 1, species => $species, type => 'Account', action => 'Login' });
      $html .= sprintf ' &middot; <a class="constant modal_link" style="display:none" href="%s">Register</a>', $hub->url({ __clear => 1, species => $species, type => 'Account', action => 'User', function => 'Add' });
    }
  }

  return $html;  
}

sub init {
  my $self         = shift;
  my $species_defs = $self->species_defs;
  $self->logins    = $species_defs->ENSEMBL_LOGINS;
}

1;
