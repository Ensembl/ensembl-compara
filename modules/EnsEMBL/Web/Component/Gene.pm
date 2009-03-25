package EnsEMBL::Web::Component::Gene;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Component::Slice;
use EnsEMBL::Web::RegObj;

use EnsEMBL::Web::Form;

use Data::Dumper;
use Bio::AlignIO;
use IO::String;
use CGI qw(escapeHTML);

use base qw(EnsEMBL::Web::Component);
our %do_not_copy = map {$_,1} qw(species type view db transcript gene);

=pod

sub user_notes {
  my( $panel, $object ) = @_;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $uri  = CGI::escape($ENV{'REQUEST_URI'});
  my $html;
  my $stable_id = $object->stable_id;
  my @annotations = $user->annotations;
  if ($#annotations > -1) {
    $html .= "<ul>";
    foreach my $annotation (sort { $a->created_at cmp $b->created_at } @annotations) {
      warn "CREATED AT: " . $annotation->created_at;
      if ($annotation->stable_id eq $stable_id) {
        $html .= "<li>";
        $html .= "<b>" . $annotation->title . "</b><br />";
        $html .= $annotation->annotation;
        $html .= "<br /><a href='/common/user/annotation?dataview=edit;url=$uri;id=" . $annotation->id . ";stable_id=$stable_id'>Edit</a>";
        $html .= " &middot; <a href='/common/user/annotation?dataview=delete;url=$uri;id=" . $annotation->id . "'>Delete</a>";
        $html .= "</li>";
      }
    }
    $html .= "</ul>";
  }

  $html .= "<a href='/common/user/annotation?url=" . $uri . ";stable_id=" . $stable_id . "'>Add new note</a>";

  $panel->add_row('Your notes', $html);

}

sub group_notes {
  my( $panel, $object ) = @_;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @groups = $user->groups;
  my $uri = CGI::escape($ENV{'REQUEST_URI'});
  my $stable_id = $object->stable_id;
  my $html;
  my $found = 0;
  my %included_annotations = ();
  foreach my $annotation ($user->annotations) {
    if ($annotation->stable_id eq $stable_id) {
      $included_annotations{$annotation->id} = "yes";
    }
  }
  foreach my $group (@groups) {
    my $title_added = 0;
    my $group_annotations = 0;
    my @annotations = $group->annotations;
    foreach my $annotation (@annotations) {
      if ($annotation->stable_id eq $stable_id) {
        $group_annotations = 1;
      }
    }
    if ($group_annotations) {
      if (!$title_added) {
        $html .= "<h4>" . $group->name . "</h4>";
        $title_added = 1;
      }
      $html .= "<ul>";
      foreach my $annotation (sort { $a->created_at cmp $b->created_at } @annotations) {
        if (!$included_annotations{$annotation->id}) {
          $found = 1;
          $html .= "<li>";
          $html .= "<b>" . $annotation->title . "</b><br />";
          $html .= $annotation->annotation;
          $html .= "</li>";
          $included_annotations{$annotation->id} = "yes";
        }
      }
      $html .= "</ul>";
    }
  }
  if ($found) {
    $panel->add_row('Group notes', $html);
  }
}

=cut

sub email_URL {
    my $email = shift;
    return qq(&lt;<a href='mailto:$email'>$email</a>&gt;) if $email;
}

sub EC_URL {
  my( $self,$string ) = @_;
  my $URL_string= $string;
  $URL_string=~s/-/\?/g;
  return $self->object->get_ExtURL_link( "EC $string", 'EC_PATHWAY', $URL_string );
}

sub content_export {
  my $self = shift;
  my $object = $self->object;
  
  return $self->_export(undef, $object->get_all_transcripts, $object->stable_id);
}

1;
