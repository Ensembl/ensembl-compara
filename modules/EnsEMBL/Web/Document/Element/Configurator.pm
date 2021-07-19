=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Element::Configurator;

# Generates the modal context navigation menu, used in dynamic pages

use strict;

use EnsEMBL::Web::Attributes;

use base qw(EnsEMBL::Web::Document::Element::Content);

sub tree    :AccessorMutator;
sub active  :AccessorMutator;
sub caption :AccessorMutator;

sub content {
  my $self = shift;
  
  my $content = $self->{'form'};
  $content   .= $_->component_content for @{$self->{'panels'}};
  $content   .= '</form>' if $self->{'form'};
  
  return $content;
}

sub get_json {
  my $self = shift;
  
  return {
    wrapper   => qq{<div class="modal_wrapper config_wrapper"></div>},
    content   => $self->content,
    params    => $self->{'json'},
    panelType => $self->{'panel_type'}
  };
}

sub init {
  my $self       = shift;
  my $controller = shift;
  my $navigation = $controller->page->navigation;

  $self->init_config($controller);
  
  $navigation->tree($self->tree);
  $navigation->active($self->active);
  $navigation->caption($self->caption);
  $navigation->configuration(1);
}

sub init_config {
  my ($self, $controller, $url) = @_;
  my $hub         = $controller->hub;
  my $action      = $hub->action;
  my $view_config = $hub->get_viewconfig($action);
  my $img_url     = $self->img_url;

  return unless $view_config;

  my $panel         = $self->new_panel('Configurator', $controller, code => 'configurator');
  my $image_config  = $view_config->image_config_type ? $hub->get_imageconfig({type => $view_config->image_config_type, cache_code => 'configurator', species => $hub->species}) : undef;
  my $top_form      = EnsEMBL::Web::Form->new({'class' => [qw(bgcolour _config_settings)], 'action' => '#'});
  my $search_box;

  $view_config->build_form($controller->object, $image_config);

  if ($image_config) {
    if ($image_config->get_parameter('multi_species')) {

      my @sp = @{$image_config->species_list};

      if (@sp) {
        my $species_select = $top_form->add_field({
          'field_class'   => 'species_select',
          'label'         => 'Species to configure',
          'inline'        => 1,
          'elements'      => [{
            'element_class' => 'species_select_select',
            'type'          => 'dropdown',
            'name'          => 'species',
            'class'         => '_stt',
            'values'        => [ map {
              'caption'       => $_->[1],
              'value'         => $hub->url('Config', { 'species' => $_->[0], '__clear' => 1 }),
              'class'         => "_stt__$_->[0]",
              'selected'      => $hub->species eq $_->[0] ? 1 : 0
            }, @sp ]
          }, {
            'type'          => 'noedit',
            'is_html'       => 1,
            'no_input'      => 1,
            'value'         => join('', map sprintf('<span class="_stt_%s"><img class="nosprite" src="%sspecies/48/%1$s.png" alt="" /></span>', $_->[0], $img_url), @sp)
          }]
        });
      }
    }
    
    $search_box = qq{<div class="configuration_search"><input class="configuration_search_text" value="Find a track" name="configuration_search_text" /></div>};
    
    $self->active($image_config->get_parameter('active_menu') || 'active_tracks');
  }

  # Add config selector dropdown at the top
  $top_form->add_field({
    'field_class'   => '_config_dropdown config_dropdown hidden',
    'label'         => 'Select from available configurations',
    'elements'      => [{
      'type'          => 'dropdown',
      'name'          => 'config_selector',
    }, {
      'type'          => 'string',
      'value'         => 'Enter configuration name'
    }, {
      'type'          => 'submit',
      'value'         => 'Save',
    }]
  });
  $top_form->add_hidden([{
    'name'      => 'config_selector_url',
    'value'     => $hub->url('Config', {function => 'list_configs', '__clear' => 1}),
    'class'     => 'js_param'
  }, {
    'name'      => 'config_save_url',
    'value'     => $hub->url('Config', {function => 'save_config', '__clear' => 1}),
    'class'     => 'js_param'
  }, {
    'name'      => 'config_apply_url',
    'value'     => $hub->url('Config', {function => 'apply_config', '__clear' => 1}),
    'class'     => 'js_param'
  }]);

  if (!$self->active || !$view_config->tree->get_node($self->active)) {
    my @nodes     = @{$view_config->tree->root->child_nodes};
    $self->active(undef);
    
    while (!$self->active && scalar @nodes) {
      my $node      = shift @nodes;
      $self->active($node->id) if $node->data->{'class'};
    }
  }
  
  my $form = $view_config->form;
  
  if ($hub->param('matrix')) {
    $panel->{'content'} = $form->render;
  } else {
    $form->add_hidden({ name => 'component', value => $action, class => 'component' });
    $panel->set_content($top_form->render . $search_box . $form->render . $self->save_as($hub->user, $view_config, $view_config->image_config_type));
  }

  $self->{'panel_type'} = $form->js_panel;

  $self->add_panel($panel);
  
  $self->tree($view_config->tree);
  $self->caption('Configure view');
  
  $self->{'json'} = $view_config->form->{'json'} || {}; #TODO - respect encapsulation

  $self->add_image_config_notes($controller) if ($image_config && !$hub->param('matrix'));
}

sub add_image_config_notes {
  my ($self, $controller) = @_;
  my $panel   = $self->new_panel('Configurator', $controller, code => 'x', class => 'image_config_notes' );
  my $img_url = $self->img_url;
  my $trackhub_link = $self->hub->url({'type' => 'UserData', 'action' => 'TrackHubSearch'});

  $panel->set_content(qq(
    <div class="info-box">
    <p>Looking for more data? Search the <a href="${trackhub_link}" class="modal_link">Trackhub Registry</a> for external sources of annotation</p>
    </div>
    <h2 class="clear">Key</h2>
    <div>
      <ul class="configuration_key">
        <li><img src="${img_url}render/normal.gif" /><span>Track style</span></li>
        <li><img src="${img_url}strand-f.png" /><span>Forward strand</span></li>
        <li><img src="${img_url}strand-r.png" /><span>Reverse strand</span></li>
        <li><img src="${img_url}star-on.png" /><span>Favourite track</span></li>
        <li><img src="${img_url}16/info.png" /><span>Track information</span></li>
      </ul>
    </div>
    <div>
      <ul class="configuration_key">
        <li><img src="${img_url}track-external.gif" /><span>External data</span></li>
        <li><img src="${img_url}track-user.gif" /><span>User-added track</span></li>
      </ul>
    </div>
    <p class="space-below">Please note that the content of external tracks is not the responsibility of the Ensembl project.</p>
    <p>URL-based tracks may either slow down your ensembl browsing experience OR may be unavailable as these are served and stored from other servers elsewhere on the Internet.</p>
  ));

  $self->add_panel($panel);
}

sub save_as { return '';
  my ($self, $user, $view_config, $image_config) = @_;
  my $hub    = $self->hub;
  my $data   = $hub->config_adaptor->filtered_configs({ code => $image_config ? [ $view_config->code, $image_config ] : $view_config->code, active => '' });
  my %groups = $user ? map { $_->group_id => $_ } $user->find_admin_groups : ();
  my ($configs, %seen, $save_to);
  
  foreach (sort { $a->{'name'} cmp $b->{'name'} } values %$data) {
    next if $seen{$_->{'config_key'}};
    
    $seen{$_} = 1 for $_->{'config_key'}, $_->{'link_key'};
    
    next if $_->{'record_type'} eq 'group' && !$groups{$_->{'record_type_id'}};
    
    $configs .= sprintf(
      '<option value="%s" class="%1$s">%s%s</option>',
      $_->{'config_key'},
      $_->{'name'},
      $user ? sprintf(' (%s%s)', $_->{'record_type'} eq 'user' ? 'Account' : ucfirst $_->{'record_type'}, $_->{'record_type'} eq 'group' ? ': ' . $groups{$_->{'record_type_id'}}->name : '') : ''
    ); 
  }
  
  my $existing = sprintf('
    <div%s>
      <label>Existing configuration:</label>
      <select name="overwrite" class="existing%s">
        <option value="">----------</option>
        %s
      </select>
      <h2>Or</h2>
    </div>',
    $configs ? '' : ' style="display:none"',
    $configs ? '' : ' disabled',
    $configs
  );
  
  if ($user) {
    $save_to = sprintf('
      <p>
        <label>Save to:</label>
        <span>Account <input type="radio" name="record_type" value="user" class="default save_to" checked /></span>
        <span>Session <input type="radio" name="record_type" value="session" class="save_to" /></span>
        %s
      </p>',
      scalar keys %groups ? '<span>Groups you administer <input type="radio" name="record_type" value="group" class="save_to" /></span>' : ''
    );
    
    if (scalar keys %groups) {
      my %default_groups = map { $_ => 1 } @{$hub->species_defs->ENSEMBL_DEFAULT_USER_GROUPS || []};
      
      $save_to .= '<div class="groups"><h4>Groups:</h4>';
      
      foreach (sort { ($a->[0] <=> $b->[0]) || ($a->[1] cmp $b->[1]) } map [ $default_groups{$_->group_id}, lc $_->name, $_ ], values %groups) {
        $save_to .= sprintf('
          <div class="form-field">
            <label class="group ff-label">%s:</label>
            <div class="ff-right"><input type="checkbox" value="%s" name="group" class="group" /></div>
          </div>',
          $_->[2]->name, $_->[2]->group_id
        );
      }
      
      $save_to .= '</div>';
    }
  } else {
    $save_to = '<input type="hidden" name="record_type" value="session" />';
  }
  
  return qq{
    <div class="config_save_as">
      <h1>Save configuration</h1>
      <form>
        $existing
        $save_to
        <p><label>Name:</label><input class="name" type="text" name="name" maxlength="255" /></p>
        <p><label>Description:</label><textarea class="desc" name="description" rows="5"></textarea></p>
        <input class="fbutton disabled" type="button" value="Save" />
      </form>
    </div>
  };
}

1;
