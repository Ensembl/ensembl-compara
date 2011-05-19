# $Id$

package EnsEMBL::Web::ViewConfig::Variation::Context;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self     = shift;
  my %options  = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my $defaults = { context => 5000 };
  
  foreach (keys %options) {
    my %hash = %{$options{$_}};
    $defaults->{lc $_} = $hash{$_}[0] for keys %hash;
  }
	
  $self->set_defaults($defaults);
  $self->add_image_config('snpview', 'nodas');
}

sub form {
  my $self = shift;
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Context',
    values => [
      { value => '1000',  name => '1kb'  },
      { value => '5000',  name => '5kb'  },
      { value => '10000', name => '10kb' },
      { value => '20000', name => '20kb' },
      { value => '30000', name => '30kb' }
    ]
  });
}

1;
