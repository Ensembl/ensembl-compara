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
    <div><iframe width="640" height="480" src="http://www.youtube-nocookie.com/embed/%s" frameborder="0" allowfullscreen="allowfullscreen" style="margin:0 auto"></iframe></div>
    <p><a href="http://www.youtube.com/user/EnsemblHelpdesk"><img alt="" src="%s/img/youtube.png" /></a></p>',
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


1;
