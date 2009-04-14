package EnsEMBL::Web::Component::UserData::ManageData;

use strict;
use warnings;
no warnings "uninitialized";
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Component::UserData);
use Apache2::RequestUtil;

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $sd = $object->species_defs;
    
  my $r = Apache2::RequestUtil->request;
  my $referer = '_referer=' . $object->param('_referer') . ';x_requested_with=' . ($object->param('x_requested_with') || $r->headers_in->{'X-Requested-With'});
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @data = $object->get_session->get_data(type => 'upload');
  
  # Control panel fixes
  my $dir = '/'.$ENV{'ENSEMBL_SPECIES'};
  $dir = '' if $dir !~ /_/;
  
  my $html;
  $html .= '<div id="modal_reload">.</div>' if $object->param('reload');
  $html .= '<h3>Your data</h3>'; # Uploads
  
  push @data, $user->uploads if $user;
  push @data, values %{$object->get_session->get_all_das};
  push @data, $user->dases if $user;
  push @data, $object->get_session->get_data(type => 'url');
  push @data, $user->urls if $user;

  if (@data) {
    my $table = EnsEMBL::Web::Document::SpreadSheet->new;
    
    $table->add_columns(
      { 'key' => 'type', 'title' => 'Type', 'width' => '10%', 'align' => 'left' },
      { 'key' => 'name', 'title' => 'File', 'width' => '30%', 'align' => 'left' }
    );
    
    if ($sd->ENSEMBL_LOGINS) {
      $table->add_columns(
        { 'key' => 'date', 'title' => 'Last updated', 'width' => '15%', 'align' => 'left' },
        { 'key' => 'save', 'title' => '', 'width' => '15%', 'align' => 'left' },
        { 'key' => 'rename', 'title' => '', 'width' => '15%', 'align' => 'left' },
      );
    }
    
    $table->add_columns(
      { 'key' => 'delete', 'title' => '', 'width' => '15%', 'align' => 'left' }
    );
    
    my $not_found = 0;
     
    foreach my $file (@data) { 
      if ($file->{'filename'} && !EnsEMBL::Web::TmpFile::Text->new(filename => $file->{'filename'})->exists) {
        $file->{'name'} .= ' (File could not be found)';
        $not_found++;
      }
    
      my $row;
      
      my $sharers = EnsEMBL::Web::Data::Session->count(code => $file->{'code'}, type => $file->{'type'});
      $sharers-- unless $file->{'user_id'}; # Take one off for the original user
      
      my $delete_class = $sharers ? 'modal_confirm' : 'modal_link';
      my $title = ' title="This data is shared with other users"' if $sharers;
      
      # from user account
      if (ref ($file) =~ /Record/) {
        my ($type, $name, $date, $rename, $delete);
        if (ref ($file) =~ /Upload/) {
          $type = 'Upload';
          $name = $file->name;
          $date = $file->modified_at || $file->created_at;
          $date = $self->pretty_date($date);
          $rename = sprintf('<a href="%s/UserData/RenameRecord?accessor=uploads;id=%s;%s" class="%s"%s>Rename</a>', $dir, $file->id, $referer, $delete_class, $title);
          $delete = sprintf('<a href="%s/UserData/DeleteUpload?type=user;id=%s;%s" class="%s"%s>Delete</a>', $dir, $file->id, $referer, $delete_class, $title);
        } elsif (ref ($file) =~ /DAS/) {
          $type = 'DAS';
          $name = $file->label;
          $date = '-';
          $rename = sprintf('<a href="%s/UserData/RenameRecord?accessor=urls;id=%s;%s" class="modal_link">Rename</a>', $dir, $file->id, $referer);
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?type=das;id=%s;%s" class="modal_link">Delete</a>', $dir, $file->id, $referer);
        } elsif (ref ($file) =~ /URL/) {
          $type = 'URL';
          $name = $file->name;
          $date = '-';
          $rename = sprintf('<a href="%s/UserData/RenameRecord?accessor=urls;id=%s;%s" class="modal_link">Rename</a>', $dir, $file->id, $referer);
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?id=%s;%s" class="modal_link">Delete</a>', $dir, $file->id, $referer);
        }
        
        if ($sd->ENSEMBL_LOGINS) {
          $row = { 'type' => $type, 'name' => $name, 'delete' => $delete, 'date' => $date, 'rename' => $rename, 'save' => 'Saved' };
        } else {
          $row = { 'type' => $type, 'name' => $name, 'delete' => $delete };
        }
      } else {
        my $save = sprintf('<a href="%s/Account/Login?%s" class="modal_link">Log in to save</a>', $dir, $referer);
        my ($type, $name, $delete);
        
        if (ref ($file) =~ /DASConfig/i) {
          $type = 'DAS';
          $name = $file->label;
          
          if ($sd->ENSEMBL_LOGINS && $user) {
            $save = sprintf('<a href="%s/UserData/SaveRemote?dsn=%s;%s" class="modal_link">Save to account</a>', $dir, $file->logic_name, $referer);
          }
          
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?logic_name=%s;%s" class="modal_link">Remove</a>', $dir, $file->logic_name, $referer);
        } elsif ($file->{'url'}) {
          $type = 'URL';
          $name = "<strong>$file->{'name'}</strong><br />" if $file->{'name'};
          $name .= "$file->{'url'} ($file->{'species'})";
          
          if ($sd->ENSEMBL_LOGINS && $user) {
            $save = sprintf('<a href="%s/UserData/SaveRemote?code=%s;species=%s;%s" class="modal_link">Save to account</a>', $dir, $file->{'code'}, $file->{'species'}, $referer);
          }
          
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?type=url;code=%s;%s" class="modal_link">Remove</a>', $dir, $file->{'code'}, $referer);
        } else {
          $type = 'Upload';
          $name = '<p>';
          $name .= "<strong>$file->{'name'}</strong><br />" if $file->{'name'};
          $name .= "$file->{'format'} file for $file->{'species'}";
          my $extra = "type=$file->{'type'};code=$file->{'code'}"; 
          
          $save = qq{<a href="$dir/UserData/SaveUpload?$extra;$referer" class="modal_link">Save to account</a>} if ($sd->ENSEMBL_LOGINS && $user);
          $delete = qq{<a href="$dir/UserData/DeleteUpload?$extra;$referer" class="$delete_class"$title>Remove</a></p>};
          
          # Remove save and delete links if the data does not belong to the current user
          if ($file->{'analyses'} =~ /^(session|user)_(\d+)_/) {
            my $type = $1;
            my $id = $2;
            
            if (($type eq 'session' && $id != $object->get_session->get_session_id)   || 
                ($type eq 'user' && $sd->ENSEMBL_LOGINS && $user && $id != $user->id) ||
                ($type eq 'user' && !($sd->ENSEMBL_LOGINS && $user))) {
                $save = '';
                $delete = '';
            }
          }
        }
        
        if ($sd->ENSEMBL_LOGINS) {
          $row = { 'type' => $type, 'name' => $name, 'delete' => $delete, 'date' => '-', 'save' => $save };
        } else {
          $row = { 'type' => $type, 'name' => $name, 'delete' => $delete };
        }
      }
      
      $table->add_row($row);
    }
    
    $html .= $table->render;
    
    if ($not_found) {
      my ($s, $are);
      
      if ($not_found == 1) {
        $are = 'is';
      } else {
        $s = 's';
        $are = 'are';
      }
      
      $html .= $self->_warning('File not found', "The file$s marked not found $are unavailable. Please try again later.", '100%');
    }
  } else {
    $html .= qq(<p class="space-below">You have no custom data.</p>);
  }

  # URL
  unless ($self->is_configurable) {
    $html .= $self->_info(
      'Adding tracks',
      qq(<p>Please note that custom data can only be added on pages that allow these tracks to be configured, for example 'Region in detail' images</p>),
      '100%',
    );
  }

  return $html;
}

1;
