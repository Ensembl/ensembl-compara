package EnsEMBL::Web::Component::Help;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;

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
  foreach my $entry (@$glossary) {     my $word    = $$entry{'word'};
    (my $anchor = $word) =~ s/ /_/g;
    my $meaning = $$entry{'meaning'};
    $html .= qq(<dt id="$anchor">$word</dt>\n<dd>$meaning</dd>\n);
  }
  $html .= "</dl>\n\n";

  $panel->print($html);
  return 1;
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
