package EnsEMBL::Web::Component::UserData::ManageRemote;

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
    my @sources = $user->dases;

    if (@sources) {
      $html .= "<h4>DAS sources</h4>";

      my $table = EnsEMBL::Web::Document::SpreadSheet->new();
      $table->add_columns(
        {'key' => "name", 'title' => 'Datasource name', 'width' => '60%', 'align' => 'left' },
        {'key' => "date", 'title' => 'Last updated', 'width' => '20%', 'align' => 'left' },
        {'key' => "delete", 'title' => '', 'width' => '20%', 'align' => 'left' },
      );
      foreach my $source (@sources) {
        my $date = $source->modified_at || $source->created_at;
        my $link = sprintf('<a href="/common/UserData/DeleteDAS?id=%s">Delete</a>', $source->id);
        $table->add_row( { 'name'  => $source->label, 'date' => $self->pretty_date($date), 'delete' => $link } );
      }
      $html .= $table->render;
    }
    else {
      $html .= qq(<p class="space-below">You have no DAS source information saved in our databases.</p>);
    }
    my @urls = $user->urls;

    if (@urls) {
      $html .= "<h4>URL-based data</h4>";

      my $table = EnsEMBL::Web::Document::SpreadSheet->new();
      $table->add_columns(
        {'key' => "name", 'title' => 'Datasource name', 'width' => '60%', 'align' => 'left' },
        {'key' => "date", 'title' => 'Last updated', 'width' => '20%', 'align' => 'left' },
        {'key' => "delete", 'title' => '', 'width' => '20%', 'align' => 'left' },
      );
      foreach my $source (@urls) {
        my $date = $source->modified_at || $source->created_at;
        my $link = sprintf('<a href="/common/UserData/DeleteURL?id=%s">Delete</a>', $source->id);
        $table->add_row( { 'name'  => $source->name, 'date' => $self->pretty_date($date), 'delete' => $link } );
      }
      $html .= $table->render;
    }
    else {
      $html .= qq(<p class="space-below">You have no DAS source information saved in our databases.</p>);
    }
  }
  return $html;
}

1;
