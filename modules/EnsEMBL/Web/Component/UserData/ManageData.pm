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
  my $self    = shift;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $logins  = $hub->species_defs->ENSEMBL_LOGINS;
  my $user    = $hub->user;
  my $sd      = $hub->species_defs;
  my $enabled_save_uploaded_data = defined($hub->species_defs->SAVE_UPLOADED_DATA) ? $hub->species_defs->SAVE_UPLOADED_DATA : 1;  
  my @data; 
  
  # Control panel fixes
  my $dir = $hub->species_path;
  $dir = '' if $dir !~ /_/;
  
  my $html;
  $html .= '<div class="modal_reload"></div>' if $hub->param('reload');
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
    if ($user->bams) {
      push @data, $user->bams;
      $saved_data = 1;
    }
    if ($user->dases) {
      push @data, $user->dases;
      $saved_data = 1;
    } 
  }
  my @tmp;
  if (@tmp = $session->get_data('type' => 'upload')) {
    push @data, @tmp;
    $temp_data = 1;
  }
  if (@tmp = $session->get_data('type' => 'url')) {
    push @data, @tmp;
    $temp_data = 1;
  }
  if (@tmp = $session->get_data('type' => 'bam')) {
    push @data, @tmp;
    $temp_data = 1;
  }
  if (@tmp = values %{$session->get_all_das}) {
    push @data, @tmp;
    $temp_data = 1;
  }

  if (@data) {
    my $table = $self->new_table;
    
    $table->add_columns(
      { 'key' => 'type', 'title' => 'Type', 'width' => '10%', 'align' => 'left' },
      { 'key' => 'name', 'title' => 'File', 'width' => '30%', 'align' => 'left' }
    );
    
    if ($logins) {
      $table->add_columns({ 'key' => 'date', 'title' => 'Last updated', 'width' => '15%', 'align' => 'left' },
                          { 'key' => 'rename', 'title' => '', 'width' => '15%', 'align' => 'left' });
      if($enabled_save_uploaded_data){
        $table->add_columns({ 'key' => 'save', 'title' => '', 'width' => '15%', 'align' => 'left' });
      }
    }
    
    $table->add_columns(
      { 'key' => 'share', 'title' => '', 'width' => '15%', 'align' => 'left' },
      { 'key' => 'delete', 'title' => '', 'width' => '15%', 'align' => 'left' }
    );
    
    my $not_found = 0;
     
    foreach my $file (@data) { 
      # EnsembleGenomes sites share session and user account - only count data that is attached to species in current site
      next unless $hub->species_defs->valid_species(ref ($file) =~ /Record/ ? $file->species : $file->{species}); 
      
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
          $name = '<strong>'.$file->{'name'}.'</strong>';
          if ($file->{'nearest'}) {
            $name .= ' [<a href="/'.$file->{'species'}.'/Location/View?r='.$file->{'nearest'}
                        .'" title="Jump to sample region with data">view location</a>]';
          }
          $name .= '<br />'.$file->format." file for <em>$species</em>";
          $date = $file->modified_at || $file->created_at;
          $date = $self->pretty_date($date, 'simple_datetime');
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
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?type=url;id=%s" class="%s">Delete</a>', $dir, $file->id, $delete_class);
        } elsif (ref ($file) =~ /BAM/) {
          $type = 'BAM';
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
          $rename = sprintf('<a href="%s/UserData/RenameRecord?accessor=bams;id=%s" class="%s">Rename</a>', $dir, $file->id, $delete_class);
          $share = sprintf('<a href="%s/UserData/SelectShare?id=%s" class="modal_link">Share</a>', $dir, $file->id);
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?type=bam;id=%s" class="%s">Delete</a>', $dir, $file->id, $delete_class);
        }
        
        if ($logins) {
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
          
          if ($logins && $user) {
            $save = sprintf('<a href="%s/UserData/SaveRemote?dsn=%s" class="modal_link">Save to account</a>', $dir, $file->logic_name);
          }
          
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?logic_name=%s" class="modal_link">Delete</a>', $dir, $file->logic_name);
        } elsif ($file->{type} =~ /^bam$/) {
          $type = 'BAM';
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
          $rename = sprintf('<a href="%s/UserData/RenameTempData?type=bam;code=%s" class="%s"%s>Rename</a>', $dir, $file->{'code'}, $delete_class, $title);
          $share = sprintf('<a href="%s/UserData/SelectShare?code=%s;species=%s" class="modal_link">Share</a>', $dir, $file->{'code'}, $file->{'species'});

          $delete = sprintf('<a href="%s/UserData/DeleteRemote?type=bam;code=%s" class="%s">Delete</a>', $dir, $file->{'code'}, $delete_class);
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
          
          if ($logins && $user) {
            $save = sprintf('<a href="%s/UserData/SaveRemote?code=%s;species=%s" class="modal_link">Save to account</a>', $dir, $file->{'code'}, $file->{'species'});
          }
          $rename = sprintf('<a href="%s/UserData/RenameTempData?type=url;code=%s" class="%s"%s>Rename</a>', $dir, $file->{'code'}, $delete_class, $title);
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
          $date = $self->pretty_date($file->{'timestamp'}, 'simple_datetime');
          my $extra = "type=$file->{'type'};code=$file->{'code'}"; 
          
          if ($file->{'format'} && $file->{'format'} eq "ID" ) { 
            $save = '';
          }
          elsif ($file->{'format'} && $file->{'format'} eq 'SNP_EFFECT') {
            $save = sprintf '<a href="%s" class="modal_link">View results</a>', '/'.$file->{'species'}.'/UserData/PreviewConvertIDs?format=text;data_format=snp;species='.$file->{'species'}.';convert_file='.$file->{'filename'}.':'.$file->{'name'};
          } 
          else {
            $save = qq{<a href="$dir/UserData/SaveUpload?$extra" class="modal_link">Save to account</a>} if ($logins && $user);
          }
          $share = sprintf('<a href="%s/UserData/SelectShare?%s" class="modal_link">Share</a>', $dir, $extra);
          $rename = sprintf('<a href="%s/UserData/RenameTempData?code=%s" class="%s"%s>Rename</a>', $dir, $file->{'code'}, $delete_class, $title);
          $delete = qq{<a href="$dir/UserData/DeleteUpload?$extra" class="$delete_class"$title>Delete</a></p>};
          
          # Remove save and delete links if the data does not belong to the current user
          if ($file->{'analyses'} =~ /^(session|user)_(\d+)_/) {
            my $type = $1;
            my $id = $2;
            
            if (($type eq 'session' && $id != $session->session_id)   || 
                ($type eq 'user' && $logins && $user && $id != $user->id) ||
                ($type eq 'user' && !($logins && $user))) {
                $save = '';
                $delete = '';
                $share = '';
                $rename = '';
            }
          }
        }
        
        if ($logins) {
          $row = { 'type' => $type, 'name' => $name, 'delete' => $delete, 'date' => $date, 'share' => $share, 'rename' => $rename, 'save' => $save };
        } else {
          $row = { 'type' => $type, 'name' => $name, 'delete' => $delete, 'date' => $date, 'share' => $share, 'rename' => $rename };
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
