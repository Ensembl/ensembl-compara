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

package EnsEMBL::Web::Component::UserData::ManageConfigSets;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::UserData::ManageConfigs);

sub empty    { return sprintf '<div class="no_records%s"><h2>Your configuration sets</h2><p>You have no configuration sets.</p></div>', $_[1] ? ' hidden' : ''; }
sub set_view { return 1; }

sub records {
  my ($self, $show_all, $config_keys) = @_;
  my $hub     = $self->hub;
  my $adaptor = $hub->config_adaptor;
  my @sets    = values %{$adaptor->all_sets};
  my $json    = {};
  my $rows    = {};
  
  $self->{'editables'} = { map { $_->{'type'} eq 'image_config' && $_->{'link_key'} ? () : ($_->{'config_key'} => $_) } values %{$self->deepcopy($adaptor->filtered_configs({ active => '' }))} };
  
  my $new_set = scalar keys %{$self->{'editables'}} ? '<p><a href="#" class="create_set">Create a new configuration set</a></p>' : '<p>You must save some configurations before you can create a new configuration set.</p>';
  
  foreach (values %{$self->{'editables'}}) {
    my @config_code = split '::', $_->{'type'} eq 'view_config' ? $_->{'code'} : $_->{'link_code'};
    my $view_config = $hub->get_viewconfig(reverse @config_code);
    
    next unless $view_config;
    
    $_->{'conf_name'}  = join ' - ', $view_config->type, $view_config->title;
    $_->{'conf_codes'} = [ join '_', @config_code ];
  }
  
  foreach (sort { $a->{'name'} cmp $b->{'name'} } @sets) {
    my $config_key = $_->{'config_key'};
    
    next if $config_keys && !$config_keys->{$config_key};
    
    my @confs;
    
    foreach (map $self->{'editables'}{$_} || (), keys %{$_->{'records'}}) {
      push @confs, [ $_->{'config_key'}, $_->{'name'}, $_->{'conf_name'}, $_->{'conf_codes'} ] if $_->{'conf_name'};
    }
    
    my ($row, $group_key, $json_group) = $self->row($_, \@confs);
    
    push @{$rows->{$group_key}}, $row;
    
    $json->{$config_key} = {
      id        => $config_key,
      name      => $_->{'name'},
      group     => $json_group,
      groupId   => $_->{'record_type_id'},
      codes     => [ map @{$_->[3]}, @confs ],
      editables => { map { $_->[0] => 1 } @confs }
    };
  }
  
  my $columns = $self->columns;
  
  return ($columns, $rows, $json) if $config_keys;
  return $self->records_html($columns, $rows, $json) . $self->empty(scalar @sets) . $new_set;
}

sub records_tables {
  my ($self, $columns, $rows) = @_;
  
  return $self->SUPER::records_tables($columns, $rows, {
    user      => 'Your configuration sets',
    group     => 'Configuration sets from your groups',
    suggested => 'Suggested configuration sets',
  });
}

sub templates {
  return $_[0]{'templates'} ||= {
    %{$_[0]->SUPER::templates},
    conf_list => '<div class="none%s">There are no configurations in this set</div><div class="height_wrap%s"><ul class="configs editables_list val">%s</ul></div>',
    list      => '<li class="%s"><span class="name">%s</span> <b class="ellipsis">...</b><span class="conf">%s</span></li>',
  };
}

sub row {
  my ($self, $record, $confs) = @_;
  my $templates = $self->templates;
  
  return $self->SUPER::row($record, {
    confs => { value => sprintf($templates->{'conf_list'}, @$confs ? ('', '') : (' show', ' hidden'), join '', map sprintf($templates->{'list'}, @$_), sort { $a->[2] cmp $b->[2] } @$confs), class => 'wrap' },
  }, [
    'Use this configuration set',
    '<div class="config_used">Configurations applied</div>',
    'Edit configurations'
  ]);
}

sub columns {
  return $_[0]->SUPER::columns([
    { key => 'name', title => 'Name', width => '20%' },
    sub { return $_[0] eq 'group' ? { key => 'group', title => 'Group', width => '20%' } : (); },
    sub { return { key => 'desc',  title => 'Description',    width => $_[0] eq 'group' ? '20%' : '30%' }; },
    sub { return { key => 'confs', title => 'Configurations', width => $_[0] eq 'group' ? '25%' : '35%' }; },
  ]);
}

sub edit_table {
  my $self = shift;
  
  return '' unless scalar keys %{$self->{'editables'}};
  
  my @rows;
  
  foreach (values %{$self->{'editables'}}) {
    my $i;
    push @rows, $self->edit_table_row($_, { map { ($i++ ? 'conf' : 'type') => $_ } split ' - ', $_->{'conf_name'} }) if $_->{'conf_name'};
  }
  
  return $self->edit_table_html([
    { key => 'type', title => 'Type',          width => '15%' },
    { key => 'conf', title => 'Configuration', width => '20%' },
    { key => 'name', title => 'Name',          width => '30%' },
    { key => 'desc', title => 'Description',   width => '30%' },
  ], \@rows);
}

sub edit_table_html {
  my ($self, $columns, $rows) = @_;
  
  return join('',
    '<h1 class="add_header">Create a new set</h1>',
    $self->SUPER::edit_table_html($columns, $rows),
    $self->new_set_form
  )
}

sub new_set_form {
  my $self     = shift;
  my $hub      = $self->hub;
  my $user     = $hub->user;
  my $form     = $self->new_form({ action => $hub->url({ action => 'ModifyConfig', function => 'add_set' }), method => 'post', class => 'add_set', skip_validation => 1 });
  my $fieldset = $form->add_fieldset;
  
  if ($user) {
    my $groups = $self->sorted_admin_groups;
    
    $fieldset->add_field({
      wrapper_class => 'save_to',
      type          => 'Radiolist',
      name          => 'record_type',
      class         => 'record_type',
      label         => 'Save to:',
      values        => [{ value => 'user', caption => 'Account' }, { value => 'session', caption => 'Session' }, scalar @$groups ? { value => 'group', caption => 'Groups you administer' } : ()],
      value         => 'user',
      label_first   => 1,
    });
    
    if (scalar @$groups) {
      my $default_groups = $self->default_groups;
      
      $fieldset->add_field({
        field_class => 'groups hidden',
        type        => 'Radiolist',
        name        => 'group',
        label       => 'Groups:',
        values      => [ map { value => $_->group_id, caption => $_->name, class => [ 'group', $default_groups->{$_->group_id} ? 'suggested' : () ] }, @$groups ],
        value       => $groups->[0]->group_id,
        label_first => 1,
      });
    }
  } else {
    $fieldset->append_child('input', { type => 'hidden', name => 'record_type', class => 'record_type', value => 'session' });
  }
  
  $fieldset->add_field({ type => 'String', name => 'name',        label => 'Configuration set name', required => 1, maxlength => 255 });
  $fieldset->add_field({ type => 'Text',   name => 'description', label => 'Configuration set description'                           });
  
  $fieldset->append_child('input', { type => 'checkbox', value => $_,     class => "selected hidden $_", name => 'config_key' }) for keys %{$self->{'editables'}};
  $fieldset->append_child('input', { type => 'submit',   value => 'Save', class => 'save fbutton'                             });
  
  return $form->render;
}

1;
