package EnsEMBL::Web::Component::Help::Movie;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Data::Movie;
use EnsEMBL::Web::Document::HTML::MovieList;
use EnsEMBL::Web::Document::SpreadSheet;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $html;
  my $referer = '_referer='.$object->param('_referer').';x_requested_with='.$object->param('x_requested_with');

  my @movies;
  my @ids = $object->param('id') || $object->param('feedback');
  if (scalar(@ids) && $ids[0]) {
    foreach my $id (@ids) {
      push @movies, EnsEMBL::Web::Data::Movie->new($id);
    }
  }
  else {
    @movies = sort {$a->title cmp $b->title} EnsEMBL::Web::Data::Movie->find_all;
  }

  if (scalar(@movies) == 1 && $movies[0]) {
    my $movie = $movies[0];
    $html .= '<h3>'.$movie->title."</h3>";

    ## Embedded flash movie
    my $file = $movie->filename;
    $file =~ s/\.swf$//;
    my $movie_server = ''; # $object->species_defs->ENSEMBL_MOVIE_SERVER;
    my $path = $movie_server.'/flash/'.$file;
    $html .= sprintf(qq(
<embed type="application/x-shockwave-flash" src="%s_controller.swf" width="%s" height="%s" id="%s_controller.swf" name="%s_controller.swf" bgcolor="#FFFFFF" quality="best" flashvars="csConfigFile=%s_config.xml&csColor=FFFFFF&csPreloader=%s_preload.swf"/>

      ),
                $path, $movie->width, $movie->height, $file, $path, $path, $path);

    ## Feedback
    my $style = 'text-align:right;margin-right:2em';
    if ($object->param('feedback')) {
      $html .= qq(<p style="$style">Thank you for your feedback.</p>);
    }
    else {
      ## Feedback form
      $html .= $self->help_feedback($style, $movie->id, return_url => '/Help/Movie', type => 'Movie',
          '_referer' => $object->param('_referer'),
          'x_requested_with' => $object->param('x_requested_with'));

      ## Link to movie-specific feedback form
      my $title = $movie->title;
      my $extra = '_referer='.$object->param('_referer').';x_requested_with='.$object->param('x_requested_with');
      $html .= qq(<div class="info-box" style="float:right;width:50%;padding:10px;margin:5px">If you have problems viewing this movie, we would be grateful if you could <a href="/Help/MovieFeedback?title=$title;$extra" class="modal_link">provide feedback</a> that will help us improve our service. Thank you.</div>);
    }
  }
  elsif (scalar(@movies) > 0 && $movies[0]) {

    $html .= EnsEMBL::Web::Document::HTML::MovieList::render();

  }
  else {
    $html .= qq(<p>Sorry, we have no video tutorials at the moment, as they are being updated for the new site design. Please try again after the next release.</p>);
  }

  return $html;
}

1;
