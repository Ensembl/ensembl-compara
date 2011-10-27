# $Id$

package EnsEMBL::Web::Component::UserData::ManageData;

use strict;

use EnsEMBL::Web::Data::Session;
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $session      = $hub->session;
  my $session_id   = $session->session_id;
  my $user         = $hub->user;
  my $species_defs = $hub->species_defs;
  my $logins       = $species_defs->ENSEMBL_LOGINS;
  my $not_found    = 0;
  my (@data, $html);  
 
  my @temp_data = map $session->get_data('type' => $_), qw(upload url);
  push @temp_data, values %{$session->get_all_das};
  
  push @data, map $user->$_, qw(uploads urls dases) if $user;
  push @data, @temp_data;
  
  if (scalar @data) {
    my @rows;
    my @columns = (
      { key => 'type',    title => 'Type',         width => '10%', align => 'left'                  },
      { key => 'name',    title => 'Source',       width => '39%', align => 'left', class => 'wrap' },
      { key => 'species', title => 'Species',      width => '15%', align => 'left'                  },
      { key => 'date',    title => 'Last updated', width => '16%', align => 'left'                  },
    );
    
    if ($logins) {
      push @columns, { key => 'rename', title => '', width => '5%', align => 'right' };
      
      if ($species_defs->SAVE_UPLOADED_DATA ne '0') {
        push @columns, (
          { key => 'save',  title => '', width => '5%', align => 'right' },
          { key => 'share', title => '', width => '5%', align => 'right' }
        );
      }
    }
    
    push @columns, ({ key => 'delete', title => '', width => '5%', align => 'right' });
    
    foreach my $file (@data) {
      my $sharers = $file->{'code'} =~ /_$session_id$/ ? EnsEMBL::Web::Data::Session->count(code => $file->{'code'}, type => $file->{'type'}) : 0;
         $sharers-- if $sharers && !$file->{'user_id'}; # Take one off for the original user
      
      my $row = ref($file) =~ /DAS/ ? $self->table_row_das($file, ref($file) =~ /Record/) : $self->table_row($file, $sharers);
      
      my ($type, $id) = $file->{'analyses'} =~ /^(session|user)_(\d+)_/;
         ($id, $type) = (($file->{'code'} =~ /_(\d+)$/), 'session') unless $type;
      
      # Remove controls if the data does not belong to the current user
      if (($type eq 'session' && $id != $session->session_id) || ($type eq 'user' && $user && $id != $user->id) || ($type eq 'user' && !$user)) {
        delete $row->{$_} for qw(save share rename);
      }
      
      push @rows, $row;
      
      if ($file->{'filename'} && !EnsEMBL::Web::TmpFile::Text->new(filename => $file->{'filename'}, extension => $file->{'extension'})->exists) {
        $file->{'name'} .= ' (File could not be found)';
        $not_found++;
      }
    }
    
    $html = $self->new_table(\@columns, \@rows, { class => 'fixed' })->render;
  }
  
#  $html  .= $self->group_shared_data; # DOESN'T WORK YET
  $html  .= $self->_warning('File not found', sprintf('The file%s marked not found %s unavailable. Please try again later.', $not_found == 1 ? ('', 'is') : ('s', 'are')), '100%') if $not_found;
  $html ||= '<p class="space-below">You have no custom data.</p>';
  $html  .= '<div class="modal_reload"></div>' if $hub->param('reload');
  
  my $notes = sprintf(qq{
    <div class="notes"><h4>%s</h4>%s</div>
    <h2 class="legend">Your data</h2>
    $html
  }, scalar @temp_data && $user && $user->find_administratable_groups ?
    ( 'Sharing with groups', '<p>Please note that you cannot share temporary data with a group until you save it to your account.</p>' ) :
    ( 'Help',                '<p class="space-below"><a href="/info/website/upload/index.html" class="popup">Help on supported formats, display types, etc</a></p>' )
  );
}

sub table_row {
  my ($self, $file, $sharers) = @_;
  my $hub          = $self->hub;
  my $delete_class = $sharers ? 'modal_confirm' : 'modal_link';
  my $title        = $sharers ? ' title="This data is shared with other users"' : '';
  my $login        = sprintf '<a href="%s" class="modal_link">Log in to %%s</a>', $hub->url({ type => 'Account', action => 'Login', __clear => 1 });
  my $user_record  = ref($file) =~ /Record/;
  my $name         = '<strong>';
  my %url_params   = ( __clear => 1, source => $file->{'url'} ? 'url' : 'upload' );
  my $save;
  
  if ($user_record) {
    $url_params{'id'} = $file->id;
  } else {
    $url_params{'code'} = $file->{'code'};
  }
  
  if ($file->{'nearest'}) {
    $name .= sprintf(
      '<a href="%s" title="Jump to sample region with data">%s</a>',
      $hub->url({
        species  => $file->{'species'},
        type     => 'Location',
        action   => 'View',
        function => undef,
        r        => $file->{'nearest'},
        __clear  => 1
      }),
      $file->{'name'}
    )
  } else {
    $name .= $file->{'name'};
  }
  
  $name .= '</strong><br />';
  $name .= $file->{'url'} || "$file->{'format'} file";
  
  if ($user_record) {
    $save = 'Saved';
  } elsif ($file->{'format'} eq 'SNP_EFFECT') {
    $save = sprintf(
      '<a href="%s" class="modal_link">View results</a>',
      $hub->url({
        species      => $file->{'species'},
        action       => 'PreviewConvertIDs',
        format       => 'text',
        data_format  => 'snp',
        convert_file => "$file->{'filename'}:$file->{'name'}"
      })
    );
  } elsif ($hub->user) {
    $save = sprintf '<a href="%s" class="modal_link">Save to account</a>', $hub->url({ action => 'ModifyData', function => $file->{'url'} ? 'save_remote' : 'save_upload', code => $file->{'code'}, __clear => 1 });
  }
  
  return {
    type    => $file->{'url'} ? 'URL' : 'Upload',
    name    => { value => $name, class => 'wrap' },
    species => sprintf('<em>%s</em>', $hub->species_defs->get_config($file->{'species'}, 'SPECIES_SCIENTIFIC_NAME')),
    date    => $self->pretty_date($file->{'timestamp'}, 'simple_datetime'),
    save    => $save || sprintf($login, 'save'),
    share   => sprintf('<a href="%s" class="modal_link">Share</a>',  $hub->url({ action => 'SelectShare', %url_params })),
    rename  => sprintf('<a href="%s" class="modal_link">Rename</a>', $hub->url({ action => $user_record ? 'RenameRecord' : 'RenameTempData', %url_params })),
    delete  => sprintf('<a href="%s" class="%s"%s>Delete</a>',       $hub->url({ action => 'ModifyData', function => $file->{'url'} ? 'delete_remote' : 'delete_upload', %url_params }), $delete_class, $title),
  };
}

sub table_row_das {
  my ($self, $file, $user_record) = @_;
  my $hub = $self->hub;
  my (%url_params, $save);
  
  if ($user_record) {
    %url_params = ( id => $file->id );
    $save       = 'Saved';
  } else {
    %url_params = ( code => $file->logic_name );
    $save       = $hub->user ?
      sprintf '<a href="%s" class="modal_link">Save to account</a>', $hub->url({ action => 'ModifyData', function => 'save_remote', dsn => $file->logic_name, __clear => 1 }) : 
      sprintf '<a href="%s" class="modal_link">Log in to save</a>',  $hub->url({ type => 'Account', action => 'Login', __clear => 1 });
  }
  
  return {
    type   => 'DAS',
    name   => { value => $file->label, class => 'wrap' },
    date   => '-',
    delete => sprintf('<a href="%s" class="modal_link">Delete</a>',  $hub->url({ action => 'ModifyData', function => 'delete_remote', source => 'das', __clear => 1, %url_params })),
    save   => $save
  };
}

sub group_shared_data {
  my $self = shift;
  my $hub  = $self->hub;
  my $user = $hub->user;
  
  return unless $user;
  
  my @columns = (
    { key => 'type',    title => 'Type',         width => '10%', align => 'left'                  },
    { key => 'name',    title => 'Source',       width => '39%', align => 'left', class => 'wrap' },
    { key => 'species', title => 'Species',      width => '15%', align => 'left'                  },
    { key => 'date',    title => 'Last updated', width => '16%', align => 'left'                  },
    { key => 'share',   title => '',             width => '20%', align => 'right'                 }
  );
  
  my ($html, @rows);
  
  foreach my $group ($user->groups) {
    foreach (grep $_, $group->uploads, $group->urls) {
      push @rows, {
        %{$self->table_row($_)},
        share => sprintf('<a href="%s" class="modal_link">Unshare</a>', $hub->url({ action => 'Unshare', id => $_->id, webgroup_id => $group->id, __clear => 1 }))
      };
    }
    
    next unless scalar @rows;
    
    $html .= sprintf '<h4>Data shared from the %s group</h4>', $group->name;
    $html .= $self->new_table(\@columns, \@rows, { class => 'fixed' })->render;
  }
  
  return $html;
}

1;