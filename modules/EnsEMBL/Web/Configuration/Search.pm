package EnsEMBL::Web::Configuration::Search;

use strict;
use EnsEMBL::Web::Configuration;
our @ISA = qw( EnsEMBL::Web::Configuration );

sub search {
  my $self  = shift;
  my $obj   = $self->{'object'};
  return unless @{$obj->Obj};
  my $species = $obj->Obj->[0]->{'species'};
  my $idx     = $obj->Obj->[0]->{'idx'};
  $self->set_title( "Search results" );
  if( my $panel1 = $self->new_panel( '',
    'code'    => "info#",
    'caption' => "Search results for $species $idx"
  )) {
    $panel1->add_components(qw(
      results     EnsEMBL::Web::Component::Search::results
    ));
    $self->add_panel( $panel1 );
  }
}

1;
