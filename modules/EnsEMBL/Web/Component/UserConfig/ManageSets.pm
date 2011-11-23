# $Id$

package EnsEMBL::Web::Component::UserConfig::ManageSets;

use strict;

use base qw(EnsEMBL::Web::Component);

sub content {
  my $self = shift;
  my $sets = $self->sets_table;
  
  return sprintf('
    <input type="hidden" class="panel_type" value="ConfigManager" />
    <div class="config_manager">
      <div class="sets">
        <div class="notes">
          <h4>Help</h4>
          <p class="space-below">You change names and descriptions by clicking on them in the table</p>
        </div>
        <h2>Your configuration sets</h2>
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
    </div>',
    $sets || '<p>You have no configuration sets.</p>',
    $self->records_table,
    $self->new_set_form
  );
}

sub sets_table {
  my $self    = shift;
  my $hub     = $self->hub;
  my $adaptor = $hub->config_adaptor;
  my @sets    = values %{$adaptor->all_sets};
  
  return unless scalar @sets;
  
  my $configs  = $adaptor->all_configs;
  my $img_url  = $self->img_url;
  my $editable = qq{<div><div class="heightWrap"><div class="val" title="Click here to edit">%s</div></div><img class="toggle" src="${img_url}closed2.gif" />%s<a href="%s" class="save"></a></div>};
  my $list     = qq{<div><div class="heightWrap"><ul>%s</ul></div><img class="toggle" src="${img_url}closed2.gif" /></div>};
  my $active   = qq{<a class="edit" href="%s" rel="%s"><img src="${img_url}activate.png" alt="use" title="Use this configuration set" /></a><div class="config_used">Configuration set applied</div>};
  my @rows;
  
  my @columns = (
    { key => 'name',    title => 'Name',           width => '20%',  align => 'left'                   },
    { key => 'desc',    title => 'Description',    width => '40%',  align => 'left'                   },
    { key => 'configs', title => 'Configurations', width => '34%',  align => 'left',   sort => 'none' },
    { key => 'active',  title => '',               width => '20px', align => 'center', sort => 'none' },
    { key => 'edit',    title => '',               width => '20px', align => 'center', sort => 'none' },
    { key => 'delete',  title => '',               width => '20px', align => 'center', sort => 'none' },
  );
  
  foreach (sort { $a->{'name'} cmp $b->{'name'} } @sets) {
    my $record_id = $_->{'record_id'};
    (my $desc     = $_->{'description'}) =~ s/\n/<br \/>/g;
    my %params    = ( action => 'ModifyConfig', __clear => 1, record_id => $record_id, is_set => 1 );
    my (@confs, @rel);
    
    foreach (map $configs->{$_} || (), keys %{$_->{'records'}}) {
      my $view_config = $hub->get_viewconfig(reverse split '::', $_->{'type'} eq 'view_config' ? $_->{'code'} : $_->{'link_code'});
      my $config_type = join ' - ', $view_config->type, $view_config->title;
      push @confs, [ $config_type, $_->{'record_id'}, qq{$_->{'name'} <b class="ellipsis">...</b><span>$config_type</span>} ];
      push @rel, [split '::', $view_config->code]->[-1];
    }
    
    push @rows, {
      name    => { value => sprintf($editable, $_->{'name'}, '<input type="text" maxlength="255" name="name" />', $hub->url({ function => 'edit_details', %params })), class => 'editable wrap' },
      desc    => { value => sprintf($editable, $desc,        '<textarea rows="5" name="description" />',          $hub->url({ function => 'edit_details', %params })), class => 'editable wrap' },
      configs => { value => scalar @confs ? sprintf($list, join '', map qq{<li class="$_->[1]">$_->[2]</li>}, sort { $a->[0] cmp $b->[0] } @confs) : 'There are no configurations in this set', class => 'wrap' },
      active  => sprintf($active, $hub->url({ function => 'activate_set', %params }), join ' ', @rel),
      edit    => sprintf('<a class="edit_record" href="#" rel="%s"><img src="%sedit.png" alt="edit" title="Edit configurations" /></a>', $record_id, $img_url),
      delete  => sprintf('<a class="edit" href="%s" rel="%s"><img src="%sdelete.png" alt="delete" title="Delete" /></a>', $hub->url({ function => 'delete_set', %params }), $record_id, $img_url),
    };
  }
  
  return $self->new_table(\@columns, \@rows, { data_table => 'no_col_toggle', exportable => 0, class => 'fixed editable' })->render;
}

sub records_table {
  my $self    = shift;
  my $hub     = $self->hub;
  my $img_url = $self->img_url;
  my $add     = '<div><a class="add_to_set" href="#" rel="%s" title="Add to set"></a><input type="hidden" name="record_id" class="update" value="%s" /></div>';
  my $wrap    = qq{<div><div class="heightWrap"><div>%s</div></div><img class="toggle" src="${img_url}closed2.gif" /></div>};
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
  $form->add_button({ type => 'submit', value => 'Save', field_class => 'save' });
  
  return $form->render;
}

1;
