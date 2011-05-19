# $Id$

package EnsEMBL::Web::ViewConfig::Location::LDImage;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self     = shift;
  my %options  = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my $defaults = {};

  foreach (keys %options) {
    my %hash = %{$options{$_}};
    $defaults->{lc $_} = $hash{$_}[0] for keys %hash;
  }
  
  $self->set_defaults($defaults);
  $self->add_image_config('ldview', 'nodas'); 
}

1;
