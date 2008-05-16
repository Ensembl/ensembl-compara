package EnsEMBL::Web::Component::Transcript::Family;

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
  return undef;
}


sub content {
  my $self = shift;
  my $object = $self->object;
  my $pepdata  = $object->translation_object;
  return unless $pepdata;
  my $families = $pepdata->get_family_links($pepdata);
  return unless %$families;

  my $html;
  foreach my $family_id (keys %$families) {
    my $family_url   = "/@{[$object->species]}/familyview?family=$family_id";
    my $family_count = $families->{$family_id}{'count'};
    my $family_desc  = $families->{$family_id}{'description'};
    $html .= qq(<p>
      <a href="$family_url">$family_id</a> : $family_desc<br />
            This cluster contains $family_count Ensembl gene member(s) in this species.</p>);
  }   

 return $html;
}

1;

