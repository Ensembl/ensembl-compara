package EnsEMBL::Web::Component::Account::Annotations;

### Module to create user gene annotation list

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return undef;
}

sub content {
  my $self = shift;
  my $html;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $sitename = $self->site_name;

  my @notes = $user->annotations;
  my $has_notes = 0;

  my @groups = $user->find_administratable_groups;
  my $has_groups = $#groups > -1 ? 1 : 0;

  if ($#notes > -1) {

    $html .= qq(<h3>Your annotations</h3>);
    ## Sort user notes by name if required

    ## Display user notes
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );

    $table->add_columns(
        { 'key' => 'gene',      'title' => 'Gene ID',       'width' => '20%', 'align' => 'left' },
        { 'key' => 'title',     'title' => 'Title',         'width' => '50%', 'align' => 'left' },
        { 'key' => 'edit',      'title' => '',              'width' => '10%', 'align' => 'left' },
    );
    if ($has_groups) {
      $table->add_columns(
        { 'key' => 'share',     'title' => '',              'width' => '10%', 'align' => 'left' },
      );
    }
    $table->add_columns(
        { 'key' => 'delete',    'title' => '',              'width' => '10%', 'align' => 'left' },
    );

    foreach my $note (@notes) {
      my $row = {};

      $row->{'gene'} = sprintf(qq(<a href="/Gene/Summary?g=%s">%s</a>),
                        $note->stable_id, $note->stable_id);

      $row->{'title'}   = $note->title;
      $row->{'edit'}    = $self->edit_link('Annotation', $note->id);
      if ($has_groups) {
        $row->{'share'}   = $self->share_link('Bookmark', $bookmark->id);
      }
      $row->{'delete'}  = $self->delete_link('Annotation', $note->id);
      $table->add_row($row);
      $has_notes = 1;
    }
    $html .= $table->render;
  }


  if (!$has_notes) {
    $html .= qq(<p class="center"><img src="/img/help/note_example.gif" alt="Sample screenshot" title="SAMPLE" /></p>);
    $html .= qq(<p class="center">You haven't saved any $sitename notes. <a href='/info/about/custom.html#notes'>Learn more about notes &rarr;</a>);
  }

  return $html;
}

1;
