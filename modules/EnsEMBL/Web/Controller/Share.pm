=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Controller::Share;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use JSON qw(to_json);

use ORM::EnsEMBL::DB::Session::Manager::ShareURL;

use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

use parent qw(EnsEMBL::Web::Controller);

sub rose_manager {
  ## Rose manager for share table
  return 'ORM::EnsEMBL::DB::Session::Manager::ShareURL';
}

sub parse_path_segments {
  # Abstract method implementation
  my $self          = shift;
  my @path          = @{$self->path_segments};
  my $request_type  = $self->{'request_type'} = $self->query_param('create') ? 'create' : 'accept';
  my $share_type    = $self->{'share_type'} = $self->query_param('share_type') || 'page';

  # when accepting a share request, first segment is the share code
  if ($request_type eq 'accept') {
    my $code  = $self->{'code'} = shift @path;
    my $row   = $self->{'row'}  = $self->rose_manager->fetch_by_primary_key($code) if $code;

    if ($row) {
      $self->{$_} = $row->$_ for qw(type action function);
    }
  } else {

    # for image share, last part in the path is the component code
    if ($share_type eq 'image') {
      $self->{'component_code'} = pop @path;
    }

    ($self->{'type'}, $self->{'action'}, $self->{'function'}, $self->{'sub_function'}) = (@path, '', '', '', '');
  }
}

sub process {
  ## @override
  my $self    = shift;
  my $hub     = $self->hub;
  my $request = $self->{'request_type'};
  my $return  = $self->can("share_$request")->($self);

  # accept
  $self->redirect($return) if $request eq 'accept';

  # create
  print to_json($return || {}) if $request eq 'create';
}

sub share_create {
  ## Creates a share link
  my $self        = shift;
  my $hub         = $self->hub;
  my $components  = $self->_get_components($self->{'component_code'});
  my $share_url   = $hub->get_permanent_url($self->referer->{'absolute_url'} =~ s/^http(s)?\:\/\/[^\/]+//r);

  # extract data from all linked viewconfigs and imageconfigs
  my $data = {};
  foreach my $component_code (keys %$components) {
    my $viewconfig = $components->{$component_code}->viewconfig;

    if ($viewconfig) {
      my $imageconfig = $viewconfig->image_config;
      my $vc_settings = $viewconfig->get_shareable_settings;
      my $ic_settings = $imageconfig ? $imageconfig->get_shareable_settings : {};

      $data->{$component_code}{'view_config'}   = $vc_settings if keys %$vc_settings;
      $data->{$component_code}{'image_config'}  = $ic_settings if keys %$ic_settings;
    }
  }

  if (keys %$data) {
    my $code    = md5_hex(to_json($data).$hub->species_defs->ENSEMBL_VERSION); # same data gets new url in new release
    my $manager = $self->rose_manager;

    if (!$manager->fetch_by_primary_key($code)) {

      # add an entry in the table
      if ($manager->create_empty_object({
        'code'        => $code,
        'url'         => $share_url,
        'type'        => $self->type,
        'action'      => $self->action,
        'function'    => $self->function,
        'data'        => $data,
        'share_type'  => $self->{'share_type'},
        'created_at'  => 'now',
      })->save) {
        $manager->object_class->init_db->commit;
      } else {
        $code = 0;
      }
    }

    $share_url = $hub->get_permanent_url({'type' => 'Share', 'action' => $code, 'function' => '', __clear => 1 }) if $code;
  }

  return { url => $share_url };
}

sub share_accept {
  ## Accepts an incoming share link and returns the link where user should be redirected
  my $self    = shift;
  my $hub     = $self->hub;
  my $manager = $self->rose_manager;
  my $code    = $self->{'code'};
  my $row     = $self->{'row'};

  if ($row) {
    my $data        = $row->data->raw;
    my $components  = $self->_get_components(keys %$data);

    foreach my $component_code (keys %$components) {
      my $viewconfig = $components->{$component_code}->viewconfig;

      if ($viewconfig) {
        if (my $vc_settings = $data->{$component_code}{'view_config'}) {
          $viewconfig->receive_shared_settings($vc_settings);
        }

        if (
          (my $ic_settings = $data->{$component_code}{'image_config'}) &&
          (my $imageconfig = $viewconfig->image_config)
        ) {
          $imageconfig->receive_shared_settings($ic_settings);
        }
      }
    }

    $row->used($row->used + 1);
    $row->save;

    $hub->store_records_if_needed;
    $manager->object_class->init_db->commit; # store_records_if_needed may not do it if no records where changed

    return $row->url;
  }

  return '/';
}

sub _get_components {
  ## @private
  my $self          = shift;
  my $hub           = $self->hub;
  my $configuration = $self->configuration;
  my $node          = $configuration->get_node($configuration->get_valid_action($self->action, $self->function));
  my %components    = @{$node ? $node->get_data('components') : ()};
  my %required      = map { $_ => 1 } grep $_, @_;

  # remove the components that are not required
  if (keys %required) {
    delete $components{$_} for grep !$required{$_}, keys %components;
  }

  # instantiate all components
  for (keys %components) {
    $components{$_} = dynamic_require($components{$_})->new($hub, undef, undef, $_);
  }

  return \%components;
}

1;
