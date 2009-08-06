package EnsEMBL::Web::Component::UserData::SelectOutput;

use strict;
use warnings;
use warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return '';
}


sub content {
  my $self = shift; 
  my $object = $self->object;
  my $html = "<h2>Stable ID Mapper</h2>";
  my $text = "Please select the format you would like your output in:";
  my $referer;
  if ($object->param('_referer')){ 
    $referer =  ';_referer='. $object->param('_referer');
  }
  my $extra_param = ';x_requested_with='.$object->param('x_requested_with');
  if ($object->param('_time')) { $extra_param.= ';_time='.$object->param('_time'); }                      
  my $convert_file;
  if ($object->param('convert_file')) {
    $convert_file = ';convert_file='.$object->param('convert_file');
  }
  if ($object->param('id_limit')) {
    $convert_file .=';id_limit=' .$object->param('id_limit');
  }
  my $species= ';species='.$object->param('species');
  my $html_url = '/'.$object->data_species.'/UserData/IDConversion?format=html' .$convert_file.$referer.$species;
  my $text_url = '/'.$object->data_species.'/UserData/MapIDs?format=text' .$convert_file.$referer.$extra_param.$species;
  my $list =  [
              '<a href='.$html_url.'>HTML</a>',
              '<a class="modal_link" href='.$text_url.'>Text</a> ',
  ];


  my $form = $self->modal_form('select', "/$object->data_species/UserData/IDMapper", { no_button => 1 });

  $form->add_fieldset;
  $form->add_notes({ class => undef, text => $text });
  $form->add_notes({ class => undef, list => $list });

  $html .= $form->render;
  return $html;
}


1;
