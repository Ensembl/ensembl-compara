=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Export::LDFormats;

use strict;

use URI::Escape qw(uri_unescape);

use base qw(EnsEMBL::Web::Component::Export);

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $type        = $hub->param('type');
  my $form_action = $hub->url({ pop1 => $hub->param('pop1') }, 1); 
  my $text        = 'Please choose a format for your exported data';
  my $form        = $self->modal_form('export_output_configuration', $form_action->[0], { no_button => 1, method => 'get' });
  my (@list, $params);
  
  $form->add_fieldset;
  
  if ($type) {    
    $form->add_notes({ class => undef, text => 'Your export has been processed successfully. You can download the exported data by following the links below' });
    $form->add_element(type => 'Hidden', name => $_, value => $form_action->[1]->{$_}) for keys %{$form_action->[1]};
    $form->add_button(type => 'Submit', name => 'submit', value => '< Back');
  } else {
    $form->add_notes({ class => undef, text => 'Please choose the output format for your export' });
  }
  
  foreach ($self->get_formats($type)) {    
    my $url   = uri_unescape($_->[1] . ($_->[2] ? ";_format=$_->[2]" : ''));
    my $class = $_->[5] || 'modal_close';
    
    push @list, qq{<a class="$class" href="$url"$_->[3]>$_->[0]</a>$_->[4]};
  }
  
  $form->add_notes({ class => undef, list => \@list });
 
  my ($chr, $start, $end) = split(':|-', $hub->param('r'));
  my $warning = $end - $start >= 2e4 ? $self->warning_panel('Large region', 'Please note: <b>haploview export</b> for regions over 20kb may fail to load owing to data density.') : '';
 
  return '<h2>Export Configuration - Linkage Disequilibrium Data</h2>' . $form->render . $warning;
}

sub get_formats {
  my $self = shift;
  my $type = shift;
  my $hub  = $self->hub;
  
  my @formats;

  if ($type eq 'haploview') {
    @formats = (
      [ 'Genotype file',     $hub->param('gen_file'),   '', ' rel="external"', ' [Genotypes in linkage format]' ],
      [ 'Locus information', $hub->param('locus_file'), '', ' rel="external"', ' [Locus information file]' ],
      [ 'Combined file',     $hub->param('tar_file') ]
    );
  } elsif ($type eq 'excel') {
    @formats = (
      [ 'Excel', $hub->param('excel_file') ]
    );
  } else {
    my %params   = %{$hub->referer->{'params'}};
    my $function = $hub->function;
    my %populations;

    foreach (keys %params) {
      if ($_ =~/pop\d+/){
        my $name = $params{$_}->[0];
        $populations{$_} = $name;
      }
    }
    
    my $href = $hub->url({
      type    => 'Export/Output', 
      action  => 'Location', 
      output  => 'ld', 
      %populations
    });
    
    my $excel = $hub->url({
      type     => 'Export',
      action   => 'LDExcelFile',
      function => $function, 
      %populations
    });
    
    my $haploview = $hub->url({
      type     => 'Export',
      action   => 'HaploviewFiles',
      function => $function, 
      %populations
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
