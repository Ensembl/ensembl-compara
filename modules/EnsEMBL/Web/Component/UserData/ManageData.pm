# $Id$

package EnsEMBL::Web::Component::UserData::ManageData;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Data::Session;
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $sd = $object->species_defs;

  my $user = $object->user;
  my @data; 
  
  # Control panel fixes
  my $dir = $object->species_path;
  $dir = '' if $dir !~ /_/;
  
  my $html;
  $html .= '<div class="modal_reload"></div>' if $object->param('reload');
  $html .= '<h3>Your data</h3>'; # Uploads
 
  my ($saved_data, $temp_data);
  if ($user) { 
    if ($user->uploads) {
      push @data, $user->uploads;
      $saved_data = 1;
    }
    if ($user->urls) {
      push @data, $user->urls;
      $saved_data = 1;
    }
    if ($user->dases) {
      push @data, $user->dases;
      $saved_data = 1;
    } 
  }
  my @tmp;
  if (@tmp = $object->get_session->get_data('type' => 'upload')) {
    push @data, @tmp;
    $temp_data = 1;
  }
  if (@tmp = $object->get_session->get_data('type' => 'url')) {
    push @data, @tmp;
    $temp_data = 1;
  }
  if (@tmp = values %{$object->get_session->get_all_das}) {
    push @data, @tmp;
    $temp_data = 1;
  }

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
      { 'key' => 'share', 'title' => '', 'width' => '15%', 'align' => 'left' },
      { 'key' => 'delete', 'title' => '', 'width' => '15%', 'align' => 'left' }
    );
    
    my $not_found = 0;
     
    foreach my $file (@data) { 
      if ($file->{'filename'} && !EnsEMBL::Web::TmpFile::Text->new(filename => $file->{'filename'}, extension => $file->{'extension'})->exists) {
        $file->{'name'} .= ' (File could not be found)';
        $not_found++;
      }
      my $row;
      
      my $sharers = EnsEMBL::Web::Data::Session->count(code => $file->{'code'}, type => $file->{'type'});
      $sharers-- unless $file->{'user_id'}; # Take one off for the original user
      
      my $delete_class = $sharers ? 'modal_confirm' : 'modal_link';
      my $title = ' title="This data is shared with other users"' if $sharers;
      my ($type, $name, $species, $date, $rename, $share, $delete);
      
      ## FROM USER ACCOUNT -------------------------------------------------------------
      if (ref ($file) =~ /Record/) {
        ($species = $file->species) =~ s/_/&nbsp;/;
        if (ref ($file) =~ /Upload/) {
          $type = 'Upload';
          $name = '<strong>';
          if ($file->{'nearest'}) {
            $name .= '<a href="/'.$file->{'species'}.'/Location/View?r='.$file->{'nearest'}
                        .'" title="Jump to sample region with data">'.$file->{'name'}.'</a>';
          }
          else {
            $name .= $file->{'name'};
          }
          $name .= '</strong><br />'.$file->format." file for <em>$species</em>";
          $date = $file->modified_at || $file->created_at;
          $date = $self->pretty_date($date);
          $rename = sprintf('<a href="%s/UserData/RenameRecord?accessor=uploads;id=%s" class="%s"%s>Rename</a>', $dir, $file->id, $delete_class, $title);
          $share = sprintf('<a href="%s/UserData/SelectShare?id=%s" class="modal_link">Share</a>', $dir, $file->id);
          $delete = sprintf('<a href="%s/UserData/DeleteUpload?type=user;id=%s" class="%s"%s>Delete</a>', $dir, $file->id, $delete_class, $title);
        } elsif (ref ($file) =~ /DAS/) {
          $type = 'DAS';
          $name = $file->label;
          $date = '-';
          $share = ''; ## No point in sharing DAS?
          $rename = ''; #sprintf('<a href="%s/UserData/RenameRecord?accessor=urls;id=%s" class="modal_link">Rename</a>', $dir, $file->id);
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?type=das;id=%s" class="modal_link">Delete</a>', $dir, $file->id);
        } elsif (ref ($file) =~ /URL/) {
          $type = 'URL';
          $name = '<strong>';
          if ($file->{'nearest'}) {
            $name .= '<a href="/'.$file->{'species'}.'/Location/View?r='.$file->{'nearest'}
                        .'" title="Jump to sample region with data">'.$file->{'name'}.'</a>';
          }
          else {
            $name .= $file->{'name'};
          }
          $name .= '</strong><br />'.$file->url." (<em>$species</em>)";
          $date = '-';
          $rename = sprintf('<a href="%s/UserData/RenameRecord?accessor=urls;id=%s" class="%s">Rename</a>', $dir, $file->id, $delete_class);
          $share = sprintf('<a href="%s/UserData/SelectShare?id=%s" class="modal_link">Share</a>', $dir, $file->id);
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?id=%s" class="%s">Delete</a>', $dir, $file->id, $delete_class);
        }
        
        if ($sd->ENSEMBL_LOGINS) {
          $row = { 'type' => $type, 'name' => $name, 'delete' => $delete, 'date' => $date, 'rename' => $rename, 'share' => $share, 'save' => 'Saved' };
        } else {
          $row = { 'type' => $type, 'name' => $name, 'delete' => $delete, 'share' => $share };
        }
      } else {
      ## TEMP DATA STORED IN SESSION --------------------------------------------
        my $save = sprintf('<a href="%s/Account/Login" class="modal_link">Log in to save</a>', $dir);
        ($species = $file->{'species'}) =~ s/_/&nbsp;/;
        
        if (ref ($file) =~ /DASConfig/i) {
          $type = 'DAS';
          $name = $file->label;
          
          if ($sd->ENSEMBL_LOGINS && $user) {
            $save = sprintf('<a href="%s/UserData/SaveRemote?dsn=%s" class="modal_link">Save to account</a>', $dir, $file->logic_name);
          }
          
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?logic_name=%s" class="modal_link">Delete</a>', $dir, $file->logic_name);
        } elsif ($file->{'url'}) {
          $type = 'URL';
          $name = '<strong>';
          if ($file->{'nearest'}) {
            $name .= '<a href="/'.$file->{'species'}.'/Location/View?r='.$file->{'nearest'}
                        .'" title="Jump to sample region with data">'.$file->{'name'}.'</a>';
          }
          else {
            $name .= $file->{'name'};
          }
          $name .= "</strong><br />$file->{'url'} (<em>$species</em>)";
          
          if ($sd->ENSEMBL_LOGINS && $user) {
            $save = sprintf('<a href="%s/UserData/SaveRemote?code=%s;species=%s" class="modal_link">Save to account</a>', $dir, $file->{'code'}, $file->{'species'});
          }
          $rename = sprintf('<a href="%s/UserData/RenameTempData?code=%s" class="%s"%s>Rename</a>', $dir, $file->{'code'}, $delete_class, $title);
          $share = sprintf('<a href="%s/UserData/SelectShare?code=%s;species=%s" class="modal_link">Share</a>', $dir, $file->{'code'}, $file->{'species'});
          
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?type=url;code=%s" class="%s">Delete</a>', $dir, $file->{'code'}, $delete_class);
        } else {
          $type = 'Upload';
          $name = '<strong>';
          if ($file->{'nearest'}) {
            $name .= '<a href="/'.$file->{'species'}.'/Location/View?r='.$file->{'nearest'}
                        .'" title="Jump to sample region with data">'.$file->{'name'}.'</a>';
          }
          else {
            $name .= $file->{'name'};
          }
          $name .= "</strong><br />$file->{'format'} file for <em>$species</em>";
          my $extra = "type=$file->{'type'};code=$file->{'code'}"; 
          
          if ($file->{'format'} && ( $file->{'format'} eq "ID" || $file->{'format'} eq "CONSEQUENCE") ) { 
            $save = '';
          } else {
            $save = qq{<a href="$dir/UserData/SaveUpload?$extra" class="modal_link">Save to account</a>} if ($sd->ENSEMBL_LOGINS && $user);
          }
          $share = sprintf('<a href="%s/UserData/SelectShare?%s" class="modal_link">Share</a>', $dir, $extra);
          $rename = sprintf('<a href="%s/UserData/RenameTempData?code=%s" class="%s"%s>Rename</a>', $dir, $file->{'code'}, $delete_class, $title);
          $delete = qq{<a href="$dir/UserData/DeleteUpload?$extra" class="$delete_class"$title>Delete</a></p>};
          
          # Remove save and delete links if the data does not belong to the current user
          if ($file->{'analyses'} =~ /^(session|user)_(\d+)_/) {
            my $type = $1;
            my $id = $2;
            
            if (($type eq 'session' && $id != $object->get_session->get_session_id)   || 
                ($type eq 'user' && $sd->ENSEMBL_LOGINS && $user && $id != $user->id) ||
                ($type eq 'user' && !($sd->ENSEMBL_LOGINS && $user))) {
                $save = '';
                $delete = '';
                $share = '';
                $rename = '';
            }
          }
        }
        
        if ($sd->ENSEMBL_LOGINS) {
          $row = { 'type' => $type, 'name' => $name, 'delete' => $delete, 'date' => '-', 'share' => $share, 'rename' => $rename, 'save' => $save };
        } else {
          $row = { 'type' => $type, 'name' => $name, 'delete' => $delete, 'share' => $share, 'rename' => $rename };
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
  if ($temp_data && $user && $user->find_administratable_groups) {
    $html .= $self->_hint(
      'manage_user_data', 'Sharing with groups',
      qq(<p>Please note that you cannot share temporary data with a group until you save it to your account.</p>),
      '100%',
    );
  }
  else {
    $html .= $self->_hint('user_data_formats', 'Help',
      qq(<p class="space-below"><a href="/info/website/upload/index.html" class="popup">Help on supported formats, display types, etc</a></p>),
      '100%',
    );
  }

  return $html;
}


1;
