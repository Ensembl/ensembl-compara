package EnsEMBL::Web::Component::Export::Alignments;

use strict;

use CGI qw(unescape);

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

  my @list;
  
  for(qw( CLUSTAL FASTA Mega MSF Nexus Pfam Phylip PSI Selex )) {
    push @list, sprintf '<a class="modal_close" href="%s;format=%s;_format=Text" rel="external">%s</a>', $href, $_ eq 'CLUSTAL' ? 'clustalw' : lc $_, $_;
  }
  
  my $form = $self->modal_form('export_output_configuration', '#', { no_button => 1, method => 'get' });
  
  $form->add_fieldset;
  
  $form->add_notes({ class => undef, text => 'Please choose a format for your exported data' });
  $form->add_notes({ class => undef, list => \@list });
      
  return '<h2>Export Configuration - Genomic Alignments</h2>' . $form->render;
}

1;
