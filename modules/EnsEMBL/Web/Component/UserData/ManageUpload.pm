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

  my $html;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user) {
    my @uploads = $user->uploads;

    if (@uploads) {
      $html .= "You have the following data saved in our databases:";

      my $table = EnsEMBL::Web::Document::SpreadSheet->new();
      $table->add_columns(
        {'key' => "name", 'title' => 'Upload name', 'width' => '60%', 'align' => 'left' },
        {'key' => "date", 'title' => 'Last updated', 'width' => '20%', 'align' => 'left' },
        {'key' => "delete", 'title' => '', 'width' => '20%', 'align' => 'left' },
      );
      foreach my $upload (@uploads) {
        my $date = $upload->modified_at || $upload->created_at;
        my $link = sprintf('<a href="/common/UserData/DeleteUpload?id=%s">Delete</a>', $upload->id);
        $table->add_row( { 'name'  => $upload->name, 'date' => $self->pretty_date($date), 'delete' => $link } );
      }
      $html .= $table->render;
    }
    else {
      $html .= qq(<p class="space-below">You have no data saved in our databases.</p>);
    }
  }
  return $html;
}

1;
