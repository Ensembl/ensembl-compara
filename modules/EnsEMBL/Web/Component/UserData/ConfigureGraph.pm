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

package EnsEMBL::Web::Component::UserData::ConfigureGraph;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'URL attached';
}

sub content {
  my $self = shift;
  my $current_species = $self->object->species_path($self->object->data_species); 
  
  my $form = $self->new_form({id => 'url_feedback', action => "$current_species/UserData/SaveExtraConfig", method => 'post'});

  ## This next bit is a hack - we need to implement userdata configuration properly!
  $form->add_element(
      type  => 'SubHeader',
      value => qq(Display options),
    );

  #GD defined colours
  # Todo - figure out how to map them to pdf colours etc 
  my @colours = ('red','green','blue','black','gray','gold','yellow','purple','orange','cyan');
  my $colour_values;
  foreach my $c (@colours) {
    push @$colour_values, {'name' => $c, 'value' => $c};
  }

  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'colour',
      'label'   => "Graph colour",      
      'values'  => $colour_values,
      'select'  => 'select',
      'disabled'=> scalar @colours ? 0 : 1,
  );

# Maybe add these options later
#
#   my @graph_types = ('line','bar');#   my $graph_values;
#   foreach my $gt (@graph_types) {
#     push @$graph_values, {'name' => $gt, 'value' => $gt};
#   }
# 
#   $form->add_element(
#       'type'    => 'DropDown',
#       'name'    => 'graphtype',
#       'label'   => "Graph type",
#       'values'  => $graph_values,
#       'select'  => 'select',
#       'disabled'=> scalar @graph_types ? 0 : 1,
#   );
# 
# 
   $form->add_element('type'  => 'Float',
                      'name'  => 'y_min',
                      'label' => 'Range Minimum (optional)',
                      'size'  => '10',
                      );
 
   $form->add_element('type'  => 'Float',
                      'name'  => 'y_max',
                      'label' => 'Range Maximum (optional)',
                      'size'  => '10',
                      'notes' => 'You can set a fixed minimum/maximum or leave these fields blank, in which case automatic scaling will be done. You can also adjust the limits later, using the popup menu on the track name'
                      );

  foreach (qw(code record_type)) {
    $form->add_element('type' => 'Hidden', 'name' => $_, 'value' => $self->hub->param($_));
  }
  $form->add_element('type' => 'Submit', 'value' => 'Save');

  return $form->render;
}

1;
