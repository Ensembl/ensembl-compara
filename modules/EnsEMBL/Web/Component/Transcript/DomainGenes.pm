package EnsEMBL::Web::Component::Transcript::DomainGenes;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  my $self = shift;
  my $accession = $self->object->param('domain');
  if ($accession) {
    return "Other genes with domain $accession";
  }
  else {
    return undef;
  }
}


sub content {
  my $self = shift;
  my $object = $self->object;
  return unless $object->param('domain');

  ## Karyotype showing genes associated with this domain
  my $html;

  return $html;
}

1;

