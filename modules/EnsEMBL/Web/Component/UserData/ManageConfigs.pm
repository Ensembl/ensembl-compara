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

package EnsEMBL::Web::Component::UserData::ManageConfigs;

use strict;

use HTML::Entities qw(encode_entities);
use URI::Escape    qw(uri_escape);

use base qw(EnsEMBL::Web::Component);

sub default_groups { return $_[0]{'default_groups'} ||= { map { $_ => 1 } @{$_[0]->hub->species_defs->ENSEMBL_DEFAULT_USER_GROUPS || []} }; }
sub admin_groups   { return $_[0]{'admin_groups'}   ||= { $_[0]->hub->user ? map { $_->group_id => $_ } $_[0]->hub->user->find_admin_groups : () }; }
sub record_group   { return $_[1]{'record_type'} eq 'group' && $_[0]->default_groups->{$_[1]{'record_type_id'}} ? 'suggested' : $_[1]{'record_type'}; }
sub empty          { return sprintf '<h2>Your configurations</h2><p>You have no saved configurations%s.</p>', $_[1] ? '' : ' for this page'; }
sub set_view       {}

sub sorted_admin_groups {
  my $self = shift;
  
  if (!$self->{'sorted_admin_groups'}) {
    my $default_groups = $self->default_groups;
    $self->{'sorted_admin_groups'} = [ map $_->[2], sort { ($a->[0] <=> $b->[0]) || ($a->[1] cmp $b->[1]) } map [ $default_groups->{$_->group_id}, lc $_->name, $_ ], values %{$self->admin_groups} ];
  }
  
  return $self->{'sorted_admin_groups'};
}

sub allow_edits {
  my $self = shift;
  
  if (!$self->{'allow_edits'}) {
    my $admin_groups  = $self->admin_groups;
    my $admin_default = scalar grep $admin_groups->{$_}, keys %{$self->default_groups};
    
    $self->{'allow_edits'} = {};
    
    foreach (values %{$self->{'editables'}}) {
      my $group = $self->record_group($_);
      $self->{'allow_edits'}{"$group $_->{'record_type_id'}"} = $self->{'allow_edits'}{$group} = 1 if $group ne 'suggested' || $admin_default;
    }
    
    $self->{'allow_edits'}{'user'} ||= $self->{'allow_edits'}{'session'};
  }
  
  return $self->{'allow_edits'};
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my %help = $hub->species_defs->multiX('ENSEMBL_HELP');
  
  return sprintf('
    <input type="hidden" class="subpanel_type" value="ConfigManager" />
    <div class="config_manager">
      <a title="Click for help (opens in new window)" class="popup constant sprite config_manager_help info_icon _ht" href="/Help/View?id=%s#manage_configs"></a>
      <div class="records">
        %s
      </div>
      %s
      <div class="edit_config_set config_manager">
        <h1 class="edit_header">Select %s for <span class="config_header"></span></h1>
        %s
      </div>
      <div class="share_config%s">
        <h1>Sharing <span class="config_header"></span></h1>
        %s
      </div>
      <div class="save_all_config_set">
        <h1>Save <span class="config_header"></span></h1>
        <p>All linked configurations and sets will also be saved to your account.</p>
        <p>The following will be saved:</p>
        <div class="configs">
          <h4>Configurations</h4>
          <ul></ul>
        </div>
        <div class="sets">
          <h4>Sets</h4>
          <ul></ul>
        </div>
        <input type="button" class="fbutton continue" value="Continue" />
        <input type="button" class="fbutton cancel" value="Cancel" />
      </div>
    </div>
    %s',
    $help{join '/', $hub->type, $hub->action},
    $self->records(@_),
    $self->set_view ? ('', 'configurations') : ($self->reset_all, 'sets'),
    $self->edit_table,
    $self->share,
    $hub->param('reload') ? '<div class="modal_reload"></div>' : ''
  );
}

sub content_update {
  my $self = shift;
  my ($columns, $rows, $json) = $self->records(1, { map { $_ => 1 } $self->hub->param('record_ids') });
  
  return $self->jsonify({
    data   => $json,
    tables => {
      map { $_ => $self->new_table($columns->{$_}, $rows->{$_}, { data_table => 1, exportable => 0 })->render } keys %$rows
    }
  });
}

sub content_config {
  my $self      = shift;
  my $hub       = $self->hub;
  my $record_id = $hub->param('record_id');
  
  return unless $record_id;
  
  my $adaptor     = $hub->config_adaptor;
  my $all_configs = $adaptor->all_configs;
  my $record      = $all_configs->{$record_id};
  
  return unless $record;
  
  my ($vc, $ic) = $record->{'type'} eq 'view_config' ? ($record, $all_configs->{$record->{'link_id'}}) : ($all_configs->{$record->{'link_id'}}, $record);
  my $all_sets  = $adaptor->all_sets;
  my @sets      = sort { $a->[1] cmp $b->[1] } map [ $all_sets->{$_}{'record_id'}, $all_sets->{$_}{'name'} ], $adaptor->record_to_sets($record_id);
  my (@config, $html);
  
  if ($vc) {
    my $view_config = $hub->get_viewconfig(reverse split '::', $vc->{'code'});
    my $settings    = ref $vc->{'data'} eq 'HASH' ? $vc->{'data'} : eval $vc->{'data'} || {};
    
    $view_config->build_form;
    
    my $labels       = $view_config->{'labels'};
    my $value_labels = $view_config->{'value_labels'};
    
    push @config, [ $labels->{$_} || $_, $value_labels->{$_}{$settings->{$_}} || ($settings->{$_} eq lc $settings->{$_} ? ucfirst $settings->{$_} : $settings->{$_}) ] for sort keys %$settings;
  }
  
  if ($ic) {
    my $image_config = $hub->get_imageconfig($ic->{'code'});
    my $settings     = ref $ic->{'data'} eq 'HASH' ? $ic->{'data'} : eval $ic->{'data'} || {};
    
    if ($image_config->multi_species) {
      my $species_defs = $hub->species_defs;
      
      foreach my $species (keys %$settings) {
        my $label        = $species_defs->get_config($species, 'SPECIES_COMMON_NAME');
           $image_config = $hub->get_imageconfig($ic->{'code'}, undef, $species);
        
        while (my ($key, $data) = each %{$settings->{$species}}) {
          push @config, $self->image_config_description($image_config, $key, $data, $label);
        }
      }
    } else {
      while (my ($key, $data) = each %$settings) {
        push @config, $self->image_config_description($image_config, $key, $data);
      }
    }
  }
  
  $html .= sprintf '<div><h4>Configuration</h4><ul>%s</ul></div>',                  join '', map qq{<li>$_->[0]: $_->[1]</li>}, sort { $a->[0] cmp $b->[0] } @config if scalar @config;
  $html .= sprintf '<div><h4>In sets</h4><ul class="editables_list">%s</ul></div>', join '', map sprintf($self->templates->{'list'}, @$_), @sets;
  
  return $html;
}

sub content_all { return $_[0]->content(1); }

sub records {
  my ($self, $show_all, $record_ids) = @_;
  my $hub     = $self->hub;
  my $adaptor = $hub->config_adaptor;
  my $configs = $adaptor->all_configs;
  my $empty   = $self->empty($show_all || !scalar keys %$configs);
  
  return $empty unless scalar keys %$configs;
  
  my (%components, $rows, $json);
  
  if (!$show_all) {
    my $i;
    my $referer     = $hub->referer;
    my $module_name = "EnsEMBL::Web::Configuration::$referer->{'ENSEMBL_TYPE'}";
       %components  = map { $hub->get_viewconfig(@$_)->code => ++$i } $self->dynamic_use($module_name) ? reverse @{$module_name->new_for_components($hub, $referer->{'ENSEMBL_ACTION'}, $referer->{'ENSEMBL_FUNCTION'})} : ();
  }
  
  $self->{'editables'} = $self->deepcopy($adaptor->all_sets);
  
  foreach (values %$configs) {
    my $record_id = $_->{'record_id'};
    
    next if $record_ids && !$record_ids->{$record_id};
    next if $_->{'active'};
    next if $_->{'type'} eq 'image_config' && $_->{'link_id'};
    
    my $vc_code = $_->{'type'} eq 'image_config' && $_->{'link_code'} ? $_->{'link_code'} : $_->{'code'};
    
    next unless $show_all || $components{$vc_code};
    
    my ($type, $code) = split '::', $vc_code;
    my $view_config   = $hub->get_viewconfig($code, $type);
    my $component     = $view_config->component;
    my @sets          = $adaptor->record_to_sets($record_id);
    
    my ($row, $group_key, $json_group) = $self->row($_, { type => $type, conf => $view_config->title });
    
    push @{$rows->{$group_key}}, $row;
    push @{$self->{'editables'}{$_}{'conf_codes'}}, "${type}_$code" for @sets;
    
    $json->{$record_id} = {
      id        => $record_id,
      name      => $_->{'name'},
      group     => $json_group,
      groupId   => $_->{'record_type_id'},
      codes     => [ "${type}_$code" ],
      editables => { map { $self->{'editables'}{$_}{'record_id'} => 1 } @sets }
    };
  }
  
  return $empty unless scalar keys %$rows;
  
  my $columns = $self->columns;
  
  return ($columns, $rows, $json) if $record_ids;
  return $self->records_html($columns, $rows, $json) . qq{<div class="hidden no_records">$empty</div>};
}

sub records_html {
  my ($self, $columns, $rows, $json) = @_;
  
  return sprintf('
    %s
    <input type="hidden" class="js_param" name="updateURL" value="%s" />
    <input type="hidden" class="js_param" name="recordType" value="%s" />
    <input type="hidden" class="js_param" name="userId" value="%s" />
    <input type="hidden" class="js_param" name="listTemplate" value="%s" />
    <input type="hidden" class="js_param json" name="records" value="%s" />
    <input type="hidden" class="js_param json" name="editables" value="%s" />',
    $self->records_tables($columns, $rows),
    $self->ajax_url('update', { update_panel => 1 }),
    $self->set_view ? 'set' : 'config',
    $self->hub->user ? $self->hub->user->user_id : '',
    encode_entities(sprintf($self->templates->{'list'})), # remove any %s inside the list template
    encode_entities($self->jsonify($json)),
    encode_entities($self->jsonify({ map { $_ => {
      name  => $self->{'editables'}{$_}{'name'},
      conf  => $self->{'editables'}{$_}{'conf_name'},
      codes => $self->{'editables'}{$_}{'conf_codes'} || [],
    }} keys %{$self->{'editables'}} }))
  );
}

sub records_tables {
  my ($self, $columns, $rows, $headers) = @_;
  my $html;
  
  $headers ||= {
    user      => 'Your configurations',
    group     => 'Configurations from your groups',
    suggested => 'Suggested configurations',
  };
  
  foreach (qw(user group suggested)) {
    my @sorted = sort { $a->{'type'} cmp $b->{'type'} || $a->{'conf'} cmp $b->{'conf'} || $a->{'name'}{'sort'} cmp $b->{'name'}{'sort'} } @{$rows->{$_} || []};
    
    $html .= sprintf(
      '<div class="record_type %s"><h2>%s</h2>%s</div>',
      join(' ', $_, scalar @sorted ? () : 'hidden'),
      $headers->{$_},
      $self->new_table($columns->{$_}, \@sorted, { data_table => 'no_sort no_col_toggle', exportable => 0, class => "fixed editable heightwrap_inside $_" })->render
    );
  }
  
  return $html;
}

sub templates {
  return $_[0]{'templates'} ||= {
    wrap     => '<div class="height_wrap"><div class="val name">%s</div></div>',
    editable => '<div><div class="height_wrap"><div class="val" title="Click here to edit">%s</div></div>%s<a href="%s" class="save"></a></div>',
    expand   => '<a class="icon_link _ht expand" title="See more details" href="%s">&#9660;</a><a class="icon_link _ht collapse hidden" title="Collapse" href="#">&#9650;</a>',
    icon     => '<a class="icon_link sprite _ht %s_icon %s" title="%s" href="%s">&nbsp;</a>%s',
    disabled => '<span class="icon_link sprite_disabled _ht %s_icon" title="%s">&nbsp;</span>',
    add      => '<a class="add_to_set" href="#" rel="%s"><span class="removed _ht" title="Add to set">&nbsp;</span><span class="added _ht" title="Remove from set">&nbsp;</span></a>',
    list     => '<li class="%s"><span class="name">%s</span></li>',
    icon_col => { title => '', width => '16px', align => 'center' },
  };
}

sub row {
  my ($self, $record, $row, $text) = @_;
  my $hub          = $self->hub;
  my $set_view     = $self->set_view;
  my $templates    = $self->templates;
  my $desc         = $record->{'description'} =~ s|\n|<br />|rg;
  my $record_id    = $record->{'record_id'};
  my %params       = ( action => 'ModifyConfig', __clear => 1, record_id => $record_id, ($set_view ? (is_set => 1) : ()) );
  my $edit_url     = $hub->url({ function => 'edit_details', %params });
  my $group        = $record->{'record_type'} eq 'group';
  my $record_group = $self->record_group($record);
  
  $row  ||= {};
  $text ||= [
    'Use this configuration',
    '<div class="config_used">Configuration applied</div>',
    'Edit sets'
  ];
  
  $row->{'expand'}  = sprintf $templates->{'expand'}, $self->ajax_url('config', { __clear => 1, record_id => $record_id, update_panel => 1 });
  $row->{'active'}  = sprintf $templates->{'icon'}, 'use', 'edit', $text->[0], $hub->url({ function => 'activate', %params }), $text->[1];
  $row->{'options'} = { class => $record_id };
  
  if ($group && !$self->admin_groups->{$record->{'record_type_id'}}) {
    $row->{'name'}   = { value => sprintf($templates->{'wrap'}, $record->{'name'}), class => 'wrap' };
    $row->{'desc'}   = { value => sprintf($templates->{'wrap'}, $desc),             class => 'wrap' };
    $row->{'delete'} = sprintf $templates->{'disabled'}, 'delete', 'You must be a group administrator to delete this configuration' . ($set_view ? ' set' : '');
    $row->{'edit'}   = sprintf $templates->{'disabled'}, 'edit',   'You must be a group administrator to edit this configuration'   . ($set_view ? ' set' : '');
  } else {
    $row->{'name'}   = { value => sprintf($templates->{'editable'}, $record->{'name'}, '<input type="text" maxlength="255" name="name" />', $edit_url), class => 'editable wrap' };
    $row->{'desc'}   = { value => sprintf($templates->{'editable'}, $desc,             '<textarea rows="5" name="description"></textarea>', $edit_url), class => 'editable wrap' };
    $row->{'delete'} = sprintf $templates->{'icon'}, 'delete', 'edit',         'Delete', $hub->url({ function => 'delete', %params, link_id => $record->{'link_id'} });
    $row->{'share'}  = sprintf $templates->{'icon'}, 'share',  'share_record', 'Share',  $hub->url({ function => 'share',  %params }) unless $group;
    $row->{'edit'}   = sprintf $templates->{'icon'}, 'edit',   'edit_record',  $text->[2], '#';

    
    if ($record->{'record_type'} eq 'session' && $hub->users_available) {
      $params{'then'} = uri_escape($hub->url({ __clear => 1, reload => 1 })) unless $hub->user;
      $row->{'save'}  = sprintf $templates->{'icon'}, 'save', 'edit', $hub->user ? 'Save to account' : 'Log in to save', $hub->url({ function => 'save', %params });
      $row->{'save'} .= sprintf $templates->{'icon'}, '', 'edit save_all', '', $hub->url({ function => 'save', %params, save_all => 1 });
    } elsif ($record->{'record_type'} eq 'user') {
      $row->{'save'} = sprintf $templates->{'disabled'}, 'save', 'Saved';
    }
  }
  
  if ($record_group eq 'group') {
    my $group_object = $hub->user->get_group($record->{'record_type_id'});
    $row->{'group'} = { value => sprintf($templates->{'wrap'}, $group_object->name), class => 'wrap' } if $group_object;
  }
  
  $row->{'name'}{'sort'} = $record->{'name'};
  
  return ($row, $record_group eq 'session' ? 'user' : $record_group, $record_group);
}

sub columns {
  my ($self, $cols) = @_;
  my $hub           = $self->hub;
  my %icon_col      = %{$self->templates->{'icon_col'}};
  my $admin_groups  = $self->admin_groups;
  my $admin_default = scalar grep $admin_groups->{$_}, keys %{$self->default_groups};
  my $groups;
  
  $cols ||= [
    { key => 'expand', %icon_col },
    { key => 'type', title => 'Type',          width => '15%' },
    { key => 'conf', title => 'Configuration', width => '20%' },
    sub {
      return $_[0] eq 'group' ? (
          { key => 'name',  title => 'Name',  width => '15%' },
          { key => 'group', title => 'Group', width => '15%' }
      ) : { key => 'name',  title => 'Name',  width => '30%' };
    },
    { key => 'desc', title => 'Description', width => '20%' },
  ];
  
  my $columns = [
    @$cols,
    { key => 'active', %icon_col },
    sub { return $_[0] eq 'user' && $hub->users_available ? { key => 'save',   %icon_col } : (); },
    sub { return $self->allow_edits->{$_[0]}              ? { key => 'edit',   %icon_col } : (); },
    sub { return $_[0] eq 'user'                          ? { key => 'share',  %icon_col } : (); },
    sub { return $_[0] ne 'suggested' || $admin_default   ? { key => 'delete', %icon_col } : (); },
  ];
  
  foreach my $type (qw(user group suggested)) {
    $groups->{$type} = [ map { ref eq 'CODE' ? &$_($type) : $_ } @$columns ];
  }
  
  return $groups;
}

sub image_config_description {
  my ($self, $image_config, $key, $conf, $label) = @_;
  
  return () if $key eq 'track_order';
  
  my $node = $image_config->get_node($key);
  
  return () unless $node;
  
  my $data      = $node->data;
  my $renderers = $data->{'renderers'} || [ 'off', 'Off', 'normal', 'On' ];
  my %valid     = @$renderers;
  return [ join(' - ', grep $_, $label, $data->{'caption'} || $data->{'name'}), $valid{$conf->{'display'}} || $valid{'normal'} || $renderers->[3] ];
}

sub edit_table {
  my $self = shift;
  
  return '' unless scalar keys %{$self->{'editables'}};
  
  return $self->edit_table_html([
    { key => 'name', title => 'Name',        width => '30%' },
    { key => 'desc', title => 'Description', width => '65%' },
  ], [ map $self->edit_table_row($_), values %{$self->{'editables'}} ]);
}

sub edit_table_row {
  my ($self, $record, $row) = @_;
  my $templates   = $self->templates;
  my $record_type = $record->{'record_type'};
     $row       ||= {};
  
  $row->{'name'}    = { value => sprintf($templates->{'wrap'}, $record->{'name'}),        class => 'wrap', sort => $record->{'name'} };
  $row->{'desc'}    = { value => sprintf($templates->{'wrap'}, $record->{'description'}), class => 'wrap' };
  $row->{'add'}     = sprintf $templates->{'add'}, $record->{'record_id'};
  $row->{'options'} = { class => join(' ', $record->{'record_id'}, @{$record->{'conf_codes'} || []}), record => $record };
  
  return $row;
}

sub edit_table_html {
  my ($self, $columns, $rows) = @_;
  my $hub      = $self->hub;
  my $user     = $hub->user;
  my $set_view = $self->set_view;
  my $form     = $self->new_form({ action => $hub->url({ action => 'ModifyConfig', function => 'edit_sets', __clear => 1 }), method => 'post', class => 'edit_record' });
  my $fieldset = $form->add_fieldset;
  my $type     = $set_view ? 'configurations' : 'sets';
  my (%tables, $html);
  
  $fieldset->append_child('input', { type => 'checkbox', class => "selected hidden $_", name => 'update_id', value => $_        }) for keys %{$self->{'editables'}};
  $fieldset->append_child('input', { type => 'hidden',   class => 'record_id',          name => 'record_id', value => ''        });
  $fieldset->append_child('input', { type => 'hidden',                                  name => 'is_set',    value => $set_view });
  $fieldset->append_child('input', { type => 'submit',   class => 'save fbutton',                            value => 'Save'    });
  
  foreach (@$rows) {
    my $record = delete $_->{'options'}{'record'};
    push @{$tables{$self->record_group($record) . ' ' . $record->{'record_type_id'}}}, $_
  }
  
  # Make sure there is at least an empty table
  $tables{'session ' . $hub->session->session_id} ||= [];
  
  if ($user) {
    my $default_groups = $self->default_groups;
    
    $tables{'user ' . $user->user_id} ||= [];
    $tables{($default_groups->{$_} ? 'suggested' : 'group') . " $_"} ||= [] for keys %{$self->admin_groups};
  }
  
  foreach (sort keys %tables) {
    my $text = join '', /user|session/ ? 'your ' : '', /user/ ? 'account' : /session/ ? 'session' : $user->get_group([split ' ']->[1])->name;
    
    $html .= $self->new_table([
      @$columns, { key => 'add', %{$self->templates->{'icon_col'}} }
    ], [
      sort { $a->{'type'} cmp $b->{'type'} || $a->{'conf'} cmp $b->{'conf'} || $a->{'name'}{'sort'} cmp $b->{'name'}{'sort'} } @{$tables{$_}}
    ], {
      data_table        => 'no_col_toggle no_sort',
      data_table_config => { iDisplayLength => 10, oLanguage => { sEmptyTable => "There are no $type from $text" } },
      exportable        => 0,
      class             => 'fixed heightwrap_inside',
      wrapper_class     => "record_type $_",
      wrapper_html      => $user ? sprintf('<p>%s from %s</p>', ucfirst $type, $text) : '',
    })->render;
  }
  
  return $html . $form->render;
}

sub share {
  my $self     = shift;
  my $hub      = $self->hub;
  my $form     = $self->new_form({ action => $hub->url({ action => 'ModifyConfig', function => 'share', __clear => 1 }), method => 'post' });
  my $groups   = $self->sorted_admin_groups;
  my $fieldset = $form->add_fieldset({ legend => 'Generate a URL to share with another user' });
  my $class;
  
  $fieldset->append_child('input', { type => 'button', class => 'make_url', value => 'Share' });
  $fieldset->append_child('input', { type => 'text',   class => 'share_url' });
  $fieldset->append_child('input', { type => 'hidden', class => 'record_id', name => 'record_id' });
  $fieldset->append_child('input', { type => 'hidden', name => 'is_set', value => $self->set_view });
  
  if (scalar @$groups) {
    $form->add_fieldset({ legend => '<span class="or">OR</span>Share with groups you administer', class => 'group' });
    $form->add_field({ type => 'Checkbox', value => $_->group_id, label => $_->name, class => 'group', name => 'group' }) for @$groups;
    $form->add_element({ type => 'Submit', value => 'Share', class => 'share_groups save disabled', disabled => 1 });
  } else {
    $class = ' narrow';
  }
  
  $form->append_child('p', { class => 'invisible' });
  
  return ($class, $form->render);
}

sub reset_all {
  my $self    = shift;
  my $hub     = $self->hub;
  my $configs = $hub->config_adaptor->all_configs;
  
  return sprintf('
    <div class="reset_all%s">
      <h2>Reset all configurations</h2>
      %s
    </div>',
    grep($configs->{$_}{'active'} eq 'y', keys %$configs) ? '' : ' hidden',
    $self->warning_panel('WARNING', sprintf('
      <p>This will reset all of your configurations to default.</p>
      <p>Saved configurations will not be affected.</p>
      <form action="%s"><input class="fbutton" type="submit" value="Reset" /></form>',
      $hub->url({ action => 'ModifyConfig', function => 'reset_all', __clear => 1 })
    ))
  );
}

1;
