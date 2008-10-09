package EnsEMBL::Web::Component::Gene::Family;

### Displays a list of protein families for this gene

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $families = $object->get_all_families;

  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );

  $table->add_columns(
      { 'key' => 'id',          'title' => 'Family ID',                                 'width' => '20%', 'align' => 'left' },
      { 'key' => 'annot',       'title' => 'Consensus annotation',                      'width' => '40%', 'align' => 'left' },
      { 'key' => 'transcripts', 'title' => 'Transcripts with proteins in this family',  'width' => '30%', 'align' => 'left' },
  );

  foreach my $family_id (sort keys %$families) {
    my $family = $families->{$family_id};
    my $row = {};

    $row->{'id'}  = $family_id;
    my $genes = $families->{$family_id}{'info'}{'genes'};
    if (scalar(@$genes) > 1) {
      $row->{'id'} .= sprintf(qq#<br />(<a href="/%s/Gene/Family?%s;family=%s" title="Show locations of these genes">%s genes</a>)#, 
                    $object->species, join(';', @{$object->core_params}),
                    $family_id, scalar(@$genes)
                    );
    }
    else {
      $row->{'id'} .= '<br />(1 gene)';
    }

    $row->{'annot'} = $families->{$family_id}{'info'}{'description'};

    my @transcripts;
    $row->{'transcripts'} = '<ul>';
    foreach my $transcript (@{$family->{'transcripts'}}) {
      my $label = $transcript->display_xref;
      $row->{'transcripts'} .= sprintf(qq(<li><a href="/%s/Transcript/Families?g=%s;t=%s">%s</a> (%s)</li>),
                        $object->species, $object->Obj->stable_id, 
                        $transcript->stable_id, $label, $transcript->stable_id);
    }
    $row->{'transcripts'} .= '</ul>';
  
    $table->add_row($row);
  }
  
  return $table->render;
}

1;
