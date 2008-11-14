package EnsEMBL::Web::Component::UserData::ManageUpload;

use strict;
use warnings;
no warnings "uninitialized";
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  ## Control panel fixes
  my $dir = '/'.$ENV{'ENSEMBL_SPECIES'};
  $dir = '' if $dir !~ /_/;
  my $referer = '_referer='.$self->object->param('_referer').';x_requested_with='.$self->object->param('x_requested_with');

  my $html;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  ## Temporary upload
  $html .= "<h3>Temporary upload</h3>";

  my @data = $self->object->get_session->get_data('type'=>'upload');

  if (@data) {
    my $table = EnsEMBL::Web::Document::SpreadSheet->new();
    $table->add_columns(
      {'key' => "name", 'title' => 'File', 'width' => '60%', 'align' => 'left' },
      {'key' => "save", 'title' => '', 'width' => '20%', 'align' => 'left' },
      {'key' => "delete", 'title' => '', 'width' => '20%', 'align' => 'left' },
    );
    foreach my $file (@data) {
      my $name = '<p>';
      $name .= '<strong>'.$file->{'name'}.'</strong><br />' if $file->{'name'};
      $name .= $file->{'format'}.' file for '.$file->{'species'};
      my $row = {'name' => $name};
      my $extra = 'type='.$file->{'type'}.';code='.$file->{'code'};
      if ($user) {
        $row->{'save'} = qq(<a href="$dir/UserData/SaveUpload?$extra;$referer" class="modal_link">Save to account</a>);
      } else {
        $row->{'save'} = qq(<a href="$dir/Account/Login?$referer" class="modal_link">Log in to save</a>);
      }
      $row->{'delete'} = qq(<a href="$dir/UserData/DeleteUpload?$extra;$referer" class="modal_link">Remove</a></p>);
      $table->add_row($row);
    }
    $html .= $table->render;
  } else {
    $html .= qq(<p class="space-below">You have no temporary data uploaded to this website.</p>);
  }

  $html .= qq(<h3>Saved uploads</h3>);
  if ($user) {
    my @uploads = $user->uploads;

    if (@uploads) {
      my $table = EnsEMBL::Web::Document::SpreadSheet->new( [], [], {'margin' => '0 0 1em 0'} );
      $table->add_columns(
        {'key' => "name", 'title' => 'Upload name', 'width' => '60%', 'align' => 'left' },
        {'key' => "date", 'title' => 'Last updated', 'width' => '20%', 'align' => 'left' },
        {'key' => "delete", 'title' => '', 'width' => '20%', 'align' => 'left' },
      );
      foreach my $upload (@uploads) {
        my $date = $upload->modified_at || $upload->created_at;
        my $link = sprintf('<a href="%s/UserData/DeleteUpload?type=user;id=%s;%s" class="modal_link">Delete</a>', $dir, $upload->id, $referer);
        $table->add_row( { 'name'  => $upload->name, 'date' => $self->pretty_date($date), 'delete' => $link } );
      }
      $html .= $table->render;
    }
    else {
      $html .= qq(<p class="space-below">You have no data saved in our databases.</p>);
    }
  }
  else {
    $html .= qq(<p>Log in to see your saved uploads.</p>);
  }
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
