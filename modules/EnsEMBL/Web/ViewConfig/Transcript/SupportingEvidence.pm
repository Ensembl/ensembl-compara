# $Id$

package EnsEMBL::Web::ViewConfig::Transcript::SupportingEvidence;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->set_defaults({ context => 100 });
  $self->add_image_config('supporting_evidence_transcript');
}

sub form {
  my $self = shift;
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Context',
    values => [
      { value => '20',   name => '20bp'         },
      { value => '50',   name => '50bp'         },
      { value => '100',  name => '100bp'        },
      { value => '200',  name => '200bp'        },
      { value => '500',  name => '500bp'        },
      { value => '1000', name => '1000bp'       },
      { value => '2000', name => '2000bp'       },
      { value => '5000', name => '5000bp'       },
      { value => 'FULL', name => 'Full Introns' }
    ]
  });
}

1;
