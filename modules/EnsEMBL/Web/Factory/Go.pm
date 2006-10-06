package EnsEMBL::Web::Factory::Go;
                                                                                   
use strict;
use warnings;
no warnings "uninitialized";
                                                                                   
use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
                                                                                   
our @ISA = qw(  EnsEMBL::Web::Factory );

sub createObjects { 
  my $self   = shift;
  
  my $acc_id = $self->param('acc') || $self->param('display');
  my $query = $self->param('query');
  my $limit = $self->param('limit') || 5;

  # Get databases
  my $db  = $self->database('core');
  unless ($db){
    $self->problem( 'Fatal', 'Database Error', "Could not connect to the core database." ); 
    return ;
  }      

  my $ga  = $self->database('go');
  unless ($ga){
    $self->problem( 'Fatal', 'Database Error', "Could not connect to the GO database." ); 
    return ;
  }      

  my $ca  = $self->database('compara');
  unless ($ca){
    $self->problem( 'Fatal', 'Database Error', "Could not connect to the compara database." );
    return ;
  }      
  my $fa = $ca->get_FamilyAdaptor;

  my ($term, $graph, %families);
  if ($acc_id || $query) {
    if ($acc_id=~/^(GO:\d+)/i) {
        $acc_id = uc($1);
        $term    = $ga->get_term({'acc'=>$acc_id});
        $graph   = $ga->get_graph_by_terms([$term], $limit);
    } else {
        if (($query =~ /^(GO\:\d+)/i) || ($query =~ /^(\d+)$/)){
            $query = uc( $1 );
            $graph = $ga->get_graph_by_acc($query,$limit);
        } else {
            $term    = $ga->get_terms({'search'=>$query});
            $graph   = $ga->get_graph_by_terms($term, $limit);
        }
    }
    # get genes associated with this graph
## Let us lazy load this....
  }
  $self->DataObjects( new EnsEMBL::Web::Proxy::Object( 
        'Go', 
        {'acc_id'=>$acc_id, 'term' => $term, 'graph' => $graph, 'families' => {} },
        $self->__data )
    );
 
}


1;

