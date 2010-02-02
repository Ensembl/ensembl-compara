package EnsEMBL::Web::Factory::Link;

use strict;

use base qw(EnsEMBL::Web::Factory);

sub createObjects { 
  my $self       = shift;    
  my $ext_db	 = $self->param('d');
  ## Grab remaining parameters and place in the hash pars
  my %pars = map { $_ eq 'd' ? () : ($_,$self->param($_)) } $self->param();
  my $URL        = $self->get_ExtURL( $ext_db, \%pars );

  if( $URL ) { 
    $self->DataObjects($self->new_object( 'Link', $URL, $self->__data ) ); 
  } else {
    $self->problem(
      'fatal', "Can't find database",
      "Do not know how to find URL for database ".$self->param('d')
    );
  }
}

1;
