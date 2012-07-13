# $Id$

package EnsEMBL::Web::Component::UserData::ManageData;

use strict;

use URI::Escape qw(uri_escape);

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
 
  my @temp_data = map $session->get_data('type' => $_), qw(upload url nonpositional);
  push @temp_data, values %{$session->get_all_das};
  
  push @data, map $user->$_, qw(uploads urls dases) if $user;
  push @data, @temp_data;
  
  if (scalar @data) {
    my @rows;
    my @columns = (
      { key => 'type',    title => 'Type',         width => '10%', align => 'left'                                  },
      { key => 'name',    title => 'Source',       width => '40%', align => 'left', sort => 'html', class => 'wrap' },
      { key => 'species', title => 'Species',      width => '20%', align => 'left', sort => 'html'                  },
      { key => 'date',    title => 'Last updated', width => '20%', align => 'left', sort => 'numeric_hidden'        },
    );
   
    push @columns, ({ key => 'download', title => '', width => '20px', align => 'center', sort => 'none' });
 
    if ($logins && $species_defs->SAVE_UPLOADED_DATA ne '0') {
      push @columns, (
        { key => 'save',  title => '', width => '22px', align => 'center', sort => 'none' },
        { key => 'share', title => '', width => '20px', align => 'center', sort => 'none' }
      );
    }
    
    push @columns, ({ key => 'delete', title => '', width => '20px', align => 'center', sort => 'none' });
    
    foreach my $file (@data) {
      my $user_record = ref($file) =~ /Record/;
      my $sharers     = $file->{'code'} =~ /_$session_id$/ ? EnsEMBL::Web::Data::Session->count(code => $file->{'code'}, type => $file->{'type'}) : 0;
         $sharers-- if $sharers && !$file->{'user_id'}; # Take one off for the original user
      
      if ($file->{'filename'} && !EnsEMBL::Web::TmpFile::Text->new(filename => $file->{'filename'}, $file->{'prefix'} ? (prefix => $file->{'prefix'}) : (), extension => $file->{'extension'})->exists) {
        $file->{'name'} .= ' (File could not be found)';
        $not_found++;
      }
      
      my $row = ref($file) =~ /DAS/ ? $self->table_row_das($file, $user_record) : $self->table_row($file, $sharers);
      
      my ($type, $id) = $file->{'analyses'} =~ /^(session|user)_(\d+)_/;
         ($id, $type) = (($file->{'code'} =~ /_(\d+)$/), 'session') unless $type;
      
      if (                                                              # This is a shared record (belonging to another user) if:
        !($user_record && $user && $file->created_by == $user->id) && ( # it's not a user record which was created by this user             AND  (stops $shared being true for the same user id with multiple session ids)
          ($type eq 'session' && $id != $session->session_id) ||        # it's a session record where the id doesn't match this session id  OR
          ($type eq 'user'    && $user && $id != $user->id)   ||        # it's a user record where the id doesn't match this user id        OR
          ($type eq 'user'    && !$user)                                # it's a user record where there is no logged in user
        )
      ) {
        delete $row->{$_} for qw(save share); # Remove controls if the data does not belong to the current user
      }
      
      push @rows, $row;
    }
    
    $html = $self->new_table(\@columns, \@rows, { data_table => 'no_col_toggle', exportable => 0, class => 'fixed editable' })->render;
  }
  
#  $html  .= $self->group_shared_data; # DOESN'T WORK YET
  $html  .= $self->_warning('File not found', sprintf('The file%s marked not found %s unavailable. Please try again later.', $not_found == 1 ? ('', 'is') : ('s', 'are')), '100%') if $not_found;
  $html ||= '<p class="space-below">You have no custom data.</p>';
  $html  .= '<div class="modal_reload"></div>' if $hub->param('reload');
  
  return qq{
    <div class="notes">
      <h4>Help</h4>
      <p class="space-below">You can rename your uploads and attached URLs by clicking on their current name in the Source column</p><br />
      <p class="space-below"><a href="/info/website/upload/index.html" class="popup">Help on supported formats, display types, etc</a></p>
    </div>
    <h2 class="legend">Your data</h2>
    $html
  };
  
  # GROUP SHARING DOESN'T WORK YET
  #return sprintf('
  #  <div class="notes"><h4>%s</h4>%s</div>
  #  <h2 class="legend">Your data</h2>
  #', scalar @temp_data && $user && $user->find_administratable_groups ?
  #  ( 'Sharing with groups', '<p>Please note that you cannot share temporary data with a group until you save it to your account.</p>' ) :
  #  ( 'Help',                '<p class="space-below"><a href="/info/website/upload/index.html" class="popup">Help on supported formats, display types, etc</a></p>' )
  #) . $html;
}

sub table_row {
  my ($self, $file, $sharers) = @_;
  my $hub          = $self->hub;
  my $img_url      = $self->img_url.'16/';
  my $delete_class = $sharers ? 'modal_confirm' : 'modal_link';
  my $title        = $sharers ? ' title="This data is shared with other users"' : '';
  my $delete       = sprintf '<a href="%%s" class="%s"%s><img src="%strash.png" alt="delete" title="Delete" /></a>', $delete_class, $title, $img_url;
  my $download;
  if ($file->{'prefix'} && $file->{'prefix'} eq 'download') {
    my $format       = $file->{'format'} eq 'report' ? 'txt' : $file->{'format'};
    $download     = sprintf '<a href="/%s/download?file=%s;prefix=download;format=%s"><img src="%sdownload.png" alt="download" title="Download" /></a>', $hub->species, $file->{'filename'}, $format, $img_url;
  }
  my $share        = qq{<a href="%s" class="modal_link"><img src="${img_url}share.png" alt="share" title="Share" /></a>};
  my $user_record  = ref($file) =~ /Record/;
  my $name         = qq{<div><strong class="val" title="Click here to rename your data">$file->{'name'}</strong>};
  my %url_params   = ( __clear => 1, source => $file->{'url'} ? 'url' : 'upload' );
  my $save;
  
  if ($user_record) {
    $url_params{'id'} = $file->id;
    
    $save = qq{<img src="${img_url}dis/save.png" alt="saved" title="Saved data" />};
  } else {
    my $save_html = qq{<a href="%s" class="modal_link"><img src="${img_url}save.png" alt="save" title="%s" /></a>};
    my $save_url  = $hub->url({ action => 'ModifyData', function => $file->{'url'} ? 'save_remote' : 'save_upload', code => $file->{'code'}, __clear => 1 });
    
    $url_params{'code'} = $file->{'code'};
    
    $save = sprintf $save_html, $hub->user ? ($save_url, 'Save to account') : ($hub->url({ type => 'Account', action => 'Login', __clear => 1, then => uri_escape($save_url), modal_tab => 'modal_user_data' }), 'Log in to save');
  }
  
  $name .= sprintf(
    '<input type="text" maxlength="255" name="record_name" /><a href="%s" class="save"></a></div>',
    $hub->url({
      action   => 'ModifyData',
      function => $user_record ? 'rename_user_record' : 'rename_session_record',
      %url_params
    })
  );
  
  if ($file->{'nearest'}) {
    $name .= sprintf(
      '<a href="%s;contigviewbottom=%s">View sample location</a><br />',
      $hub->url({
        species  => $file->{'species'},
        type     => 'Location',
        action   => 'View',
        function => undef,
        r        => $file->{'nearest'},
        __clear  => 1
      }),
      join ',', map $_ ? "$_=on" : (), $file->{'analyses'} ? split ', ', $file->{'analyses'} : join '_', $user_record ? 'user' : $file->{'type'}, $file->{'code'}
    );
  }
  
  if ($file->{'format'} eq 'SNP_EFFECT' || $file->{'filetype'}) {
    my %params = $file->{'format'} eq 'SNP_EFFECT' ? (
      action       => 'ConsequenceCalculator',
      data_format  => 'snp',
      convert_file => "$file->{'filename'}:$file->{'name'}",
      code         => $file->{'code'},
    ) : $file->{'filetype'} eq 'ID History Converter' ? (
      action       => 'IDConversion',
      data_format  => 'id',
      convert_file => "upload_$file->{'code'}:$file->{'name'}",
      id_limit     => 30,
    ) : (
      action    => 'PreviewConvert',
      converted => "$file->{'filename'}:$file->{'name'}",
    );
  
    $name .= sprintf '<a href="%s" class="modal_link">View results</a><br />', $hub->url({ species => $file->{'species'}, __clear => 1, %params });
    $save  = '';
    $share = '' if $file->{'filetype'} eq 'ID History Converter';
  }
  
  $name .= $file->{'url'} || sprintf '%s file', $file->{'filetype'} || $file->{'format'};
  
  return {
    type    => $file->{'url'} ? 'URL' : 'Upload',
    name    => { value => $name, class => 'wrap editable' },
    species => sprintf('<em>%s</em>', $hub->species_defs->get_config($file->{'species'}, 'SPECIES_SCIENTIFIC_NAME')),
    date    => sprintf('<span class="hidden">%s</span>%s', $file->{'timestamp'} || '-', $self->pretty_date($file->{'timestamp'}, 'simple_datetime')),
    save    => $save,
    download => $download,
    share   => sprintf($share, $hub->url({ action => 'SelectShare', %url_params })),
    delete  => sprintf($delete, $hub->url({ action => 'ModifyData', function => $file->{'url'} ? 'delete_remote' : 'delete_upload', %url_params })),
  };
}

sub table_row_das {
  my ($self, $file, $user_record) = @_;
  my $hub     = $self->hub;
  my $img_url = $self->img_url.'16/';
  my $link    = qq{<a href="%s" class="modal_link"><img src="${img_url}%s.png" alt="%s" title="%s" /></a>};
  my (%url_params, $save);
  
  if ($user_record) {
    %url_params = ( id => $file->id );
    $save       = qq{<img src="${img_url}dis/save.png" alt="saved" title="Saved data" />};
  } else {
    my $save_url    = $hub->url({ action => 'ModifyData', function => 'save_remote', dsn => $file->logic_name, __clear => 1 });
    my @save_params = $hub->user ? ($save_url, 'Save to account') : ($hub->url({ type => 'Account', action => 'Login', __clear => 1, then => uri_escape($save_url), modal_tab => 'modal_user_data' }), 'Log in to save');
       %url_params  = ( code => $file->logic_name );
       $save        = sprintf $link, $save_params[0], 'save', 'save', $save_params[1];
  }
  
  return {
    type   => 'DAS',
    name   => { value => $file->label, class => 'wrap' },
    date   => '<span class="hidden">-</span>-',
    delete => sprintf($link, $hub->url({ action => 'ModifyData', function => 'delete_remote', source => 'das', __clear => 1, %url_params }), 'trash', 'delete', 'Delete'),
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
    $html .= $self->new_table(\@columns, \@rows, { class => 'fixed editable' })->render;
  }
  
  return $html;
}

1;
