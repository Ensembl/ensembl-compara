# $Id$

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
    $params{'record_type_id'} = $params{'record_type'} eq 'session' ? $session->create_session_id : $hub->user ? $hub->user->id : undef;
    
    if ($params{'record_type_id'}) {
      my $adaptor   = $hub->config_adaptor;
      my $configs   = $adaptor->all_configs;
      my $overwrite = $hub->param('overwrite');
         $overwrite = undef unless exists $configs->{$overwrite}; # check that the overwrite id belongs to this user
      my (%existing, @links);
      
      if ($overwrite) {
        foreach my $id ($overwrite, $configs->{$overwrite}{'link_id'} || ()) {
          $existing{$configs->{$id}{'type'}} = { record_id => $id };
          $params{$_} ||= $configs->{$id}{$_} for qw(record_type record_type_id name description);
          push @{$params{'set_ids'}}, $adaptor->record_to_sets($id);
        }
      }
      
      foreach (qw(view_config image_config)) {
        ($params{'code'}, $params{'link'}) = $_ eq 'view_config' ? ($code, [ 'image_config', $image_config ]) : ($image_config, [ 'view_config', $code ]);
        
        my ($saved, $deleted) = $adaptor->save_config(%params, %{$existing{$_}}, type => $_, data => $adaptor->get_config($_, $params{'code'}));
        
        push @links, { id => $saved, code => $params{'code'}, link => $params{'link'}, set_ids => $params{'set_ids'} };
        
        if ($deleted) {
          push @{$existing_config->{'deleted'}}, $deleted;
        } elsif ($saved) {
          $existing_config->{'saved'} ||= { value => $saved, class => $saved, html => $configs->{$saved}{'name'} }; # only provide one saved entry for a linked pair
        }
      }
      
      $adaptor->link_configs(@links);
      
      delete $existing_config->{'saved'} if $overwrite && $configs->{$existing_config->{'saved'}{'value'}}{'link_id'};
    }
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
