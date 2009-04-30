package EnsEMBL::Web::Command::UserData::AttachDAS;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::DASConfig;
use base 'EnsEMBL::Web::Command';

{

sub BUILD {
}

sub process {
  my $self = shift;
  my $url = '/'.$self->object->data_species.'/UserData/';
  my ($next, $param);

  my $server = $self->object->param('das_server');

  if ($server) {
    my $filter = EnsEMBL::Web::Filter::DAS->new({'object'=>$self->object});
    my $sources = $filter->catch($server, $self->object->param('source_id'));
    if ($filter->error_code) {
      $url .= 'SelectDAS';
      $param->{'filter_module'} = 'DAS';
      $param->{'filter_code'} = $filter->error_code;
    }
    else {
    
      my @success = ();
      my @skipped = ();

      foreach my $source (@{ $sources }) {
        my $source_id = $source->{'source_id'}; ## Save for use later in loop
        $source->{'url'} = $self->object->param('das_server');
        delete($source->{'source_id'}); ## Parameter only used by web interface

        my $das_config = EnsEMBL::Web::DASConfig->new_from_hashref( $source );
        next unless $das_config && ref $das_config;
        use Data::Dumper;
        warn '>>> 1 '.Dumper($das_config);

        # Fill in missing coordinate systems
        if (!scalar @{ $das_config->coord_systems }) {
          my @expand_coords = grep { $_ } $self->object->param($source_id.'_coords');
          #warn "EXPANDED COORDS @expand_coords";
          if (scalar @expand_coords) {
            @expand_coords = map {
              Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new_from_string($_)
            } @expand_coords;
          }
          else {
            $param->{'filter_module'} = 'DAS';
            $param->{'filter_code'} = 'no_coords';
            #warn 'DAS ERROR: Source '.$das_config->logic_name.' has no coordinate systems and none were selected.';
          }
          $das_config->coord_systems(\@expand_coords);
        }
        warn '>>> 2 '.Dumper($das_config);

        # NOTE: at present the interface only allows adding a source that has not
        # already been added (by disabling their checkboxes). Thus this call
        # should always evaluate true at present.
        if( $self->object->get_session->add_das( $das_config ) ) {
          warn "+++ DAS ADDED";
          push @success, $das_config->logic_name;
        } 
        else {
          push @skipped, $das_config->logic_name;
        }
        #  Either way, turn the source on...
        $self->object->get_session->configure_das_views(
          $das_config,
          $self->object->_parse_referer( $self->object->param('_referer') )
        );
      }
      $self->object->get_session->save_das;
      $url .= 'DasFeedback';
      $param->{'added'} = \@success;
      $param->{'skipped'} = \@skipped;
    }
  }
  else {
    $next = 'SelectDAS';
    $param->{'filter_module'} = 'DAS';
    $param->{'filter_code'} = 'no_server';
  }

  $self->ajax_redirect($url.$next, $param);
}

}

1;
