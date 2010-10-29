package EnsEMBL::Web::Component::StructuralVariation::Summary;

use strict;

use base qw(EnsEMBL::Web::Component::StructuralVariation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self                = shift;
  my $hub                 = $self->hub;
  my $object              = $self->object;
  my $name                = $object->name;
  my $class               = $object->class;
  my $source              = $object->source;
  my $source_description  = $object->source_description;
 
  $name = "$class ( $name source $source - $source_description)";
 
  my $html = qq{
    <dl class="summary">
      <dt> Variation class </dt>
      <dd>$name</dd>
  };
 

  $html .= "</dl>";
  return $html;
}

1;
