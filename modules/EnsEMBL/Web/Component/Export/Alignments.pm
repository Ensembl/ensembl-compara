package EnsEMBL::Web::Component::Export::Alignments;

use strict;

use CGI qw(unescape);

use EnsEMBL::Web::Constants;

use base 'EnsEMBL::Web::Component::Export';

sub content {
  my $self = shift;
  my $object = $self->object;
  
  my $align = $object->parent->{'params'}->{'align'}->[0];
  
  my $params = {
    action   => 'Export', 
    type     => $object->function, 
    function => 'Alignment',
    output   => 'alignment',
    align    => $align
  };
  
  my $href = CGI::unescape($object->_url($params));
  
  my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;
  
  my @list = map qq{<a class="modal_close" href="$href;format=$_;_format=Text" rel="external">$formats{$_}</a>}, sort keys %formats;
  
  my $form = $self->modal_form('export_output_configuration', '#', { no_button => 1, method => 'get' });
  
  $form->add_fieldset;
  
  $form->add_notes({ class => undef, text => 'Please choose a format for your exported data' });
  $form->add_notes({ class => undef, list => \@list });
      
  return '<h2>Export Configuration - Genomic Alignments</h2>' . $form->render;
}

1;
