package EnsEMBL::Web::Component::Gene::Family;

### Displays a list of protein families for this gene

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $sp = $object->species_defs->SPECIES_COMMON_NAME;
  my $families = $object->get_all_families;

  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );

  $table->add_columns(
      { 'key' => 'id',         'title' => 'Family ID',                'width' => '20%', 'align' => 'left' },
      { 'key' => 'annot',      'title' => 'Consensus annotation',     'width' => '30%', 'align' => 'left' },
      { 'key' => 'transcripts', 'title' => "Other $sp transcripts in this family", 'width' => '30%', 'align' => 'left' },
      { 'key' => 'jalview',    'title' => 'Multiple alignments',      'width' => '20%', 'align' => 'left' },
  );

  foreach my $family_id (sort keys %$families) {
    my $family = $families->{$family_id};
    my $row = {};

    $row->{'id'}  = $family_id;
    my $genes = $families->{$family_id}{'info'}{'genes'};
    if (scalar(@$genes) > 1) {
      $row->{'id'} .= sprintf(qq#<br /><br />(<a href="/%s/Gene/Family/Genes?%s;family=%s" title="Show locations of these genes">%s genes</a>)#, 
                    $object->species, join(';', @{$object->core_params}),
                    $family_id, scalar(@$genes)
                    );
    }
    else {
      $row->{'id'} .= '<br /><br />(1 gene)';
    }
    my $prot_url = sprintf('/%s/Gene/Family/Proteins?%s;family=%s', 
                    $object->species, join(';', @{$object->core_params}), $family_id
    );
    $row->{'id'} .= '<br />(<a href="'.$prot_url.'">all proteins in family</a>)';

    $row->{'annot'} = $families->{$family_id}{'info'}{'description'};

    my @transcripts;
    $row->{'transcripts'} = '<ul>';
    foreach my $transcript (@{$family->{'transcripts'}}) {
      my $label = $transcript->display_xref;
      $row->{'transcripts'} .= sprintf(qq(<li><a href="/%s/Gene/Family/Genes?g=%s;family=%s">%s</a> (%s)</li>),
                        $object->species, $object->Obj->stable_id, $family_id,
                        $transcript->stable_id, $label, $transcript->stable_id);
    }
    $row->{'transcripts'} .= '</ul>';

    my $fam_obj = $object->create_family($family_id);
    my $ensembl_members   = $object->member_by_source($fam_obj, 'ENSEMBLPEP');
    my @all_pep_members;
    push @all_pep_members, @$ensembl_members;
    push @all_pep_members, @{$object->member_by_source($fam_obj, 'Uniprot/SPTREMBL')};
    push @all_pep_members, @{$object->member_by_source($fam_obj, 'Uniprot/SWISSPROT')};

    my $jalview = $self->_jalview_link( $family_id, 'Ensembl', $ensembl_members ) .
               $self->_jalview_link( $family_id, '', \@all_pep_members );
    $jalview = 'No alignment has been produced for this family.' unless $jalview;
    $row->{'jalview'} = $jalview;  

    $table->add_row($row);
  }
  
  return $table->render;
}

sub _jalview_link {
  my( $self, $family, $type, $refs ) = @_;
  my $count     = @$refs;
  my $url = '/'.$self->object->species.$self->url('/Gene/Family/Alignments');
  $url .= "?family=$family;".join(';', @{$self->object->core_params});
  return qq(
  <p class="space-below">$count $type members of this family <a href="$url">JalView</a></p>
);
}

1;
