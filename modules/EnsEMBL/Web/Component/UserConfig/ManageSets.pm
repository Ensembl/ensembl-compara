# $Id$

package EnsEMBL::Web::Component::UserConfig::ManageSets;

use strict;

use base qw(EnsEMBL::Web::Component);

sub content {
  my $self = shift;
  
  return sprintf('
    <input type="hidden" class="subpanel_type" value="ConfigManager" />
    <div class="config_manager">
      <div class="sets">
        <div class="info">
          <h3>Help</h3>
          <div class="message-pad"><p>You can change names and descriptions by clicking on them in the table</p></div>
        </div>
        %s
        <p><a href="#" class="create_set"><span class="create">Create a new configuration set</span><span class="cancel">[Cancel]</span></a></p>
      </div>
      <div class="edit_set">
        <h4>Select configurations for the set:</h4>
        %s
      </div>
      <div class="new_set">
        %s
      </div>
      <div class="share_config">
        %s
      </div>
    </div>',
    $self->sets_table || '<p>You have no configuration sets.</p>',
    $self->records_table,
    $self->new_set_form,
    $self->share
  );
}

sub sets_table {
  my $self    = shift;
  my $hub     = $self->hub;
  my $adaptor = $hub->config_adaptor;
  my @sets    = values %{$adaptor->all_sets};

  return unless scalar @sets;
  
  my %admin_groups = $hub->user ? map { $_->group_id => 1 } $hub->user->find_admin_groups : ();
  my $configs      = $adaptor->all_configs;
  my $img_url      = $self->img_url;
  my $icon_url     = $img_url . '16/';
  my $editable     = qq{<div><div class="heightWrap"><div class="val" title="Click here to edit">%s</div></div>%s<a href="%s" class="save"></a></div>};
  my $list         = qq{<div><div class="heightWrap"><ul>%s</ul></div></div>};
  my $active       = qq{<a class="edit icon_link sprite _ht use_icon" href="%s" rel="%s" title="Use this configuration set">&nbsp;</a><div class="config_used">Configuration applied</div>};
  my (%rows, $html);
  
  my @columns = (
    { key => 'name',    title => 'Name',           width => '20%',  align => 'left'                   },
    { key => 'desc',    title => 'Description',    width => '40%',  align => 'left'                   },
    { key => 'configs', title => 'Configurations', width => '34%',  align => 'left',   sort => 'none' },
    { key => 'active',  title => '',               width => '20px', align => 'center', sort => 'none' },
    { key => 'edit',    title => '',               width => '20px', align => 'center', sort => 'none' },
    { key => 'share',   title => '',               width => '20px', align => 'center', sort => 'none' },
    { key => 'delete',  title => '',               width => '20px', align => 'center', sort => 'none' },
  );

  foreach (sort { $a->{'name'} cmp $b->{'name'} } @sets) {
    my $record_id = $_->{'record_id'};
    my $group     = $_->{'record_type'} eq 'group';
    (my $desc     = $_->{'description'}) =~ s/\n/<br \/>/g;
    my %params    = ( action => 'ModifyConfig', __clear => 1, record_id => $record_id, is_set => 1 );
    my (@confs, @rel);
     
    foreach (map $configs->{$_} || (), keys %{$_->{'records'}}) {
      my $view_config = $hub->get_viewconfig(reverse split '::', $_->{'type'} eq 'view_config' ? $_->{'code'} : $_->{'link_code'});
      next unless $view_config;
      my $config_type = join ' - ', $view_config->type, $view_config->title;
      push @confs, [ $config_type, $_->{'record_id'}, qq{$_->{'name'} <b class="ellipsis">...</b><span>$config_type</span>} ];
      push @rel, [split '::', $view_config->code]->[-1];
    }
    
    my %row = (
      configs => { value => scalar @confs ? sprintf($list, join '', map qq{<li class="$_->[1]">$_->[2]</li>}, sort { $a->[0] cmp $b->[0] } @confs) : 'There are no configurations in this set', class => 'wrap' },
    );
    
    if ($group && !$admin_groups{$_->{'record_type_id'}}) {
      $row{'name'} = { value => $_->{'name'}, class => 'wrap' };
      $row{'desc'} = { value => $desc,        class => 'wrap' };
    } else {
      $row{'name'}   = { value => sprintf($editable, $_->{'name'}, '<input type="text" maxlength="255" name="name" />', $hub->url({ function => 'edit_details', %params })), class => 'editable wrap' };
      $row{'desc'}   = { value => sprintf($editable, $desc,        '<textarea rows="5" name="description" />',          $hub->url({ function => 'edit_details', %params })), class => 'editable wrap' };
      $row{'active'} = sprintf($active, $hub->url({ function => 'activate_set', %params }), join ' ', @rel);
      $row{'edit'}   = sprintf('<a class="icon_link sprite _ht edit_icon edit_record" href="#" rel="%s" title="Edit configurations">&nbsp;</a>', $record_id);
      $row{'share'}  = sprintf('<a class="icon_link sprite _ht share_icon share_record" href="%s" rel="%s" title="Share">&nbsp;</a>', $hub->url({ function => 'share',      %params }), $_->{'name'}) unless $group;
      $row{'delete'} = sprintf('<a class="icon_link sprite _ht delete_icon edit" href="%s" rel="%s" title="Delete">&nbsp;</a>',       $hub->url({ function => 'delete_set', %params }), $record_id);
    }
    
    push @{$rows{$group ? 'group' : 'user'}}, \%row;
  }
  
  foreach (grep $rows{$_}, qw(user group)) {
    $html .= sprintf '<h2>%s</h2>', $_ eq 'user' ? 'Your configuration sets' : 'Configuration sets from your groups';
    $html .= $self->new_table(\@columns, $rows{$_}, { data_table => 'no_col_toggle', exportable => 0, class => 'fixed editable heightwrap_inside' })->render;
  }
  
  return $html;
}

sub records_table {
  my $self    = shift;
  my $hub     = $self->hub;
  my $img_url = $self->img_url;
  my $add     = '<div><a class="add_to_set" href="#" rel="%s" title="Add to set"></a><input type="hidden" name="record_id" class="update" value="%s" /></div>';
  my $wrap    = qq{<div><div class="heightWrap"><div>%s</div></div></div>};
  my (%configs, %entries, @rows);
  
  my @columns = (
    { key => 'type',        title => 'Type',        width => '10%',  align => 'left'   },
    { key => 'title',       title => 'Title',       width => '15%',  align => 'left'   },
    { key => 'name',        title => 'Name',        width => '15%',  align => 'left'   },
    { key => 'description', title => 'Description', width => '55%',  align => 'left'   },
    { key => 'add',         title => '',            width => '20px', align => 'center' },
  );
  
  push @{$configs{$_->{'type'}}{$_->{'code'}}}, $_ for values %{$hub->config_adaptor->filtered_configs({ active => '' })};
  
  foreach my $type ('view_config', 'image_config') {
    foreach my $code (sort keys %{$configs{$type}}) {
      foreach (@{$configs{$type}{$code}}) {
        next if $type eq 'image_config' && $_->{'link_id'};
        
        my @config_code = split '::', $type eq 'view_config' ? $code : $_->{'link_code'};
        my $view_config = $hub->get_viewconfig(reverse @config_code);
        next unless $view_config;
        push @{$entries{$view_config->type}{join '_', @config_code}}, { %$_, title => $view_config->title };
      }
    }
  }
  
  foreach my $type (sort keys %entries) {
    foreach my $code (sort keys %{$entries{$type}}) {
       foreach (@{$entries{$type}{$code}}) {
        push @rows, {
          type        => $type,
          title       => $_->{'title'},
          name        => { value => sprintf($wrap, $_->{'name'}),        class => 'wrap' },
          description => { value => sprintf($wrap, $_->{'description'}), class => 'wrap' },
          add         => sprintf($add,  $code, $_->{'record_id'}),
          options     => { class => $code }
        };
      }
    }
  }
  
  return $self->new_table(\@columns, \@rows, { data_table => 'no_col_toggle no_sort', exportable => 0, class => 'fixed' })->render;
}

sub new_set_form {
  my $self = shift;
  my $hub  = $self->hub;
  my $form = $self->modal_form('', $hub->url({ action => 'ModifyConfig', function => 'add_set' }), { no_button => 1 });
  
  if ($hub->user) {
    my $field = $form->add_field({
      wrapper_class => 'save_to',
      type          => 'Radiolist',
      name          => 'record_type',
      label         => 'Save to:',
      values        => [{ value => 'user', caption => 'Account' }, { value => 'session', caption => 'Session' }],
      value         => 'user',
      inline        => 1,
      label_first   => 1
    });
  } else {
    $form->add_hidden({ name => 'record_type', value => 'session' });
  }
  
  $form->add_field({ type => 'String', name => 'name',        label => 'Configuration set name', required => 1, maxlength => 255 });
  $form->add_field({ type => 'Text',   name => 'description', label => 'Configuration set description'                           });
  $form->add_button({ type => 'submit', value => 'Save', field_class => 'save_button' });
  
  return $form->render;
}

sub share {
  my $self   = shift;
  my $hub    = $self->hub;
  my $user   = $hub->user;
  my $form   = $self->new_form({ url => $hub->url({ function => 'share', is_set => 1, __clear => 1 }) });
  my @groups = $user ? $user->find_admin_groups : ();
  
  my $fieldset = $form->add_fieldset({ legend => 'Generate a URL to share with another user' });
  
  $fieldset->append_child('input', { type => 'button', class => 'make_url', value => 'Go' });
  $fieldset->append_child('input', { type => 'text',   class => 'share_url' });
  
  if (scalar @groups) {
    $form->add_fieldset({ legend => 'Share with groups you administer', class => 'group' });
    $form->add_field({ type => 'Checkbox', value => $_->group_id, label => $_->name, class => 'group' }) for @groups;
    $form->add_element({ type => 'Button', value => 'Share', class => 'share_groups' });
  } else {
    $form->set_attribute('class', 'narrow');
  }
  
  $form->append_child('p', { class => 'invisible' });
  
  return $form->render;
}

1;
