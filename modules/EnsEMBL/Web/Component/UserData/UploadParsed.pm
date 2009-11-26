package EnsEMBL::Web::Component::UserData::UploadParsed;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Text::FeatureParser;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub caption {
  my $self = shift;
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  my $url    = $self->ajax_url('ajax', 1) . ';r=' . $object->parent->{'params'}->{'r'}[0] . ';code=' .  $object->param('code');
  
  return qq{<div class="ajax" title="['$url']"></div>};
}

sub content_ajax {
  my $self = shift;
  
  my $object = $self->object;
  my $upload = $object->get_session->get_data('code' => $object->param('code'));
  my $html;

  # Here's what we actually want to do!
  my $total_features;
  my $parser = EnsEMBL::Web::Text::FeatureParser->new($object->species_defs, $object->param('r'));
  
  if ($upload->{'type'} eq 'upload') {
    #warn "UPLOAD ".$upload->{'filename'}.' = '.$upload->{extension};
    my $file = new EnsEMBL::Web::TmpFile::Text(filename => $upload->{'filename'}, extension => $upload->{'extension'});
    my $data = $file->retrieve;

    $parser->parse($data, $upload->{'format'});
    $upload->{'format'} = $parser->format unless $upload->{'format'};
    $upload->{'style'}  = $parser->style;
    $object->get_session->set_data($upload);

    $html .= '<p class="space-below"><strong>Total features found</strong>: ' . $parser->feature_count . '</p>';

    if ($parser->nearest) {
      $html .= '<p class="space-below"><strong>Go to nearest region with data</strong>: ';
      $html .= qq{<a href="/$upload->{'species'}/Location/View?r=} . $parser->nearest . '">' . $parser->nearest . '</a></p>';
      $html .= '<p class="space-below">or</p>';
    }
    $html .= '<p>Close this window to return to current page</p>';
  }

  return $html;
}

1;
