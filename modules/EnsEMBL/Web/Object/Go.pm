package EnsEMBL::Web::Object::Go;
                                                                                   
use strict;
use warnings;
no warnings "uninitialized";
                                                                                   
use EnsEMBL::Web::Object;
use EnsEMBL::Web::Proxy::Object;
                                                                                   
@EnsEMBL::Web::Object::Go::ISA = qw(EnsEMBL::Web::Object);

sub acc_id  { return $_[0]->Obj->{'acc_id'} if $_[0]->Obj->{'acc_id'}; }
sub name  { return $_[0]->Obj->{'term'}->name if $_[0]->Obj->{'term'}; }
sub families { return $_[0]->Obj->{'families'} if $_[0]->Obj->{'families'};}

sub iterator { 
    my $graph = $_[0]->Obj->{'graph'};
    my $iterator = $graph->create_iterator();
    return $iterator;
}

sub retrieve_features {
  my $acc_id = $_[0]->Obj->{'acc_id'};
  my $array_ref = $_[0]->Obj->{'families'}{$acc_id};
  my $results = [];
  
  foreach my $subarray_ref (@$array_ref) {
    my @subarray = @$subarray_ref;
    my $gene = $subarray[0];
    push @$results, {
      'region'   => $gene->seq_region_name,
      'start'    => $gene->start,
      'end'      => $gene->end,
      'strand'   => $gene->strand,
      'length'   => $gene->end-$gene->start+1,
      'extname'  => $gene->external_name, 
      'label'    => $gene->stable_id,
      'extra'    => [ $gene->description ]
    }
  }
  
  return ( $results, ['Description'] );
}

sub get_geneinfo {
  my $acc_id = $_[0]->Obj->{'acc_id'};
  my $array_ref = $_[0]->Obj->{'families'}{$acc_id};
  my $results = [];
  
  foreach my $subarray_ref (@$array_ref) {
    my @subarray = @$subarray_ref;
    my $gene = $subarray[0];
    my $ev = '???';
    foreach my $dbl( @{$gene->get_all_DBLinks} ){
        next if ! $dbl->isa('Bio::EnsEMBL::GoXref');
        next if $dbl->display_id ne $acc_id;
        $ev = join( ',', @{$dbl->get_all_linkage_types} );
        last;
    }
    push @$results, {
        'stable_id'     => $gene->stable_id,
        'evidence'      => $ev,
        'description'   => $gene->description
    }
  }
  return $results;
} 

sub get_faminfo {
  my $acc_id = $_[0]->Obj->{'acc_id'};
  my $array_ref = $_[0]->Obj->{'families'}{$acc_id};
  my $results = [];
  
  foreach my $subarray_ref (@$array_ref) {
    my @subarray = @$subarray_ref;
    my $family = $subarray[1];

    push @$results, {
        'stable_id'     => $family->stable_id,
        'description'   => $family->description
    }
  }
  return $results;
}

1;
