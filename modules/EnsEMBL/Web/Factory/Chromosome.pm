package EnsEMBL::Web::Factory::Chromosome;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;

use vars qw( @ISA );
@ISA = qw(  EnsEMBL::Web::Factory );


sub createObjects {   
  my $self = shift;    
  my $chr = uc( $self->param('chr'));
  my @chromosomes = map { uc($_) } @{$self->species_defs->ENSEMBL_CHROMOSOMES};
  my %chrhash;

  if($self->param('otherspecies')) {
    $self->DBConnection->get_databases( 'core', 'compara' );
  }

  $chr =~ s/^CHR//i;       # for retro-compatability
  @chrhash{@chromosomes}=1;
  $chr = $chromosomes[0] unless $chr eq 'ALL' || exists $chrhash{$chr};
  $self->is_golden; # test if we can get a chromosome	
  unless ($chr){
    $self->problem( 'Fatal', 'No "Golden Path" assembly', "No chromosomes could be found for @{[$self->species]} and no chromosome fragment was specified." );
    return;
  }

  my $database  = $self->database('core') ; 
  if ($self->DBConnection->has_fatal_error){
    $self->problem( 'Fatal', 'Database Error', 'Could not connect to the Ensembl Databases');
    return;
  }	
  my $sa ;
  my $chromosome;
  if(!$database) { 				
    eval { $sa = $database->get_SliceAdaptor(); };
    $self->problem( 'Fatal','EnsEMBL Error' ,"Sorry, can't retrieve chromosome information.") if($@);
    $chromosome = $sa->fetch_by_region( undef, $chr) unless ( $chr eq 'ALL' ); 
  } else {
    eval { $sa = $self->database('core')->get_SliceAdaptor(); };
    $self->problem( 'Fatal','EnsEMBL Error' ,"Sorry, can't retrieve chromosome information.") if($@);
    $chromosome = $sa->fetch_by_region( undef, $chr) unless ( $chr eq 'ALL' );
  }

  my $dataobject = EnsEMBL::Web::Proxy::Object->new( 'Chromosome', $chromosome, $self->__data );
  return unless $dataobject;
  $self->DataObjects($dataobject);
}

#------------------------------------------------------------------------------

sub is_golden {
  my $self = shift ;
  unless( @{ $self->species_defs->ENSEMBL_CHROMOSOMES || [] } ){
    $self->problem( 'non_fatal', 'No "Golden Path" assembly', "We do not yet have a full assembly for $@{[$self->species]}, and there is therefore no chromosomal display available." );
    return 0;
  }
  return 1;
}

1;
