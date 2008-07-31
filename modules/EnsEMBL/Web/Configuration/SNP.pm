package EnsEMBL::Web::Configuration::SNP;

use strict;

use EnsEMBL::Web::RegObj;

use base qw( EnsEMBL::Web::Configuration );

## Function to configure gene snp view

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Structure';
}

sub local_context  { $_[0]->_local_context; }

sub populate_tree {
  my $self = shift;
}

sub global_context {
  my $self = shift;
  return $self->_global_context('SNP');
}

sub context_panel {
  my $self   = shift;
  my $obj    = $self->{'object'};
  my $panel  = $self->new_panel( 'Summary', 
    'code'     => 'summary_panel',
    'object'   => $obj,
    'caption'  => $obj->caption
  );
  #$panel->add_component( qw(snp_summary EnsEMBL::Web::Component::SNP::Summary) );
  $self->add_panel( $panel );
}

sub content_panel {
  my $self   = shift;
  my $obj    = $self->{'object'};

  my $action = $self->_get_valid_action( $ENV{'ENSEMBL_ACTION'} );
  my $node          = $self->get_node( $action );
  my $previous_node = $node->previous_leaf      ;
  my $next_node     = $node->next_leaf          ;

  my %params = (
    'object'   => $obj,
    'code'     => 'main',
    'caption'  => $node->data->{'caption'}
  );
  $params{'previous'} = $previous_node->data if $previous_node;
  $params{'next'    } = $next_node->data     if $next_node;
  my $panel = $self->new_panel( 'Navigation', %params );
  if( $panel ) {
    $panel->add_components( @{$node->data->{'components'}} );
    $self->add_panel( $panel );
  }
}

1;
