# $Id$

package EnsEMBL::Web::Command::UserData::AttachDAS;

use strict;

use Bio::EnsEMBL::ExternalData::DAS::CoordSystem;

use EnsEMBL::Web::Filter::DAS;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $session = $hub->session;
  my $url     = $hub->species_path($hub->data_species) . '/UserData/';
  my $server  = $hub->param('das_server');
  my $params  = {};
  
  if ($server) {
    my $filter  = new EnsEMBL::Web::Filter::DAS({ object => $object });
    my $sources = $filter->catch($server, $hub->param('logic_name'));
    
    if ($filter->error_code) {
      $url .= 'SelectDAS';
      $params->{'filter_module'} = 'DAS';
      $params->{'filter_code'}   = $filter->error_code;
    } else {
      my (@success, @skipped);
      
      foreach my $source (@$sources) {
        # Fill in missing coordinate systems
        if (!scalar @{$source->coord_systems}) {
          my @expand_coords = grep $_, $hub->param($source->logic_name . '_coords');
          
          if (scalar @expand_coords) {
            @expand_coords = map Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new_from_string($_), @expand_coords;
            $source->coord_systems(\@expand_coords);
          } else {
            $params->{'filter_module'} = 'DAS';
            $params->{'filter_code'}   = 'no_coords';
          }
        }

        # NOTE: at present the interface only allows adding a source that has not
        # already been added (by disabling their checkboxes). Thus this call
        # should always evaluate true at present.
        if ($session->add_das($source)) {
          push @success, $source->logic_name;
        } else {
          push @skipped, $source->logic_name;
        }
        
        $session->configure_das_views($source, $hub); # Turn the source on
      }
      
      $session->save_das;
      $session->store;
      
      $url .= 'DasFeedback';
      $params->{'added'}   = \@success;
      $params->{'skipped'} = \@skipped;
    }
  } else {
    $url .= 'SelectDAS';
    $params->{'filter_module'} = 'DAS';
    $params->{'filter_code'}   = 'no_server';
  }
  
  $self->ajax_redirect($url, $params);
}

1;
