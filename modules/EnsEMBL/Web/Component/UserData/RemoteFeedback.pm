package EnsEMBL::Web::Component::UserData::RemoteFeedback;

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

  my $form = EnsEMBL::Web::Form->new('url_feedback', '', 'post');

  $form->add_element(
    type  => 'Information',
    value => qq(Thank you - your remote data was successfully attached. Close this Control Panel to view your data),
  );
  $form->add_element( 'type' => 'ForceReload' );

  ## This next bit is a hack - we need to implement userdata configuration properly!
  if ($hub->param('format') =~ /bigwig/i) {
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
      'label'   => "Graph colour",      'values'  => $colour_values,
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
#   $form->add_element('type'  => 'Float',
#                      'name'  => 'min',
#                      'label' => 'Range Minimum (optional)',
#                      'size'  => '10',
#                      'notes' => 'You can set a fixed minimum or leave this field blank in which case automatic scaling will be done.'
#                      );
# 
#   $form->add_element('type'  => 'Float',
#                      'name'  => 'max',
#                      'label' => 'Range Maximum (optional)',
#                      'size'  => '10',
#                      'notes' => 'You can set a fixed maximum or leave this field blank in which case automatic scaling will be done.'
#                      );

  }

  return $form->render;
}

1;
