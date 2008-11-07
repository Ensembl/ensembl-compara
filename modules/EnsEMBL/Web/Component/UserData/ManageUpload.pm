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

  ## Do any 'deletes'
  my $type = $object->param('record') || '';
  if ($type eq 'session') {
    $object->get_session->purge_tmp_data('upload');
  }
  elsif ($type eq 'user') {
    $object->delete_userdata($object->param('id'));
  }

  ## Control panel fixes
  my $dir = '/'.$ENV{'ENSEMBL_SPECIES'};
  $dir = '' if $dir !~ /_/;
  my $referer = '_referer='.$self->object->param('_referer').';x_requested_with='.$self->object->param('x_requested_with');

  my $html;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  ## Temporary upload
  $html .= "<h4>Temporary upload</h4>";

  my $temp_data = $self->object->get_session->get_tmp_data('upload');
  if ($temp_data && keys %$temp_data) {
    $html .= '<p>'.$temp_data->{'format'}.' file for '.$temp_data->{'species'}.': ';
    if ($user) {
      $html .= qq(<a href="$dir/UserData/SaveUpload?wizard_next=save_tempdata;$referer" class="modal_link">Save to account</a> | );
    }
    else {
      $html .= qq(<a href="$dir/Account/Login?$referer" class="modal_link">Log in to save</a> | );
    }
    $html .= qq(<a href="$dir/UserData/ManageUpload?record=session;$referer" class="modal_link">Delete</a></p>);
  }
  else {
    $html .= qq(<p>You have no temporary data uploaded to this website.</p>);
  }

  $html .= qq(<h4>Saved uploads</h4>);
  if ($user) {
    my @uploads = $user->uploads;

    if (@uploads) {
      $html .= "You have the following data saved in our databases:";

      my $table = EnsEMBL::Web::Document::SpreadSheet->new( [], [], {'margin' => '0 0 1em 0'} );
      $table->add_columns(
        {'key' => "name", 'title' => 'Upload name', 'width' => '60%', 'align' => 'left' },
        {'key' => "date", 'title' => 'Last updated', 'width' => '20%', 'align' => 'left' },
        {'key' => "delete", 'title' => '', 'width' => '20%', 'align' => 'left' },
      );
      foreach my $upload (@uploads) {
        my $date = $upload->modified_at || $upload->created_at;
        my $link = sprintf('<a href="%s/UserData/ManageUpload?record=user;id=%s;%s" class="modal_link">Delete</a>', $dir, $upload->id, $referer);
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
  $html .= $self->_info(
    'Adding tracks',
    qq(<p>Please note that custom data can only be added on pages that allow these tracks to be configured, for example 'Region in detail' images</p>),
    '100%',
  );


  return $html;
}

1;
