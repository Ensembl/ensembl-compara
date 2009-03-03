package EnsEMBL::Web::Command::UserData::ValidateDAS;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Filter::DAS;
use base 'EnsEMBL::Web::Command';

{

sub BUILD {
}

sub process {
  my $self = shift;
  my $url = '/'.$self->object->data_species.'/UserData/';
  my $param;

  ## Catch any errors at the server end
  my $filter = EnsEMBL::Web::Filter::DAS->new({'object'=>$self->object});
  my $sources = $filter->catch($self->object->param('dsn'));
  if ($filter->error_code) {
    $url .= 'SelectDAS';
    $param->{'filter_module'} = 'DAS';
    $param->{'filter_code'} = $filter->error_code;
  }
  else {
    my $no_species = 0;
    my $no_coords  = 0;
    $param->{'selected_das'} = $self->object->das_server_param;
    $param->{'species'} = $self->object->param('species');
    $param->{'coords'} = $self->object->param('coords');
    $param->{'dsn'} = $self->object->param('dsn');

    for my $source (@{ $sources }) {
      # If one or more source has missing details, need to fill them in and resubmit
      unless (@{ $source->coord_systems } || $self->object->param('coords')) {
        $no_coords = 1;
        if (!$self->object->param('species')) {
          $no_species = 1;
        }
      }
    }

    warn "++ NO SPECIES: $no_species";
    warn "++ NO COORDS: $no_coords";

    my $next = $no_species ? 'SelectDasSpecies'
           : $no_coords  ? 'SelectDasCoords'
           : 'AttachDAS';
    warn ">>> NEXT $next";
    $url .= $next;
  }
  #$self->ajax_redirect($url, $param); 

}

}

1;
