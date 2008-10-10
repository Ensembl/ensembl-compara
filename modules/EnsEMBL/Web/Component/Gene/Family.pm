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
      { 'key' => 'id',          'title' => 'Family ID',                             'width' => '20%', 'align' => 'left' },
      { 'key' => 'annot',       'title' => 'Consensus annotation',                  'width' => '30%', 'align' => 'left' },
      { 'key' => 'transcripts', 'title' => $object->gene_name.' transcripts in this family',  'width' => '30%', 'align' => 'left' },
      { 'key' => 'jalview', 'title' => 'Multiple alignments',  'width' => '20%', 'align' => 'left' },
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
      $row->{'transcripts'} .= sprintf(qq(<li><a href="/%s/Transcript/Families?g=%s;t=%s">%s</a> (%s)</li>),
                        $object->species, $object->Obj->stable_id, 
                        $transcript->stable_id, $label, $transcript->stable_id);
    }
    $row->{'transcripts'} .= '</ul>';

    my $family = $object->create_family($family_id);
    my $ensembl_members   = $object->member_by_source($family, 'ENSEMBLPEP');
    my @all_pep_members;
    push @all_pep_members, @$ensembl_members;
    push @all_pep_members, @{$object->member_by_source($family, 'Uniprot/SPTREMBL')};
    push @all_pep_members, @{$object->member_by_source($family, 'Uniprot/SWISSPROT')};

    my $jalview = _jalview_link( 'Ensembl', $ensembl_members, $object ) .
               _jalview_link( '', \@all_pep_members, $object );
    $jalview = 'No alignment has been produced for this family.' unless $jalview;
    $row->{'jalview'} = $jalview;  

    $table->add_row($row);
  }
  
  return $table->render;
}

sub _jalview_link {
  my( $type, $refs, $object ) = @_;
  my $count     = @$refs;
  my $outcount = 0;
  return unless $count;
  my $BASE      = $object->species_defs->ENSEMBL_BASE_URL;
  my $FN        = $object->temp_file_name( undef, 'XXX/X/X/XXXXXXXXXXXXXXX' );
  my $file      = $object->species_defs->ENSEMBL_TMP_DIR_IMG."/$FN";
  $object->make_directory( $file );
  my $URL       = $object->species_defs->ENSEMBL_TMP_URL_IMG."/$FN";
  if( open FASTA,   ">$file" ) {;
    foreach my $member_attribute (@$refs){
      my ($member, $attribute) = @$member_attribute;
      my $align;
      eval { $align = $attribute->alignment_string($member); };
      unless ($@) {
        if($attribute->alignment_string($member)) {
          print FASTA ">".$member->stable_id."\n";
          print FASTA $attribute->alignment_string($member)."\n";
          $outcount++;
        }
      }
    }
    close FASTA;
  }
  return unless $outcount;

  return qq(
  <p class="space-below">$count $type members of this family:
    <applet archive="$BASE/jalview/jalview.jar"
        code="jalview.ButtonAlignApplet.class" width="100" height="35" style="border:0"
        alt = "[Java must be enabled to view alignments]">
      <param name="input" value="$BASE/$URL" />
      <param name="type" value="URL" />
      <param name=format value="FASTA" />
      <param name="fontsize" value="10" />
      <param name="Consensus" value="*" />
      <strong>Java must be enabled to view alignments</strong>
    </applet>
  </p>
);
}

1;
