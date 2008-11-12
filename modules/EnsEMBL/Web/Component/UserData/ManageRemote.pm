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
  my $object = $self->object;

  ## Control panel fixes
  my $dir = '/'.$ENV{'ENSEMBL_SPECIES'};
  $dir = '' if $dir !~ /_/;
  my $referer = '_referer='.$self->object->param('_referer').';x_requested_with='.$self->object->param('x_requested_with');

  my $html;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $save = sprintf('<a href="%s/Account/Login?%s" class="modal_link">Log in to save</a>', $dir, $referer);

  ## List DAS sources
  $html .= "<h3>DAS sources</h3>";

  my @sources = values %{$self->object->get_session->get_all_das};

  if ($user) {
    push @sources, $user->dases;
  }

  if (@sources) {

    my $table = EnsEMBL::Web::Document::SpreadSheet->new();
    $table->add_columns(
      {'key' => "name", 'title' => 'Datasource name', 'width' => '50%', 'align' => 'left' },
      {'key' => "date", 'title' => 'Last updated', 'width' => '20%', 'align' => 'left' },
      {'key' => "save", 'title' => '', 'width' => '15%', 'align' => 'left' },
      {'key' => "delete", 'title' => '', 'width' => '15%', 'align' => 'left' },
    );
    
    foreach my $source (sort { lc $a->label cmp lc $b->label } @sources) {

      if (ref($source) =~ /Record/) { ## from user account
        my $date = $source->modified_at || $source->created_at;
        my $link = sprintf('<a href="%s/UserData/DeleteRemote?id=%s;%s" class="modal_link">Delete</a>', $dir, $source->id, $referer);
        $table->add_row( { 'name'  => $source->label, 'date' => $self->pretty_date($date), 'save' => 'Saved', 'delete' => $link } );
      }
      else { ## temporary
        if ($user) {
          $save = sprintf('<a href="%s/UserData/SaveRemote?wizard_next=save_tempdas;dsn=%s;%s" class="modal_link">Save to account</a>', $dir, $source->logic_name, $referer);
        }
        my $detach = sprintf('<a href="%s/UserData/DeleteRemote?logic_name=%s;%s" class="modal_link">Remove</a>', $dir, $source->logic_name, $referer);
        $table->add_row( { 'name'  => $source->label, 'date' => 'N/A', 'save' => $save, 'delete' => $detach } );
      }

    }
    $html .= $table->render;
  }
  else {
    $html .= qq(<p class="space-below">You have no DAS sources attached.</p>);
  }

  ## List URL data
  $html .= "<h3>URL-based data</h3>";

  my @urls = $self->object->get_session->get_data(type => 'url');

  push @urls, $user->urls
    if $user;

  if (@urls) {
    my $table = EnsEMBL::Web::Document::SpreadSheet->new( [], [], {'margin' => '0 0 1em 0'} );
    $table->add_columns(
      {'key' => "url", 'title' => 'Datasource URL', 'width' => '50%', 'align' => 'left' },
      {'key' => "date", 'title' => 'Last updated', 'width' => '20%', 'align' => 'left' },
      {'key' => "save", 'title' => '', 'width' => '15%', 'align' => 'left' },
      {'key' => "delete", 'title' => '', 'width' => '15%', 'align' => 'left' },
    );
    foreach my $source (@urls) {
      if (ref($source) =~ /Record/) { ## from user account
        my $date = $source->modified_at || $source->created_at;
        my $link = sprintf('<a href="%s/UserData/DeleteRemote?id=%s;%s" class="modal_link">Delete</a>', $dir, $source->id, $referer);
        $table->add_row( { 'url'  => $source->url.' ('.$source->species.')', 'date' => $self->pretty_date($date), 'save' => 'Saved', 'delete' => $link } );
      }
      else { ## temporary
        if ($user) {
          $save = sprintf('<a href="%s/UserData/SaveRemote?wizard_next=save_tempdas;code=%s;species=%s;%s" class="modal_link">Save to account</a>', $dir, $source->{'code'}, $source->{'species'}, $referer);
        }
        my $detach = sprintf('<a href="%s/UserData/DeleteRemote?type=url;code=%s;%s" class="modal_link">Remove</a>', $dir, $source->{'code'}, $referer);
        $table->add_row( { 'url'  => $source->{'url'}.' ('.$source->{'species'}.')', 'date' => 'N/A', 'save' => $save, 'delete' => $detach } );
      }
    }
    $html .= $table->render;
  }
  else {
    $html .= qq(<p class="space-below">You have no URL data attached.</p>);
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
