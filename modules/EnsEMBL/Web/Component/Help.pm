package EnsEMBL::Web::Component::Help;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;
use Image::Size;

our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
no warnings "uninitialized";

use constant 'HELPVIEW_IMAGE_DIR'   => "/img/help";

sub _wrap_form {
  my ( $panel, $object, $node ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form($node)->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}

sub hv_intro      { _wrap_form($_[0], $_[1], 'hv_intro'); }
sub hv_contact    { _wrap_form($_[0], $_[1], 'hv_contact'); }

sub hv_multi {
  my($panel,$object) = @_;
  my $kw = $object->param('search');
  my ($list_type, %scores);

  if ($object->species_defs->ENSEMBL_MODULAR_HELP) {
    $list_type = 'dl';
    ## convert scores back into hash
    my @articles = split('_', $object->param('results'));
    foreach my $article (@articles) {
      my @bits = split('-', $article);
      $scores{$bits[0]} = $bits[1];
    }
  }
  else {
    $list_type = 'ul';
  }

  my %param = (
    'hilite' => $object->param('hilite'),
    'search' => $kw,
  );

  $panel->print(qq(
  <p>Your search for "$kw" is found in the following entries:</p>
  <$list_type>));

  foreach( @{$object->results}) {
    $param{'kw'} = $_->{'keyword'};
    if ($object->species_defs->ENSEMBL_MODULAR_HELP) {
      $panel->printf( qq(\n    <dt><a href="%s">%s</a></dt><dd>%s</dd>), $object->_help_URL(\%param), $_->{'title'}, $_->{'summary'});
    }
    else {
      $panel->printf( qq(\n    <li><a href="%s">%s</a></li>), $object->_help_URL(\%param), $_->{'title'});
    }
  } 
  $panel->print(qq(\n</$list_type>));
  return 1;
}

sub hv_single {
  my($panel,$object) = @_;
  my $article = $object->results->[0];
  my $hilite = $object->param('hilite');

  my $title = $$article{'title'};
  if ($hilite) {
    $title = _kw_hilite($object, $title);
  }
  my $html = "<h2>$title</h2>";

  my ($text, $header, $group);
  if ($object->species_defs->ENSEMBL_MODULAR_HELP) {
    if ($$article{'intro'}) {
      $text = $$article{'intro'};
      if ($hilite) {
        $text   = _kw_hilite($object, $text);
      }
      $text = _link_mapping($object, $text);
      $html .= qq(<h4>Introduction</h4>);
      $html .= $text;
    }
    ## do individual chunks
    if ($$article{'items'} && scalar(@{$$article{'items'}}) > 0) {
      my @items = @{$$article{'items'}};
      foreach my $item (@items) {
        $header = $$item{'header'};
        $group  = $$item{'group_intro'};
        $text   = $$item{'content'};
        if ($hilite) {
          $header = _kw_hilite($object, $header);
          $text   = _kw_hilite($object, $text);
        }
        (my $anchor = $header) =~ s/ /_/g;
        if ($group eq 'Y') {
          $html .= qq(<h3 class="boxed" id="$anchor">$header</h3>\n);
        }
        else {
          $html .= qq(<h4>$header</h4>\n);
        }
        $text = _link_mapping($object, $text);
        $html .= qq($text\n\n);
      }
    }
  }
  else {
    $text = $$article{'content'};
    if ($hilite) {
      $text   = _kw_hilite($object, $text);
    }
    $text = _link_mapping($object, $text);
    $html .= "\n$text\n\n";
  }
  $panel->print($html);
  return 1;
}

sub _link_mapping {
  my ($object, $content) = @_;

  ## internal (Ensembl) links
  $content =~ s/HELP_(.*?)_HELP/$object->_help_URL({'kw'=>"$1"})/mseg;

  ## images
  my $replace = HELPVIEW_IMAGE_DIR;
  $content =~ s/IMG_(.*?)_IMG/$replace\/$1/mg;

  return $content;
}

sub _kw_hilite {
  my ($object, $content) = @_;
  my $kw = $object->param('search') || $object->param('kw');

  $content =~ s/($kw)(?!(\w|\s|[-\.\/;:#\?"])*>)/<span class="hilite">$1<\/span>/img;
  return $content;
}


sub hv_thanks {
  my($panel,$object) = @_;
  my $sitetype = ucfirst(lc($object->species_defs->ENSEMBL_SITETYPE)) || 'Ensembl';
  $panel->print(qq(
<p>Your message was successfully sent to the $sitetype Site Helpdesk Administration Team. They will get back to you in due course.</p>
<p>Helpdesk</p>));
  return 1;
}

sub glossary {
  my($panel,$object) = @_;
  my $glossary = $object->glossary;

  my $html = "<dl>";
  foreach my $entry (@$glossary) {     
    my $word    = $$entry{'word'};
    (my $anchor = $word) =~ s/ /_/g;
    my $acronym = $$entry{'acronym'};
    my $meaning = $$entry{'meaning'};
    $html .= qq(<dt id="$anchor">$word</dt>\n<dd>);
    $html .= "<strong>$acronym</strong><br />" if $acronym;
    $html .= qq($meaning</dd>\n);
  }
  $html .= "</dl>\n\n";

  $panel->print($html);
  return 1;
}

sub movie_index_intro {
  my($panel,$object) = @_;

  my $html = qq(
<p>The tutorials listed below are Flash animations of some of our training presentations, with added popup notes in place of a soundtrack. We are gradually adding to the list, so please check back regularly (the list will also be included in the bimonthly Release Email, which is sent to the <a href="/info/about/contact.html">ensembl-announce mailing list</a>).</p>
  );

  $panel->print($html);
  return 1;
}

sub movie_index {
  my($panel,$object) = @_;
  my $movie_list = $object->movie_list;

  if (ref($movie_list) eq 'ARRAY' && @$movie_list) {
    $panel->add_columns( 
      {'key' => "title", 'title' => 'Title', 'width' => '60%', 'align' => 'left' },
      {'key' => "mins", 'title' => 'Running time (minutes)', 'width' => '20%', 'align' => 'left' },
      {'key' => "size", 'title' => 'File size', 'width' => '20%', 'align' => 'left' },
    );
    foreach my $entry (@$movie_list) {     
      my $id    = $$entry{'movie_id'};
      my $title = $$entry{'title'};
      my $size  = $$entry{'filesize'};
      my $time  = $$entry{'frame_count'} / ($$entry{'frame_rate'} * 60);
      my $mins  = int($time);
      my $secs  = int(($time - $mins) * 60);
      $panel->add_row({
        'title' => qq(<a href="/common/Workshops_Online?movie=$id">$title</a>),
        'mins'  => "$mins:$secs",
        'size'  => "$size GB",
      });
    }
  }
  return 1;
}

sub movie_intro {
  my($panel,$object) = @_;

  my $html = qq(<p>Click on the 'Play' button below the image to start the tutorial. You can also click on the progress bar to skip forwards and backwards.</p>
  );

  $panel->print($html);
  return 1;
}

sub embed_movie {
  my($panel,$object) = @_;
  my $movie = $object->movie;

  ## we hard-code this so that mirror sites don't have to keep downloading
  ## dozens of megabytes of Flash movies :)
  my $path = 'http://www.ensembl.org/flash/'; ## CHANGE TO 'www.ensembl.org' ONCE FILES ARE ON THE WEB NODES!
  my $uri  = $path.$movie->{'filename'};

  my $html = qq(<div class="flash"><object type="application/x-shockwave-flash" id="movie" data="$uri" width="750" height="500">
<param name="movie" value="$uri" /> 
<param name="wmode" value="transparent" />
</object></div>);

  $panel->print($html);
  return 1;
}

sub control_movie {
  my ( $panel, $object ) = @_;
  my $label = '';
  my $html = qq(
   <div>
     @{[ $panel->form( 'control_movie' )->render() ]}
  </div>);

  $panel->print($html);
  return 1;
}

sub control_movie_form {

  my( $panel, $object ) = @_;
  my $script = $object->script;
  my $movie = $object->movie;
  my $frame_count = $movie->{'frame_count'};
  my $frame_rate  = $movie->{'frame_rate'};

  my $form = EnsEMBL::Web::Form->new( 'control_movie', "/common/$script", 'get' );
  my $controls = "'control_movie_1', 'control_movie_2', 'control_movie_4', 'control_movie_14'";
  my $progress = "'control_movie_1', 'control_movie_5', 'control_movie_6', 'control_movie_7', 'control_movie_8', 'control_movie_9', 'control_movie_10', 'control_movie_11', 'control_movie_12', 'control_movie_13'";

  $form->add_element(
    'type'     => 'Button',
    'on_click' => "hiliteButton('control_movie_1', $controls);PlayMovie($frame_count);",
    'name'     => 'Play',
    'value'    => 'Play',
    'spanning' => 'inline',
  );
  $form->add_element(
    'type'     => 'Button',
    'on_click' => "hiliteButton('control_movie_2', $controls);StopMovie();",
    'name'     => 'Stop',
    'value'    => 'Stop',
    'spanning' => 'inline',
  );
  $form->add_element(
      'type'      => 'StaticImage',
      'name'      => 'spacer',
      'src'       => '/img/blank.gif',
      'alt'       => ' ',
      'width'     => 100,
      'height'    => 25,
      'spanning'  => 'inline',
    );
  $form->add_element(
    'type'     => 'Button',
    'on_click' => "hiliteButton('control_movie_4', $progress);RewindMovie();",
    'name'     => 'Rewind',
    'value'    => '|<<',
    'spanning' => 'inline',
  );
  for (my $i=1; $i<10; $i++) {
    my $tenth = int(($frame_count / 10) * $i);
    $form->add_element(
      'type'     => 'Button',
      'on_click' => "SkipToFrame($tenth);",
      'name'     => "Skip$i",
      'value'    => '  ',
      'spanning' => 'inline',
    );
  }
  $form->add_element(
    'type'     => 'Button',
    'on_click' => "hiliteButton('control_movie_14', $progress);EndOfMovie();",
    'name'     => 'End',
    'value'    => '>>|',
    'spanning' => 'inline',
  );
  $form->add_element(
      'type'      => 'StaticImage',
      'name'      => 'spacer',
      'src'       => '/img/blank.gif',
      'alt'       => ' ',
      'width'     => 100,
      'height'    => 25,
      'spanning'  => 'inline',
    );
  $form->add_element(
    'type'     => 'Button',
    'on_click' => 'ZoominMovie()',
    'name'     => 'Zoomin',
    'value'    => 'Zoom In',
    'spanning' => 'inline',
  );
  $form->add_element(
    'type'     => 'Button',
    'on_click' => 'ZoomoutMovie()',
    'name'     => 'Zoomout',
    'value'    => 'Zoom Out',
    'spanning' => 'inline',
  );
  return $form;
}


#-----------------------------------------------------------------
# DB EDITOR WIZARD COMPONENTS
#-----------------------------------------------------------------

sub select    { _wrap_form($_[0], $_[1], 'select'); }
sub enter     { _wrap_form($_[0], $_[1], 'enter'); }
sub preview   { _wrap_form($_[0], $_[1], 'preview'); }

sub _wrap_form {
  my ( $panel, $object, $node ) = @_;
  my $html = qq(<div class="formpanel" style="width:80%">);
  $html .= $panel->form($node)->render();
  $html .= '</div>';
  $panel->print($html);
  return 1;
}


1;
