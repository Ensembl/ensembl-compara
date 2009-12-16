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
  my ($html_target, $text_target, $title, $extra_param, $convert_file);
  
  if ($object->param('id_mapper') ) {
    $title = 'Stable ID Mapper';
    $html_target = 'IDConversion';
    $text_target = 'MapIDs';       
  } elsif ($object->param('consequence_mapper')) {
    $title = 'Consequence Calculator';  
    $html_target = 'ConsequenceCalculator';
    $text_target = 'SNPConsequence';
  }

  my $species_path = $object->species_path($object->data_species);
  my $html         = "<h2>$title</h2>";
  my $text         = "Please select the format you would like your output in:";
  my $species      = ';species=' . $object->param('species');
  my $referer      = ';_referer=' . uri_escape($object->parent->{'uri'});
  
  $extra_param .= ';_time=' . $object->param('_time') if $object->param('_time');
  
  $convert_file  = ';convert_file=' . $object->param('convert_file') if $object->param('convert_file');
  $convert_file .= ';id_limit=' . $object->param('id_limit') if $object->param('id_limit');
  
  my $html_url = "$species_path/UserData/$html_target?format=html" . $convert_file . $species . $referer;
  my $text_url = "$species_path/UserData/$text_target?format=text" . $convert_file . $species . $extra_param;
  
  my $list = [
    qq{<a href="$html_url">HTML</a>},
    qq{<a class="modal_link" href="$text_url">Text</a>}
  ];
  
  my $form = $self->modal_form('select', "$species_path/UserData/IDMapper", { no_button => 1 });
  
  $form->add_fieldset;
  $form->add_notes({ class => undef, text => $text });
  $form->add_notes({ class => undef, list => $list });

  $html .= $form->render;
  
  return $html;
}


1;
