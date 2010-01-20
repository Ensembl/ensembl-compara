package EnsEMBL::Web::Component::UserData::UploadParsed;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::TmpFile::Text;

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

  return qq{<div class="ajax"><input type="hidden" class="ajax_load" value="$url" /></div><div class="modal_reload"></div>};
}

sub content_ajax {
  my $self = shift;
  
  my $object = $self->object;
  my $upload = $object->get_session->get_data('code' => $object->param('code'));
  my $html;

  # Here's what we actually want to do!
  my $total_features;
  my $parser = new EnsEMBL::Web::Text::FeatureParser($object->species_defs, $object->param('r'));
  
  if ($upload->{'type'} eq 'upload') {
    my $size = int($upload->{'filesize'} / (1024 ** 2));
    
    if ($size > 10) {
      $html .= "<p>Your uncompressed file is over $size MB, which may be very slow to parse and load. Please consider uploading a smaller dataset.</p>";
    } else {
      my $file = new EnsEMBL::Web::TmpFile::Text(filename => $upload->{'filename'}, extension => $upload->{'extension'});
      my $data = $file->retrieve;
      
      $parser->parse($data, $upload->{'format'});
      $upload->{'format'} = $parser->format unless $upload->{'format'};
      $upload->{'style'}  = $parser->style;
      $upload->{'nearest'} = $parser->nearest;
      $object->get_session->set_data(%$upload);
      
      $html .= sprintf '<p class="space-below"><strong>Total features found</strong>: %s</p>', $parser->feature_count;
      
      if ($parser->nearest) {
        $html .= sprintf '<p class="space-below"><strong>Go to %s region with data</strong>: ', $object->parent->{'params'}{'r'} ? 'nearest' : 'first';
        $html .= sprintf '<a href="%s/Location/View?r=%s">%s</a></p>', $object->species_path($upload->{'species'}), $parser->nearest, $parser->nearest;
        $html .= '<p class="space-below">or</p>';
      }
      
      $html .= '<p>Close this window to return to current page</p>';
    }
  }

  return $html;
}

1;
