=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Controller::Config;

### Prints the configuration modal dialog.

use strict;

use Encode qw(decode_utf8);

use base qw(EnsEMBL::Web::Controller::Modal);

sub page_type { return 'Configurator'; }

sub init {
  my $self = shift;
  
  $self->SUPER::init unless $self->update_configuration; # config has updated and redirect is occurring
}

sub update_configuration {
  ### Checks to see if the page's view config or image config has been changed
  ### If it has, returns 1 to force a redirect to the updated page
  
  my $self = shift;
  my $hub  = $self->hub;
  
  return unless $hub->param('submit') || $hub->param('reset');
  
  my $r            = $self->r;
  my $session      = $hub->session;
  my $view_config  = $hub->get_viewconfig($hub->action);
  my $code         = $view_config->code;
  my $image_config = $view_config->image_config;  
  my $updated      = $view_config->update_from_input;
  my $existing_config;
  
  $session->store;
  
  if ($hub->param('save_as')) {
    my %params = map { $_ => decode_utf8($hub->param($_)) } qw(record_type name description);
    $params{'record_type_ids'} = $params{'record_type'} eq 'group' ? [ $hub->param('group') ] : $params{'record_type'} eq 'session' ? $session->create_session_id : $hub->user ? $hub->user->id : undef;
    $existing_config = $self->save_config($code, $image_config, %params);
  }
  
  if ($hub->param('submit')) {
    if ($r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest') {
      my $json = {};
      
      if ($hub->action =~ /^(ExternalData|TextDAS)$/) {
        my $function = $view_config->altered == 1 ? undef : $view_config->altered;
        
        $json = {
          redirect => $hub->url({ 
            action   => 'ExternalData', 
            function => $function, 
            %{$hub->referer->{'params'}}
          })
        };
      } elsif ($updated || $hub->param('reload')) {
        $json = $updated if ref $updated eq 'HASH';
        $json->{'updated'}  = 1;
      }
      
      $json->{'existingConfig'} = $existing_config if $existing_config;
      
      $r->content_type('text/plain');
      
      print $self->jsonify($json || {});
    } else {
      $hub->redirect; # refreshes the page
    }
    
    return 1;
  }
}

1;
