package EnsEMBL::Web::Component::Help;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Data::Article;
use EnsEMBL::Web::Data::View;
use Image::Size;
use Data::Dumper;

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

sub helpview {
  my($panel, $object) = @_;
  my ($article) = @{ $object->views };
  
  my $hilite = $object->param('hilite');

  my $title = $article->title if $article;
  if ($hilite) {
    $title = _kw_hilite($object, $title);
  }
  my $html = "<h2>$title</h2>";

  my ($text, $header, $group);
  $text = $article->content if $article;
  $text =~ s/\\'/'/g;
  if ($hilite) {
    $text   = _kw_hilite($object, $text);
  }
  $text = _link_mapping($object, $text);
  $html .= "\n$text\n\n";
  $panel->print($html);
  return 1;
}

sub helpsearch {
    my ( $panel, $object) = @_;
  my $html = qq(
  <h3>Search Tips</h3>
<p>Ensembl Help now uses MySQL full text searching. This performs a case-insensitive natural language search
on the content of the help database. This gives better results than a simple string search, with some caveats:</p>
<ul>
<li>Words shorter than 4 characters in length (eg SNP) are ignored.</li>
<li>Words that occur in more than 50% of the records are ignored.</li>
<li>Wildcards such as '%' (zero or one occurences of any character) and '_' (exactly one character) are no longer available.</li>
</ul>
<p>For more about the Ensembl Help Search, please go to the <a href="/@{[$object->species]}/helpview?kw=helpview">HelpView help page</a>.</p>
<h3>Search Ensembl Help</h3>
);
  $html .= $panel->form('helpsearch')->render();
  
  $panel->print($html);
  return 1;
}

sub helpsearch_form {
  my( $panel, $object ) = @_;

  my $form = EnsEMBL::Web::Form->new( 'helpsearch', "/common/help/results", 'get' );

  $form->add_element(
    'type'    => 'String',
    'name'    => 'kw',
    'label'   => 'Search for:',
  );

  $form->add_element(
    'type'    => 'CheckBox',
    'name'    => 'hilite',
    'label'   => 'Highlight search term(s)',
  );

  $form->add_element(
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Go',
  );

  return $form;
}

sub results {
  my($panel,$object) = @_;
  my $kw = $object->param('kw');
  my ($list_type, %scores);
  #my $modular = $object->species_defs->ENSEMBL_MODULAR_HELP;
  my $modular = 0;

  if ($modular) {
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

  $panel->print(qq(
  <p>Your search for "$kw" is found in the following entries:</p>
  <$list_type class="spaced">));

  foreach( @{$object->results}) {
    my $url = '/common/helpview?id='.$_->{'id'}.';hilite='.$object->param('hilite');
    if ($modular) {
      my $help = EnsEMBL::Web::Data::View->new({ 'id' => $_->{'id'} }); 
      $panel->printf( qq(\n    <dt><a href="%s">%s</a></dt><dd>%s</dd>), $url, $help->title, $help->summary);
    }
    else {
      my $help = EnsEMBL::Web::Data::Article->new({ 'id' => $_->{'id'} }); 
      $panel->printf( qq(\n    <li><a href="%s">%s</a></li>), $url, $help->title);
    }
  } 
  $panel->print(qq(\n</$list_type>));
  return 1;
}

sub contact { _wrap_form($_[0], $_[1], 'contact'); }

sub contact_form {
  my( $panel, $object ) = @_;

  my $form = EnsEMBL::Web::Form->new( 'contact', "/common/help/send_email", 'get' );

  if ($object->param('kw')) {
    $form->add_element(
      'type' => 'Information',
      'value' => 'Sorry, no pages were found containing the term <strong>'.$object->param('kw')
                  .qq#</strong> (or more than 50% of articles contain this term). Please 
<a href="/common/help/search">try again</a> or use the form below to contact HelpDesk:#,
    );
  }

  $form->add_element(
    'type'    => 'String',
    'name'    => 'name',
    'label'   => 'Your name:',
  );

  $form->add_element(
    'type'    => 'Email',
    'name'    => 'email',
    'label'   => 'Your email:',
  );

  $form->add_element(
    'type'    => 'String',
    'name'    => 'category',
    'label'   => 'Subject:',
  );

  $form->add_element(
    'type'    => 'Text',
    'name'    => 'comments',
    'label'   => 'Message:',
  );

  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'kw',
    'value'   => $object->param('kw'),
  );

  $form->add_element(
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Send Email',
  );

  return $form;
}

sub thanks {
  my($panel,$object) = @_;
  my $sitetype = $object->species_defs->ENSEMBL_SITETYPE;
  $panel->print(qq(
<p>Your message was sent to the $sitetype Helpdesk Team. They will get back to you in due course.</p>
<p>Helpdesk</p>));
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
  ### Highlights the search keyword(s) in the text
  my ($object, $content) = @_;
  my $kw = $object->param('search') || $object->param('kw');

  $content =~ s/($kw)(?!(\w|\s|[-\.\/;:#\?"])*>)/<span class="hilite">$1<\/span>/img;
  return $content;
}

sub glossary {
  my($panel,$object) = @_;
  my $glossary = $object->glossary;

  my $html = "<dl>";
  my @sorted = sort { lc($a->word) cmp lc($b->word) } @$glossary;
  foreach my $entry (@$glossary) {
    my $word    = $entry->word;
    my $acronym = $entry->expanded;
    my $meaning = $entry->meaning;
    (my $anchor = $word) =~ s/ /_/g;
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
<h3>Animated Tutorials</h3>

<p>The tutorials listed below are Flash animations of some of our training presentations, with added popup notes in place of a soundtrack. We are gradually adding to the list, so please check back regularly (the list will also be included in the bimonthly Release Email, which is sent to the <a href="/info/about/mailing.html">ensembl-announce mailing list</a>).</p>
<p>Please note that files are around 3MB per minute, so if you are on a dialup connection, playback may be jerky.</p>
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
    );
    foreach my $entry (@$movie_list) {     
      my $id      = $entry->id;
      my $title   = $entry->title;
      my $length  = $entry->length;
      my $link   = qq(<a href="/common/Workshops_Online?id=$id" style="font-size:115%;font-weight:bold;text-decoration:none">$title</a>);
      ## Do flagging of new and updated content 
      my $new     = $entry->created_at;
      my $updated = $entry->modified_at;
      my $time    = time() - (86400 * 50); ## 60 days, ie approximate time between releases
      if ($updated && $updated > $time) {
        $link .= ' <span class="alert">UPDATED!</span>';
      }
      elsif ($new && $new > $time) { 
        $link .= ' <span class="alert">NEW!</span>';
      }

      $panel->add_row({
        'title' => $link,
        'mins'  => $length,
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
  my $path  = 'http://www.ensembl.org/flash/'; 
  my $uri   = $path.$movie->filename;
  my $w     = $movie->width;
  my $h     = $movie->height;

  my $html = qq(<div class="flash"><object type="application/x-shockwave-flash" id="movie" data="$uri" width="$w" height="$h">
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
  my $frame_count = $movie->frame_count;
  my $frame_rate  = $movie->frame_rate;

  my $form = EnsEMBL::Web::Form->new( 'control_movie', "/common/$script", 'get' );
  my $controls = "'control_movie_1', 'control_movie_2', 'control_movie_4', 'control_movie_14'";
  my $progress = "'control_movie_1', 'control_movie_5', 'control_movie_6', 'control_movie_7', 'control_movie_8', 'control_movie_9', 'control_movie_10', 'control_movie_11', 'control_movie_12', 'control_movie_13'";

  $form->add_element(
    'type'     => 'Button',
    'onclick' => "hiliteButton('control_movie_1', $controls);PlayMovie($frame_count);",
    'name'     => 'Play',
    'value'    => 'Play',
    'layout' => 'inline',
  );
  $form->add_element(
    'type'     => 'Button',
    'onclick' => "hiliteButton('control_movie_2', $controls);StopMovie();",
    'name'     => 'Stop',
    'value'    => 'Stop',
    'layout' => 'inline',
  );
  $form->add_element(
      'type'      => 'StaticImage',
      'name'      => 'spacer',
      'src'       => '/img/blank.gif',
      'alt'       => ' ',
      'width'     => 100,
      'height'    => 25,
      'layout'  => 'inline',
    );
  $form->add_element(
    'type'     => 'Button',
    'onclick' => "hiliteButton('control_movie_4', $progress);RewindMovie();",
    'name'     => 'Rewind',
    'value'    => '|<<',
    'layout' => 'inline',
  );
  for (my $i=1; $i<10; $i++) {
    my $tenth = int(($frame_count / 10) * $i);
    $form->add_element(
      'type'     => 'Button',
      'onclick' => "SkipToFrame($tenth);",
      'name'     => "Skip$i",
      'value'    => '  ',
      'layout' => 'inline',
    );
  }
  $form->add_element(
    'type'     => 'Button',
    'onclick' => "hiliteButton('control_movie_14', $progress);EndOfMovie();",
    'name'     => 'End',
    'value'    => '>>|',
    'layout' => 'inline',
  );
  $form->add_element(
      'type'      => 'StaticImage',
      'name'      => 'spacer',
      'src'       => '/img/blank.gif',
      'alt'       => ' ',
      'width'     => 100,
      'height'    => 25,
      'layout'  => 'inline',
    );
  $form->add_element(
    'type'     => 'Button',
    'onclick' => 'ZoominMovie()',
    'name'     => 'Zoomin',
    'value'    => 'Zoom In',
    'layout' => 'inline',
  );
  $form->add_element(
    'type'     => 'Button',
    'onclick' => 'ZoomoutMovie()',
    'name'     => 'Zoomout',
    'value'    => 'Zoom Out',
    'layout' => 'inline',
  );
  return $form;
}

sub helpful {
  my ( $panel, $object ) = @_;
  my $label = '';
  my $html = qq(
   <div class="formpanel" style="width:50%">
     @{[ $panel->form( 'helpful' )->render() ]}
  </div>);

  $panel->print($html);
  return 1;
}

sub helpful_form {
  my( $panel, $object ) = @_;
  my $form = EnsEMBL::Web::Form->new( 'helpful', "/common/help_feedback", 'post' );
  $form->add_element(
    'type'    => 'RadioGroup',
    'name'    => 'helpful',
    'label'   => 'Did you find this help item useful?',
    'values'  => [{'value'=>'yes', 'name'=>'Yes', 'checked'=>'checked'}, {'value'=>'no', 'name'=>'No'}]
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'id',
    'value'   => $object->param('id'),
  );
  $form->add_element(
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Send feedback',
  );
  return $form;
}

sub help_feedback {
  my ( $panel, $object ) = @_;
  my $label = '';
  my $url = $object->param('url') || $object->species_defs->SITE_LOGO_HREF;
  my $html = qq(
<script type="text/javascript">
<!--
window.setTimeout('backToEnsembl()', 5000);

function backToEnsembl(){
  window.location = "$url"
}
//-->
</script>
<p>Thank you for taking time to rate our online help.</p>

<p>Please <a href="$url">click here</a> if you are not returned to your starting page within five seconds.</p>
);

  $panel->print($html);
  return 1;
}

sub static {
  my ( $panel, $object ) = @_;
  my $label = '';
  my $html = qq(<h3>Non-animated Presentations</h3>
  <p>We also have an number of our workshop presentations online as PDF documents, covering subjects from overviews of Ensembl to detailed worked examples. Please visit the <a href="/info/using/website/tutorials/">tutorials homepage</a> for the up-to-date list.</p>
  );

  $panel->print($html);
  return 1;
}

1;
