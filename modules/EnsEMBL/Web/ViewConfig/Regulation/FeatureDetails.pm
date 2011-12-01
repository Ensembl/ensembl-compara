# $Id$

package EnsEMBL::Web::ViewConfig::Regulation::FeatureDetails;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self     = shift;
  my $analyses = $self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'feature_type'}{'analyses'} || {};
  
  $self->set_defaults({
    image_width => 800,
    context     => 200,
    opt_focus   => 'yes',
    map {( "opt_ft_$_" => 'on' )} keys %$analyses
  });

  $self->add_image_config('reg_detail');
  $self->title = 'Summary';
}

sub form {
  my $self = shift;  
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Context',
    values => [
      { value => '20',   name => '20bp'   },
      { value => '50',   name => '50bp'   },
      { value => '100',  name => '100bp'  },
      { value => '200',  name => '200bp'  },
      { value => '500',  name => '500bp'  },
      { value => '1000', name => '1000bp' },
      { value => '2000', name => '2000bp' },
      { value => '5000', name => '5000bp' }
    ]
  });
  
  $self->add_form_element({ type => 'YesNo', name => 'opt_focus', select => 'select', label => 'Show Core Evidence track' });
}

1;
