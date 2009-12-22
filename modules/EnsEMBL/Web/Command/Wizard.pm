package EnsEMBL::Web::Command::Wizard;

## Generic module for redirecting wizard nodes 
## depending on which form button is clicked

use strict;
use warnings;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self   = shift;
  my $object = $self->object;
  my $back   = $object->param('wizard_back'); # Check if we're going back
  my @steps  = $object->param('_backtrack');
  my $params = {};
  my $url;
  
  if ($back) {
    my $current_node = 'Summary'; ## Default value to stop Magic from barfing
    my $species = $object->type eq 'UserData' ? $object->data_species : $object->species;
    
    $url .= $object->species_path($species) if $species;
    $url .= '/' . $object->type;
    
    pop @steps;
    $current_node = pop @steps;
    $url .= "/$current_node";
  } else {
    $url = $object->param('wizard_next');
  }
  
  # Pass the "normal" parameters but munge the wizard ones
  foreach my $name ($object->param) {
    next if $name =~ /^wizard_/;
    
    my @value = $object->param($name);
    my $value = (@value) ? \@value : $value[0];
    
    if ($name eq '_backtrack' && $back) {
      $value = \@steps;
      
      if (scalar @steps) {
        $object->param('_backtrack', @steps);
      } else {
        $object->delete_param('_backtrack');
      }
    };
    
    $params->{$name} = $value;
  }
  
  $self->ajax_redirect($url, $params); 
}

1;
