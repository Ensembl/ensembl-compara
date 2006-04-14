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
    $self->problem( 'Fatal', 
            'Database Error', 
            "Could not connect to the core database." ); 
    return ;
  }      

  my $ga  = $self->database('go');
  unless ($ga){
    $self->problem( 'Fatal', 
            'Database Error', 
            "Could not connect to the GO database." ); 
    return ;
  }      

  my $ca  = $self->database('compara');
  unless ($ca){
    $self->problem( 'Fatal', 
            'Database Error', 
            "Could not connect to the compara database." ); 
    return ;
  }      
  my $fa = $ca->get_FamilyAdaptor;

  my ($term, $graph, %families);
  if ($acc_id || $query) {
    if ($acc_id=~/^(GO:\d+)/i) {
        $acc_id = uc($1);
        $term    = $ga->get_term({'acc'=>$acc_id});
        $graph   = $ga->get_graph_by_terms([$term], $limit);
    }
    else {
        if (($query =~ /^(GO\:\d+)/i) || ($query =~ /^(\d+)$/)){
            $query = uc( $1 );
            $graph = $ga->get_graph_by_acc($query,$limit);
        } else {
            $term    = $ga->get_terms({'search'=>$query});
            $graph   = $ga->get_graph_by_terms($term, $limit);
        }
    }
    # get genes associated with this graph
    my $it   = $graph->create_iterator();
    while (my $ni = $it->next_node_instance) {
        my $tempid = $ni->term->public_acc();
        my $array_ref = []; 
        # get gene objects
        my @genes = $db->get_DBEntryAdaptor->list_gene_ids_by_extids($tempid);
        foreach my $gene (@genes) {
            my $subarray_ref = []; 
            my $gene_obj = $db->get_GeneAdaptor->fetch_by_dbID($gene);
            push (@$subarray_ref, $gene_obj);
            if ($self->param('display')) { 
                my $fam_obj = $fa->fetch_by_Member_source_stable_id( 'ENSEMBLGENE', $gene_obj->stable_id );
                push (@$subarray_ref, $fam_obj->[0]);
            }
            push (@$array_ref, $subarray_ref);
        }
        $families{$tempid} = $array_ref;
    }
  }
  $self->DataObjects( new EnsEMBL::Web::Proxy::Object( 
        'Go', 
        {'acc_id'=>$acc_id, 'term' => $term, 'graph' => $graph, 'families' => \%families,},
        $self->__data )
    );
 
}


1;

