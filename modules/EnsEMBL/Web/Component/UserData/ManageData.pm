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
  
  my $not_found = 0;
  
  # Extra check if file exists, if not - delete the record
  foreach my $file (@data) {    
    if ($file->{'filename'} && !EnsEMBL::Web::TmpFile::Text->new(filename => $file->{'filename'})->exists) {
      $file->{'name'} .= ' (File could not be found)';
      $not_found++;
    }
  }
  
  push @data, $user->uploads if $user;
  push @data, values %{$object->get_session->get_all_das};
  push @data, $user->dases if $user;
  push @data, $object->get_session->get_data(type => 'url');
  push @data, $user->urls if $user;

  if (@data) {
    my $table = EnsEMBL::Web::Document::SpreadSheet->new;
    
    $table->add_columns(
      { 'key' => 'type', 'title' => 'Type', 'width' => '10%', 'align' => 'left' },
      { 'key' => 'name', 'title' => 'File', 'width' => '45%', 'align' => 'left' }
    );
    
    if ($sd->ENSEMBL_LOGINS) {
      $table->add_columns(
        { 'key' => 'date', 'title' => 'Last updated', 'width' => '15%', 'align' => 'left' },
        { 'key' => 'save', 'title' => '', 'width' => '15%', 'align' => 'left' }
      );
    }
    
    $table->add_columns(
      { 'key' => 'delete', 'title' => '', 'width' => '15%', 'align' => 'left' }
    );
    
    foreach my $file (@data) {
      my $row;
      my $sharers = $object->get_session->get_sharers($file);
      my $delete_class = $sharers ? 'modal_confirm' : 'modal_link';
      my $title = sprintf(' title="This data is shared with %d user%s"', $sharers, $sharers > 1 ? 's' : '') if $sharers;
      
      # from user account
      if (ref $file =~ /Record/) {
        my ($type, $name, $date, $delete);
        
        if (ref $file =~ /Upload/) {
          $type = 'Upload';
          $name = $file->name;
          $date = $file->modified_at || $file->created_at;
          $date = $self->pretty_date($date);
          $delete = sprintf('<a href="%s/UserData/DeleteUpload?type=user;id=%s;%s" class="$delete_class"$title>Delete</a>', $dir, $file->id, $referer);
        } elsif (ref $file =~ /DAS/) {
          $type = 'DAS';
          $name = $file->label;
          $date = '-';
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?type=das;id=%s;%s" class="modal_link">Delete</a>', $dir, $file->id, $referer);
        } elsif (ref $file =~ /URL/) {
          $type = 'URL';
          $name = $file->name;
          $date = '-';
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?id=%s;%s" class="modal_link">Delete</a>', $dir, $file->id, $referer);
        }
        
        if ($sd->ENSEMBL_LOGINS) {
          $row = { 'type' => $type, 'name' => $name, 'delete' => $delete, 'date' => $date, 'save' => 'Saved' };
        } else {
          $row = { 'type' => $type, 'name' => $name, 'delete' => $delete };
        }
      } else {
        my $save = sprintf('<a href="%s/Account/Login?%s" class="modal_link">Log in to save</a>', $dir, $referer);
        my ($type, $name, $delete);
        
        if (ref $file =~ /DASConfig/i) {
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
          
          if ($sd->ENSEMBL_LOGINS && $user) {
            $save = qq(<a href="$dir/UserData/SaveUpload?$extra;$referer" class="modal_link">Save to account</a>);
          }
          
          $delete = qq(<a href="$dir/UserData/DeleteUpload?$extra;$referer" class="$delete_class"$title>Remove</a></p>);
        }
        
        if ($file->{'analyses'}) {
          $file->{'analyses'} =~ /^session_(\d+)_/;
          $delete = '' if $1 != $object->get_session->get_session_id; # It's not your data, so you aren't allowed to delete it.
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
