# $Id$

package EnsEMBL::Web::Component::UserData::ManageConfigs;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component);

sub default_groups { return $_[0]{'default_groups'} ||= { map { $_ => 1 } @{$_[0]->hub->species_defs->ENSEMBL_DEFAULT_USER_GROUPS || []} }; }
sub admin_groups   { return $_[0]{'admin_groups'}   ||= { $_[0]->hub->user ? map { $_->group_id => 1 } $_[0]->hub->user->find_admin_groups : () }; }
sub record_group   { return $_[1]{'record_type'} eq 'group' && $_[0]->default_groups->{$_[1]{'record_type_id'}} ? 'suggested' : $_[1]{'record_type'}; }
sub empty          { return sprintf '<p>You have no custom configurations%s.</p>', $_[1] ? '' : ' for this page'; }
sub set_view       {}

sub content {
  my $self = shift;
  
  return sprintf('
    <input type="hidden" class="subpanel_type" value="ConfigManager" />
    <div class="config_manager">
      <div class="records">
        %s
      </div>
      <div class="edit_config_set config_manager">
        <h1 class="edit_header">Select %s for <span class="config_header"></span></h1>
        %s
      </div>
      <div class="share_config%s">
        <h1>Sharing <span class="config_header"></span></h1>
        %s
      </div>
    </div>',
    $self->records(@_),
    $self->set_view ? 'configurations' : 'sets',
    $self->edit_table,
    $self->share
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
  my ($self, $record_id) = @_;
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
  my $list      = '<li class="%s">' . $self->templates->{'wrap'} . '</li>';
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
  $html .= sprintf '<div><h4>In sets</h4><ul class="editables_list">%s</ul></div>', join '', map sprintf($list, @$_), @sets;
  
  return $html;
}

sub content_all { return $_[0]->content(1); }

sub records {
  my ($self, $show_all, $record_ids) = @_;
  my $hub     = $self->hub;
  my $adaptor = $hub->config_adaptor;
  my $configs = $adaptor->all_configs;
  my $none    = $self->empty($show_all || !scalar keys %$configs);
  
  return $none unless scalar keys %$configs;
  
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
    
    my ($row, $row_key, $json_group) = $self->row($_, { type => $type, conf => $view_config->title });
    
    push @{$rows->{$row_key}}, $row;
    push @{$self->{'editables'}{$_}{'conf_codes'}}, "${type}_$code" for @sets;
    
    $json->{$record_id} = {
      id        => $record_id,
      name      => $_->{'name'},
      group     => $json_group,
      codes     => [ "${type}_$code" ],
      editables => { map { $self->{'editables'}{$_}{'record_id'} => 1 } @sets }
    };
  }
  
  return $none unless scalar keys %$rows;
  
  my $columns = $self->columns;
  
  return ($columns, $rows, $json) if $record_ids;
  return $self->records_html($columns, $rows, $json);
}

sub records_html {
  my ($self, $columns, $rows, $json) = @_;
  
  return sprintf('
    %s
    <input type="hidden" class="js_param" name="updateURL" value="%s" />
    <input type="hidden" class="js_param" name="recordType" value="%s" />
    <input type="hidden" class="js_param" name="listTemplate" value="%s" />
    <input type="hidden" class="js_param json" name="records" value="%s" />
    <input type="hidden" class="js_param json" name="editables" value="%s" />',
    $self->records_tables($columns, $rows),
    $self->ajax_url('update', { update_panel => 1 }),
    $self->set_view ? 'set' : 'config',
    encode_entities(sprintf($self->templates->{'list'}) || sprintf('<li>%s</li>', $self->templates->{'wrap'})),
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
    
    if ($record->{'record_type'} eq 'user') {
      $row->{'save'} = sprintf $templates->{'disabled'}, 'save', 'Saved';
    } else {
      $row->{'save'} = sprintf $templates->{'icon'}, 'save', 'edit', 'Save to account', $hub->url({ function => 'save', %params });
    }
  }
  
  $row->{'name'}{'sort'} = $record->{'name'};
  
  return ($row, $record_group eq 'session' ? 'user' : $record_group, $record_group);
}

sub columns {
  my ($self, $cols) = @_;
  my %icon_col = %{$self->templates->{'icon_col'}};
  my ($groups, %editable);
  
  $cols ||= [
    { key => 'expand', %icon_col },
    { key => 'type', title => 'Type',          width => '15%' },
    { key => 'conf', title => 'Configuration', width => '20%' },
    { key => 'name', title => 'Name',          width => '30%' },
    { key => 'desc', title => 'Description',   width => '30%' },
  ];
  
  my $columns = [
    @$cols,
    { key => 'active', %icon_col },
    { key => 'save',   %icon_col },
    { key => 'edit',   %icon_col },
    { key => 'share',  %icon_col },
    { key => 'delete', %icon_col },
  ];
  
  $editable{$self->record_group($_)} = 1 for values %{$self->{'editables'}};
  
  foreach (qw(user group suggested)) {
    my $regex = sprintf '^(%s)$', join '|', $_ eq 'user' ? () : qw(save share), $editable{$_} ? () : 'edit';
    $groups->{$_} = [ grep $_->{'key'} !~ /$regex/, @$columns ];
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
  $row->{'options'} = { class => join(' ', $record->{'record_id'}, @{$record->{'conf_codes'} || []}), table => $self->record_group($_) };
  
  return $row;
}

sub edit_table_html {
  my ($self, $columns, $rows) = @_;
  my $form     = $self->new_form({ action => $self->hub->url({ action => 'ModifyConfig', function => 'edit_sets', __clear => 1 }), method => 'post', class => 'edit_record' });
  my $fieldset = $form->add_fieldset;
  
  $fieldset->append_child('input', { type => 'checkbox', class => "selected hidden $_", name => 'update_id', value => $_              }) for keys %{$self->{'editables'}};
  $fieldset->append_child('input', { type => 'hidden',   class => 'record_id',          name => 'record_id', value => ''              });
  $fieldset->append_child('input', { type => 'hidden',                                  name => 'is_set',    value => $self->set_view });
  $fieldset->append_child('input', { type => 'submit',   class => 'save fbutton',                            value => 'Save'          });
  
  my %tables;
  push @{$tables{delete $_->{'options'}{'table'}}}, $_ for @$rows;
  
  return join('',
    map($self->new_table(
      [ @$columns, { key => 'add', %{$self->templates->{'icon_col'}} } ],
      [ sort { $a->{'type'} cmp $b->{'type'} || $a->{'conf'} cmp $b->{'conf'} || $a->{'name'}{'sort'} cmp $b->{'name'}{'sort'} } @{$tables{$_}} ],
      { data_table => 'no_col_toggle no_sort', exportable => 0, class => 'fixed heightwrap_inside', wrapper_class => "record_type $_", data_table_config => { iDisplayLength => 10 } }
    )->render, sort keys %tables),
    $form->render
  );
}

sub share {
  my $self     = shift;
  my $hub      = $self->hub;
  my $user     = $hub->user;
  my $form     = $self->new_form({ action => $hub->url({ action => 'ModifyConfig', function => 'share', __clear => 1 }), method => 'post' });
  my @groups   = $user ? $user->find_admin_groups : ();
  my $fieldset = $form->add_fieldset({ legend => 'Generate a URL to share with another user' });
  my $class;
  
  $fieldset->append_child('input', { type => 'button', class => 'make_url', value => 'Share' });
  $fieldset->append_child('input', { type => 'text',   class => 'share_url' });
  $fieldset->append_child('input', { type => 'hidden', class => 'record_id', name => 'record_id' });
  $fieldset->append_child('input', { type => 'hidden', name => 'is_set', value => $self->set_view });
  
  if (scalar @groups) {
    $form->add_fieldset({ legend => '<span class="or">OR</span>Share with groups you administer', class => 'group' });
    $form->add_field({ type => 'Checkbox', value => $_->group_id, label => $_->name, class => 'group', name => 'group' }) for @groups;
    $form->add_element({ type => 'Submit', value => 'Share', class => 'share_groups save disabled', disabled => 1 });
  } else {
    $class = ' narrow';
  }
  
  $form->append_child('p', { class => 'invisible' });
  
  return ($class, $form->render);
}

1;
