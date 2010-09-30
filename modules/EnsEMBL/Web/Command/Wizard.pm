package EnsEMBL::Web::Command::Wizard;

## Generic module for redirecting wizard nodes 
## depending on which form button is clicked

use strict;
use warnings;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self   = shift;
  my $hub    = $self->hub;
  my $back   = $hub->param('wizard_back'); # Check if we're going back
  my @steps  = $hub->param('_backtrack');
  my $params = {};
  my $url;
  
  if ($back) {
    my $current_node = 'Summary'; ## Default value to stop Magic from barfing
    my $species = $hub->type eq 'UserData' ? $hub->data_species : $hub->species;
    
    $url .= $hub->species_path($species) if $species;
    $url .= '/' . $hub->type;
    
    pop @steps;
    $current_node = pop @steps;
    $url .= "/$current_node";
  } else {
    $url = $hub->param('wizard_next');
  }
  
  # Pass the "normal" parameters but munge the wizard ones
  foreach my $name ($hub->param) {
    next if $name =~ /^wizard_/;
    
    my @value = $hub->param($name);
    my $value = (@value) ? \@value : $value[0];
    
    if ($name eq '_backtrack' && $back) {
      $value = \@steps;
      
      if (scalar @steps) {
        $hub->param('_backtrack', @steps);
      } else {
        $hub->delete_param('_backtrack');
      }
    };
    
    $params->{$name} = $value;
  }
  
  $self->ajax_redirect($url, $params); 
}

1;
