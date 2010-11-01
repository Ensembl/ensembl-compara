# $Id$

package EnsEMBL::Web::Component::LRG::LRGDiff;

### NAME: EnsEMBL::Web::Component::LRG::LRGDiff;
### Generates a table of differences between the LRG and the reference sequence

### STATUS: Under development

### DESCRIPTION:
### Because the LRG page is a composite of different domain object views, 
### the contents of this component vary depending on the object generated
### by the factory

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::LRG);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $lrg  = $self->object->Obj;
  my $html;
  
  my $columns = [
    { key => 'location', sort => 'position_html', title => 'Location'           },
    { key => 'type',     sort => 'string',        title => 'Type'               },
    { key => 'lrg' ,     sort => 'string',        title => 'LRG sequence'       },
    { key => 'ref',      sort => 'string',        title => 'Reference sequence' },
  ];
  
  my @rows;
  
  foreach my $diff (@{$lrg->get_all_differences}) {
    push @rows, {
      location => $lrg->seq_region_name . ":$diff->{'start'}" . ($diff->{'end'} == $diff->{'start'} ? '' : "-$diff->{'end'}"),
      type     => $diff->{'type'},
      lrg      => $diff->{'seq'},
      ref      => $diff->{'ref'},
    };
  }
  
  if (@rows) {
    $html .= $self->new_table($columns, \@rows, { data_table => 1, sorting => [ 'location asc' ] })->render;
  } else {
	# find the name of the reference assembly
	my $csa = $self->object->get_adaptor('get_CoordSystemAdaptor', 'core');
	my ($highest_cs) = @{$csa->fetch_all()};
    my $assembly = $highest_cs->version();
	
    $html .= qq{<h3>No differences found - the LRG reference sequence is identical to the $assembly reference assembly sequence</h3>};
  }
  
  return $html;
}

1;
