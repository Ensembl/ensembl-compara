# $Id$

package EnsEMBL::Web::ViewConfig::transcriptsnpdataview;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  $self->_set_defaults(qw(
    panel_image       on 
    context           100
    panel_transcript  on
    image_width       800
    reference),       ''
  );
  
  my %options = EnsEMBL::Web::Constants::VARIATION_OPTIONS; # Add other options

  foreach (keys %options) {
    my %hash = %{$options{$_}};
    
    foreach my $key (keys %hash){
      $self->_set_defaults(lc $key => $hash{$key}[0]);
    }
  }
  
  $self->storable = 1;
}

1;
