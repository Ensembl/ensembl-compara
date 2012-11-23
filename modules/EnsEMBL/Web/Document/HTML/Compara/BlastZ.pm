package EnsEMBL::Web::Document::HTML::Compara::BlastZ;

use strict;

use EnsEMBL::Web::Hub;

use base qw(EnsEMBL::Web::Document::HTML::Compara);

sub render { 
  my $self = shift;
  my $html;

  ## Get all the data 
  my $methods = ['BLASTZ_NET', 'LASTZ_NET'];
  my ($species_list, $data) = $self->mlss_data($methods);

  ## Do some munging
  my ($species_order, $info) = $self->get_species_info($species_list, 1);

  ## Output data
  foreach my $sp (@$species_order) {
    next unless $sp && $data->{$sp};
    $html .= sprintf '<h4>%s</h4><ul>', $info->{$sp}{'long_name'};

    foreach my $other (@$species_order) {
      my $values = $data->{$sp}{$other};
      next unless $values;  
        
      my $method  = $values->[0];
      my $mlss_id = $values->[1];
      my $url = '/info/docs/compara/mlss.html?method='.$method.';mlss='.$mlss_id;
      $html .= sprintf '<li><a href="%s">%s (%s)</a></li>', 
                          $url, $info->{$other}{'common_name'}, $info->{$other}{'long_name'};
    } 
    $html .= '</ul>';
  }

  return $html;
}

1;
