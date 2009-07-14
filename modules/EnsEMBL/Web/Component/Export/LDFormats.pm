package EnsEMBL::Web::Component::Export::LDFormats;

use strict;

use CGI qw(unescape);

use base 'EnsEMBL::Web::Component::Export';

sub content {
  my $self = shift;
  my $object = $self->object;

  my $type = $object->param('type');
  my $form_action = $object->_url({ opt_pop => $object->param('opt_pop') }, 1);
  my $text = 'Please choose a format for your exported data';
  my (@list, $params);
  
  my $form = $self->modal_form('export_output_configuration', $form_action->[0], { no_button => 1, method => 'get' });
  
  $form->add_fieldset;
  
  if ($type) {    
    $form->add_notes({ class => undef, text => 'Your export has been processed successfully. You can download the exported data by following the links below' });
    $form->add_element(type => 'Hidden', name => $_, value => $form_action->[1]->{$_}) for keys %{$form_action->[1]};
    $form->add_button(type => 'Submit', name => 'submit', value => '< Back');
  } else {
    $form->add_notes({ class => undef, text => 'Please choose the output format for your export' });
  }
  
  foreach ($self->get_formats($type)) {    
    my $url = CGI::unescape($_->[1] . ($_->[2] ? ";_format=$_->[2]" : ''));
    my $class = $_->[5] || 'modal_close';
    
    push @list, qq{<a class="$class" href="$url"$_->[3]>$_->[0]</a>$_->[4]};
  }
  
  $form->add_notes({ class => undef, list => \@list });
  
  return '<h2>Export Configuration - Linkage Disequilibrium Data</h2>' . $form->render;
}

sub get_formats {
  my $self = shift;
  my $type = shift;
  my $object = $self->object;
  
  my @formats;

  if ($type eq 'haploview') {
    @formats = (
      [ 'Genotype file',     $object->param('gen_file'),   '', ' rel="external"', ' [Genotypes in linkage format]' ],
      [ 'Locus information', $object->param('locus_file'), '', ' rel="external"', ' [Locus information file]' ],
      [ 'Combined file',     $object->param('tar_file') ]
    );
  } elsif ($type eq 'excel') {
    @formats = (
      [ 'Excel', $object->param('excel_file') ]
    );
  } else {
    my $opt_pop = $object->parent->{'params'}->{'opt_pop'}->[0];
    $opt_pop =~ s/(%3A|:)on//; # FIXME: Hack to remove :on from opt_pop
    
    my $href = $object->_url({
      type    => $object->function, 
      action  => 'Export', 
      output  => 'ld', 
      opt_pop => $opt_pop,
    });
    
    my $excel = $object->_url({
      type     => 'Export',
      action   => 'LDExcelFile',
      function => $object->function, 
      opt_pop  => $opt_pop,
    });
    
    my $haploview = $object->_url({
      type     => 'Export',
      action   => 'HaploviewFiles',
      function => $object->function, 
      opt_pop  => $opt_pop,
    });
    
    @formats = (
      [ 'HTML',  $href, 'HTML', ' rel="external"' ],
      [ 'Text',  $href, 'Text', ' rel="external"' ],
      [ 'Excel', $excel, '', '', '', 'modal_link' ],
      [ 'For upload into Haploview software', $haploview, '', '', ' [<a href="http://www.broad.mit.edu/mpg/haploview/" rel="external">Haploview website</a>]', 'modal_link' ]
    );
  }
  
  return @formats;
}

1;
