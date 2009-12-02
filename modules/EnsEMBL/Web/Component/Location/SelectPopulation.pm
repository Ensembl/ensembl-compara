package EnsEMBL::Web::Component::Location::SelectPopulation;

use strict;
use warnings;
no warnings 'uninitialized';

use CGI qw(escapeHTML);

use base qw(EnsEMBL::Web::Component::MultiSelector);

sub _init {
  my $self = shift;
 
  $self->SUPER::_init;
 
  $self->{'link_text'}       = 'Select populations for comparison';
  $self->{'included_header'} = 'Selected Populations';
  $self->{'excluded_header'} = 'Unselected Populations';
  $self->{'url_param'}       = 'pop';
}

sub content_ajax {
  my $self    = shift;
  my $object  = $self->object;
  my $params  = $object->multi_params; 
  my %available;

  my $slice = $object->database('core')->get_SliceAdaptor->fetch_by_region(
    $object->seq_region_type, $object->seq_region_name, 1, $object->seq_region_length, 1
  );
  my $ld_adaptor    = $object->database('variation')->get_LDFeatureContainerAdaptor();
  my @populations   = @{$ld_adaptor->get_populations_by_Slice($slice)};  

  my %shown = map { $object->param("pop$_") => $_ } grep s/^pop(\d+)$/$1/, $object->param;
  my $next_id         = 1 + scalar keys %shown;

  foreach my $i (sort  @populations ){
    $available{$i} = $i;
  }

  $self->{'all_options'} = \%available;
  $self->{'included_options'} = \%shown;

  $self->SUPER::content_ajax;
}

1;
