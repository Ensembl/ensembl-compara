package EnsEMBL::Web::Component::Help;

use base qw( EnsEMBL::Web::Component);
use strict;
use warnings;

use constant 'HELPVIEW_IMAGE_DIR'   => "/img/help";

sub kw_hilite {
  ### Highlights the search keyword(s) in the text, omitting HTML tag contents
  my ($self, $content) = @_;
  my $kw = $self->hub->param('string');
  return $content unless $kw;

  $content =~ s/($kw)(?![^<]*?>)/<span class="hilite">$1<\/span>/img;
  return $content;
}

sub embed_movie {
## FACTORED OUT SO CAN BE USED BY MULTIPLE HELP MODULES
  my ($self, $movie) = @_;

  my $html = sprintf '<h3>%s</h3>
      <object width="425" height="344">
        <param name="movie" value="http://www.youtube.com/v/%s&amp;hl=en&amp;fs=1"></param>
        <param name="allowFullScreen" value="true"></param>
        <param name="allowscriptaccess" value="always"></param>        <embed src="http://www.youtube.com/v/%s&amp;hl=en&amp;fs=1" type="application/x-shockwave-flash" allowscriptacce
ss="always" allowfullscreen="true" width="425" height="344"></embed>
      </object>
      <table>
        <tr>          <td><a href="http://www.youtube.com/user/EnsemblHelpdesk"><img src="/img/youtube.png" style="float:left;paddin
g:20px 0px;" /></a></td>
          <td>',
      $movie->{'title'}, $movie->{'youtube_id'}, $movie->{'youtube_id'};

  return $html;
}


1;
