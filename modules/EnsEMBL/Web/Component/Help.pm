# $Id$

package EnsEMBL::Web::Component::Help;

use base qw( EnsEMBL::Web::Component);
use strict;

sub kw_hilite {
  ### Highlights the search keyword(s) in the text, omitting HTML tag contents
  my ($self, $content) = @_;
  my $kw = $self->hub->param('string');
  return $content unless $kw;

  $content =~ s/($kw)(?![^<]*?>)/<span class="hilite">$1<\/span>/img;
  return $content;
}

sub embed_movie {
  my ($self, $movie) = @_;

  return sprintf '
    <h3>%s</h3>
    <p class="space-below"><iframe width="640" height="480" src="http://www.youtube-nocookie.com/embed/%s" frameborder="0" allowfullscreen="allowfullscreen" style="margin:0 auto"></iframe></p>
    <p class="space-below"><a href="http://www.youtube.com/user/EnsemblHelpdesk"><img alt="" src="%s/img/youtube.png" /></a></p>',
    $movie->{'title'}, $movie->{'youtube_id'}, $self->hub->species_defs->ENSEMBL_STATIC_SERVER;
}

sub parse_help_html {
  my ($self, $content, $adaptor) = @_;

  my $html;

  ### Parse help looking for embedded movie placeholders
  foreach my $line (split('\n', $content)) {
    if ($line =~ /\[\[movie=(\d+)/i) {
      $line = $self->embed_movie(@{$adaptor->fetch_help_by_ids([$1]) || []});
    }

    $html .= $line;
  }

  return $html;
}

sub help_feedback {
  my ($self, $style, $id, %args) = @_;
  return ''; ## FIXME - this needs to be reenabled when we have time
  
  my $html = qq{
    <div style="text-align:right;margin-right:2em;">
      <form id="help_feedback_$id" class="std check _check" action="/Help/Feedback" method="get">
        <strong>Was this helpful?</strong>
        <input type="radio" class="autosubmit" name="help_feedback" value="yes" /><label>Yes</label>
        <input type="radio" class="autosubmit" name="help_feedback" value="no" /><label>No</label>
        <input type="hidden" name="record_id" value="$id" />
  };
  
  while (my ($k, $v) = each (%args)) {
    $html .= qq{
        <input type="hidden" name="$k" value="$v" />};
  }
  
  $html .= '
      </form>
    </div>';
  
  return $html;
}

1;
