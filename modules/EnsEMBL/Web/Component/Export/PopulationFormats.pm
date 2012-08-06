package EnsEMBL::Web::Component::Export::PopulationFormats;

use strict;

use URI::Escape qw(uri_unescape);

use base 'EnsEMBL::Web::Component::Export';

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  
  my $params = {
    action   => 'Transcript', 
    type     => 'Export/Output', 
    function => 'Population',
    output   => 'gen_var'
  };
  
  my $view_config = $hub->get_viewconfig('VariationTable', 'Transcript');

  foreach ($view_config->options) {
    my $option = $view_config->get($_);
    $params->{$_} = $option unless $option =~ /^off|no$/;
  }
  
  my $href = uri_unescape($hub->url($params));
  
  my @formats = (
    [ 'HTML', 'HTML', ' rel="external"' ],
    [ 'Text', 'Text', ' rel="external"' ]
  );
  
  my @list;
  
  foreach (@formats) {
    my $format = ";_format=$_->[1]" if $_->[1];
    push @list, qq{<a class="modal_close" href="$href$format"$_->[2]>$_->[0]</a>$_->[3]};
  }
  
  my $form = $self->modal_form('export_output_configuration', '#', { no_button => 1, method => 'get' });
  
  $form->add_fieldset;
  
  $form->add_notes({ class => undef, text => 'Dump of SNP data per individual (SNPs in rows, individuals in columns). For more advanced data queries use <a href="/biomart/martview">BioMart</a>.' });
  $form->add_notes({ class => undef, text => 'Please choose a format for your exported data' });
  $form->add_notes({ class => undef, list => \@list });
      
  return '<h2>Export Configuration - Transcript Genetic Variation</h2>' . $form->render;
}

1;
