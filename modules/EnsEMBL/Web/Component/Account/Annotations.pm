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
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0px'} );

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

      $row->{'gene'} = sprintf(qq(<a href="/Gene/Summary?g=%s" class="cp-external">%s</a>),
                        $note->stable_id, $note->stable_id);

      $row->{'title'}   = $note->title;
      $row->{'edit'}    = $self->edit_link('Annotation', $note->id);
      if ($has_groups) {
        $row->{'share'}   = $self->share_link('Bookmark', $note->id);
      }
      $row->{'delete'}  = $self->delete_link('Annotation', $note->id);
      $table->add_row($row);
      $has_notes = 1;
    }
    $html .= $table->render;
  }

 ## Get all note records for this user's subscribed groups
  my %group_notes = ();
  foreach my $group ($user->groups) {
    foreach my $note ($group->annotations) {
      next if $note->created_by == $user->id;
      if ($group_notes{$note->id}) {
        push @{$group_notes{$note->id}{'groups'}}, $group;
      }
      else {
        $group_notes{$note->id}{'note'} = $note;
        $group_notes{$note->id}{'groups'} = [$group];
        $has_notes = 1;
      }
    }
  }

  if (scalar values %group_notes > 0) {
    $html .= qq(<h3>Group notes</h3>);
    ## Sort group notes by name if required

    ## Display group notes
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '0px'} );

    $table->add_columns(
        { 'key' => 'name',      'title' => 'Name',          'width' => '20%', 'align' => 'left' },
        { 'key' => 'title',     'title' => 'Title',         'width' => '40%', 'align' => 'left' },
        { 'key' => 'group',     'title' => 'Group(s)',      'width' => '40%', 'align' => 'left' },
    );

    foreach my $note_id (keys %group_notes) {
      my $row = {};
      my $note = $group_notes{$note_id}{'note'};

      $row->{'name'} = sprintf(qq(<a href="/Gene/Summary?g=%s" class="cp-external">%s</a>),
                        $note->stable_id, $note->stable_id);

      $row->{'title'} = $note->title || '&nbsp;';

      my @group_links;
      foreach my $group (@{$group_notes{$note_id}{'groups'}}) {
        push @group_links, 
          sprintf(qq(<a href="/Account/MemberGroups?id=%s;_referer=%s" class="modal_link">%s</a>), 
            $group->id, CGI::escape($self->object->param('_referer')), $group->name);
      }
      $row->{'group'} = join(', ', @group_links);
      $table->add_row($row);
    }
    $html .= $table->render;
  }

  if (!$has_notes) {
    $html .= qq(<p class="center"><img src="/img/help/note_example.gif" alt="Sample screenshot" title="SAMPLE" /></p>);
  }

  return $html;
}

1;
