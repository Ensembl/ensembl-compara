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
    @movies = sort {$a->title cmp $b->title} EnsEMBL::Web::Data::Movie->search({'status' => 'live'});
  }

  if (scalar(@movies) == 1 && $movies[0]) {
    my $movie = $movies[0];
    $html .= embed_movie($movie);

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

sub embed_movie {
  my $movie = shift;

  ## Check if we're just passing an ID from other code
  unless (ref($movie) eq 'EnsEMBL::Web::Data::Movie') {
    my @results = EnsEMBL::Web::Data::Movie->search({'help_record_id' => $movie, 'status' => 'live'});
    $movie = $results[0];
    return undef unless $movie && ref($movie) eq 'EnsEMBL::Web::Data::Movie';
  }

  my $html = '<h3>'.$movie->title."</h3>";

  $html .= sprintf(qq(
<object width="425" height="344"><param name="movie" value="http://www.youtube.com/v/%s&amp;hl=en&amp;fs=1"></param><param name="allowFullScreen" value="true"></param><param name="allowscriptaccess" value="always"></param><embed src="http://www.youtube.com/v/%s&amp;hl=en&amp;fs=1" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true" width="425" height="344"></embed></object>
    ), $movie->youtube_id, $movie->youtube_id);


  return $html;
}

1;
