package EnsEMBL::Web::Command::Export::Type;

use strict;

use Class::Std;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  
  my $action = $object->action;
  my $function = $object->function; 
  
  my $params = {};
  map { $params->{$_} = $object->param($_) unless $object->param($_) =~ /^off|no$/ } $object->param;
  
  my $type;
  
  if ($action eq 'Location' && $function eq 'LD') {
    $type = 'LDFormats';
  } elsif ($action eq 'Transcript' && $function eq 'Population') {
    $type = 'PopulationFormats';
  } elsif ($function eq 'Compara_Alignments') {
    $type = 'Alignments';
  } else {
    $type = 'Configure';
  }
  
  my $url = sprintf '/%s/Export/%s/%s', $object->species, $type, $action;
  
  $self->ajax_redirect($url, $params);
}

}

1;
