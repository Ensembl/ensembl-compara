# $Id$

package EnsEMBL::Web::Component::Help;

use base qw( EnsEMBL::Web::Component);
use strict;

sub embed_movie {
  my ($self, $movie) = @_;

  my ($embed, $channel, $logo, $alt);
  if ($self->requesting_country eq 'CN') {  ## Select YouKu (if possible) for visitors within China
    $channel  = 'http://u.youku.com/Ensemblhelpdesk';
    $alt      = 'Youku &#20248;&#37239;&#32593; channel';
    if ($movie->{'youku_id'}) {
      $embed    = sprintf('<embed src="http://player.youku.com/player.php/sid/%s/v.swf" allowFullScreen="true" quality="high" width="640" height="480" align="middle" allowScriptAccess="always" type="application/x-shockwave-flash"></embed>', $movie->{'youku_id'});
      $logo     = $self->hub->species_defs->ENSEMBL_STATIC_SERVER.'/img/youku.png';
    }
    else {
      return sprintf '<p>Sorry, this tutorial has not yet been added to our <a href="%s">%s</a>', $channel, $alt;
    }
  }
  else {
    $embed    = sprintf('<iframe width="640" height="480" src="http://www.youtube-nocookie.com/embed/%s" frameborder="0" allowfullscreen="allowfullscreen" style="margin:0 auto"></iframe>', $movie->{'youtube_id'});
    $channel  = '"http://www.youtube.com/user/EnsemblHelpdesk';
    $logo     = $self->hub->species_defs->ENSEMBL_STATIC_SERVER.'/img/youtube.png';
    $alt      = 'YouTube channel';
  }

  return sprintf '
    <h3>%s</h3>
    <p>%s</p>
    <p><a href="%s"><img alt="%s" src="%s" /></a></p>',
    $movie->{'title'}, $embed, $channel, $alt, $logo;
}

sub parse_help_html {
  ## Parses help content looking for embedded movie and images placeholders
  my ($self, $content, $adaptor) = @_;

  my $sd      = $self->hub->species_defs;
  my $img_url = $sd->ENSEMBL_STATIC_SERVER.$sd->ENSEMBL_HELP_IMAGE_ROOT;
  my $html;

  foreach my $line (split '\n', $content) {

    if ($line =~ /\[\[movie=(\d+)/i) {
      $line = $self->embed_movie(@{$adaptor->fetch_help_by_ids([$1]) || []});
    }

    while ($line =~ /\[\[image=([^\s]+)\s*([^\]]+)?\s*\]\]/ig) {
      substr $line, $-[0], $+[0] - $-[0], qq(<img src="$img_url$1" alt="" $2 \/>); # replace square bracket tag with actual image
    }

    $html .= $line;
  }

  return $html;
}

sub help_feedback {
  my ($self, $id, %args) = @_;
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
