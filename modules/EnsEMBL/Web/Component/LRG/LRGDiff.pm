#$Id$
package EnsEMBL::Web::Component::LRG::LRGDiff;

### NAME: EnsEMBL::Web::Component::LRG::LRGDiff;
### Generates a table of differences between the LRG and the reference sequence

### STATUS: Under development

### DESCRIPTION:
### Because the LRG page is a composite of different domain object views, 
### the contents of this component vary depending on the object generated
### by the factory

use strict;
use warnings;
no warnings "uninitialized";
use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::Component::LRG);
use EnsEMBL::Web::Document::SpreadSheet;
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  
  my $html;
  
  my $columns = [
    { key => 'location', sort => 'position_html', title => 'Location'           },
    { key => 'Type',     sort => 'string',                                      },
    { key => 'lrg' ,     sort => 'string',        title => 'LRG sequence'       },
    { key => 'ref',      sort => 'string',        title => 'Reference sequence' },
  ];
  
  my $rows;
  
  foreach my $diff(@{$object->Obj->get_all_differences}) {
	my %row = (
	  'location' => $object->Obj->seq_region_name.':'.$diff->{start}.($diff->{end} == $diff->{start} ? '' : '-'.$diff->{end}),
	  'Type'     => $diff->{type},
	  'lrg'      => $diff->{seq},
	  'ref'      => $diff->{ref},
	);
	
	push @$rows, \%row;
  }
  
  if($rows) {
  
	my $table = new EnsEMBL::Web::Document::SpreadSheet($columns, $rows, { data_table => 1, sorting => [ 'location asc' ] });
	
	$html .= $table->render;
  }
  
  else {
	$html .= '<h3>No differences found - LRG sequence matches reference</h3>';
  }
  
  return $html;
}

1;
