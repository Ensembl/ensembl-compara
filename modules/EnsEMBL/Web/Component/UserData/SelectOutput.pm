package EnsEMBL::Web::Component::UserData::SelectOutput;

use strict;
use warnings;
use warnings 'uninitialized';

use URI::Escape qw(uri_escape);

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption { return ''; }

sub content {
  my $self = shift; 
  my $object = $self->object;
  my ($html_target, $text_target, $title, $convert_file, $data_format);
  my $extra_param = "";

  if ($object->param('id_mapper') ) {
    $title = 'Stable ID Mapper';
    $html_target = 'IDConversion';
    $text_target = 'MapIDs';       
    $data_format = 'id';
  } elsif ($object->param('consequence_mapper')) {
    $title = 'Variant Effect Predictor';  
    $html_target = 'ConsequenceCalculator';
    $text_target = 'PreviewConvertIDs';
    $data_format = 'snp';
  }

  my $html         = "<h2>$title</h2>";

  if ($object->param('consequence_mapper') && $object->param('count')) {
    $html .= $self->_info('Too many features', 'Your file contained '.$object->param('count') .' features; however this web tool will only convert the first '. $object->param('size_limit') .' features in the file.');
  }

  my $text         = "Please select the format you would like your output in:";
  my $species      = ';species=' . $object->param('species');
  my $species_path = $object->species_path($object->data_species) || '/'.$species;
  
  $extra_param .= ';_time=' . $object->param('_time') if $object->param('_time');
  
  $convert_file  = ';convert_file=' . $object->param('convert_file') if $object->param('convert_file');
  $convert_file .= ';id_limit=' . $object->param('id_limit') if $object->param('id_limit');
  $convert_file .= ';variation_limit=' . $object->param('variation_limit') if $object->param('variation_limit');
  
  my $html_url = "$species_path/UserData/$html_target?format=html;data_format=".$data_format . $convert_file . $species;
  $html_url .= ';code='.$object->param('code') if $object->param('code');

  my $text_url = "$species_path/UserData/$text_target?format=text;data_format=".$data_format . $convert_file . $species . $extra_param;
  
  my $list = [
    qq{<a class="modal_link" href="$html_url">HTML</a>},
    qq{<a class="modal_link" href="$text_url">Text</a>}
  ];
  
  my $form = $self->modal_form('select', "$species_path/UserData/IDMapper", { no_button => 1 });
  
  $form->add_fieldset;
  $form->add_notes({ class => undef, text => $text });
  $form->add_notes({ class => undef, list => $list });
  
  $html .= $form->render;

  if ($object->param('code')) {
    my $session_data = $self->hub->session->get_data('code' => $object->param('code'));
    my $nearest = $session_data->{'nearest'};
    if ($nearest) {
      $html .= qq(
<p>or view a sample SNP in <a href="$species_path/Location/View?r=$nearest">Region in Detail</a></p>
<p>(You can also view or download your converted file from 'Manage Your Data')</p>
);
    }
  }

  return $html;
}


1;
