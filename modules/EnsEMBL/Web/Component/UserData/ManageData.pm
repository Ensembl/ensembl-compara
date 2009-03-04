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
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $sd = $object->species_defs;
  
  ## Control panel fixes
  my $dir = '/'.$ENV{'ENSEMBL_SPECIES'};
  $dir = '' if $dir !~ /_/;
  my $r = Apache2::RequestUtil->request();

  my $referer = '_referer='.$self->object->param('_referer').';x_requested_with='.
     ( $self->object->param('x_requested_with')||$r->headers_in->{'X-Requested-With'} );

  my $html;
  if( $self->object->param('reload') ) {
    $html .= '<div id="modal_reload">.</div>';
  }
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  ## Uploads
  $html .= "<h3>Your data</h3>";

  my @data = $self->object->get_session->get_data(type => 'upload');
  ## Extra check if file exists, if not - delete the record
  foreach my $file (@data) {
    $self->object->get_session->purge_data($file)
      unless EnsEMBL::Web::TmpFile::Text->new(filename => $file->{'filename'})->exists;
  }
  
  push @data, $user->uploads if $user;
  push @data, values %{$self->object->get_session->get_all_das};
  push @data, $user->dases if $user;
  push @data, $self->object->get_session->get_data(type => 'url');
  push @data, $user->urls if $user;

  if (@data) {
    my $table = EnsEMBL::Web::Document::SpreadSheet->new();
    $table->add_columns(
      {'key' => "type",   'title' => 'Type',          'width' => '10%', 'align' => 'left' },
      {'key' => "name",   'title' => 'File',          'width' => '45%', 'align' => 'left' },
    );
    if ($sd->ENSEMBL_LOGINS) {
      $table->add_columns(
        {'key' => "date",   'title' => 'Last updated',  'width' => '15%', 'align' => 'left' },
        {'key' => "save",   'title' => '',              'width' => '15%', 'align' => 'left' },
      );
    }
    $table->add_columns(
      {'key' => "delete", 'title' => '',              'width' => '15%', 'align' => 'left' },
    );
    foreach my $file (@data) {
      my $row;
      if (ref($file) =~ /Record/) { ## from user account
        my ($type, $name, $date, $delete);
        if (ref($file) =~ /Upload/) {
          $type = 'Upload';
          $name = $file->name;
          $date = $file->modified_at || $file->created_at;
          $date = $self->pretty_date($date);
          $delete = sprintf('<a href="%s/UserData/DeleteUpload?type=user;id=%s;%s" class="modal_link">Delete</a>', $dir, $file->id, $referer);
        }
        elsif (ref($file) =~ /DAS/) {
          $type = 'DAS';
          $name = $file->label;
          $date = '-';
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?type=das;id=%s;%s" class="modal_link">Delete</a>', $dir, $file->id, $referer);
        }
        elsif (ref($file) =~ /URL/) {
          $type = 'URL';
          $name = $file->name;
          $date = '-';
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?id=%s;%s" class="modal_link">Delete</a>', $dir, $file->id, $referer);
        }
        if ($sd->ENSEMBL_LOGINS) {
          $row = {'type' => $type, 'name' => $name, 'date' => $date, 'save' => 'Saved', 'delete' => $delete };
        }
        else {
          $row = {'type' => $type, 'name' => $name, 'delete' => $delete };
        }
      }
      else {
        my $save = sprintf('<a href="%s/Account/Login?%s" class="modal_link">Log in to save</a>', $dir, $referer);
        my ($type, $name, $delete);
        if (ref($file) =~ /DASConfig/i) {
          $type = 'DAS';
          $name = $file->label;
          if ($sd->ENSEMBL_LOGINS && $user) {
            $save = sprintf('<a href="%s/UserData/SaveRemote?wizard_next=save_tempdas;dsn=%s;%s" class="modal_link">Save to account</a>', $dir, $file->logic_name, $referer);
          }
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?logic_name=%s;%s" class="modal_link">Remove</a>', $dir, $file->logic_name, $referer);
  
        }
        elsif ($file->{'url'}) {
          $type = 'URL';
          $name = '<strong>'.$file->{'name'}.'</strong><br />' if $file->{'name'};
          $name .= $file->{'url'}.' ('.$file->{'species'}.')';
          if ($sd->ENSEMBL_LOGINS && $user) {
            $save = sprintf('<a href="%s/UserData/SaveRemote?wizard_next=save_tempdas;code=%s;species=%s;%s" class="modal_link">Save to account</a>', $dir, $file->{'code'}, $file->{'species'}, $referer);
          }
          $delete = sprintf('<a href="%s/UserData/DeleteRemote?type=url;code=%s;%s" class="modal_link">Remove</a>', $dir, $file->{'code'}, $referer);
        }
        else {
          $type = 'Upload';
          $name = '<p>';
          $name .= '<strong>'.$file->{'name'}.'</strong><br />' if $file->{'name'};
          $name .= $file->{'format'}.' file for '.$file->{'species'};
          my $extra = 'type='.$file->{'type'}.';code='.$file->{'code'};
          if ($sd->ENSEMBL_LOGINS && $user) {
            $save = qq(<a href="$dir/UserData/SaveUpload?$extra;$referer" class="modal_link">Save to account</a>);
          }
          $delete = qq(<a href="$dir/UserData/DeleteUpload?$extra;$referer" class="modal_link">Remove</a></p>);
        }
        if ($sd->ENSEMBL_LOGINS) {
          $row = {'type' => $type, 'name' => $name, 'date' => '-', 'save' => $save, 'delete' => $delete };
        }
        else {
          $row = {'type' => $type, 'name' => $name, 'delete' => $delete };
        }
      }
      $table->add_row($row);
    }
    $html .= $table->render;  
  } 
  else {
    $html .= qq(<p class="space-below">You have no custom data.</p>);
  }

## URL

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
