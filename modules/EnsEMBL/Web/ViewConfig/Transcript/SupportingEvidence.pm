# $Id$

package EnsEMBL::Web::ViewConfig::Transcript::SupportingEvidence;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->set_defaults({ context => 100 });
  $self->add_image_config('supporting_evidence_transcript');
  $self->title = 'Supporting evidence';
}

sub form {
  my $self = shift;
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Context',
    values => [
      { value => '20',   caption => '20bp'         },
      { value => '50',   caption => '50bp'         },
      { value => '100',  caption => '100bp'        },
      { value => '200',  caption => '200bp'        },
      { value => '500',  caption => '500bp'        },
      { value => '1000', caption => '1000bp'       },
      { value => '2000', caption => '2000bp'       },
      { value => '5000', caption => '5000bp'       },
      { value => 'FULL', caption => 'Full Introns' }
    ]
  });
}

1;
