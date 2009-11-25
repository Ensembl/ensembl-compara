package EnsEMBL::Web::Component::UserData::UploadParsed;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Text::FeatureParser;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html;

  my $upload = $object->get_session->get_data('code' => $object->param('code'));
  #$html = '<p style="margin-top:1em">Checking file contents: <img src="/i/ajax_progress.gif" alt="" style="margin-left:10px" /></p>';

  ## Here's what we actually want to do!
  my $total_features;
  my $referer = $object->param('_referer');
  $referer =~ /r=(\w+(:\d+-\d+)?)/; ## Get current coordinates from parent URL
  my $location = $1;
  my $parser = EnsEMBL::Web::Text::FeatureParser->new($object->species_defs, $location);
  if ($upload->{'type'} eq 'upload') {
    my $file = new EnsEMBL::Web::TmpFile::Text( filename => $upload->{'filename'});
    my $data = $file->retrieve;
    $parser->parse($data, $upload->{'format'});
    unless ($upload->{'format'}) {
      $upload->{'format'} = $parser->format;
    }
    $upload->{'style'} = $parser->style;
    $object->get_session->set_data($upload);
    $html .= '<p class="space-below"><strong>Total features found</strong>: '.$parser->feature_count.'</p>';
    if ($parser->nearest) {
      $html .= '<p class="space-below"><strong>Nearest region with data</strong>: ';
      $html .= '<a href="/'.$upload->{'species'}.'/Location/View?r='.$parser->nearest.'">'.$parser->nearest.'</a>';
    }
  }

  return $html;
}

1;
