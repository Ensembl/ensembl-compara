package EnsEMBL::Web::Component::Family;

# outputs chunks of XHTML for protein family-based displays

use EnsEMBL::Web::Component;
our @ISA = qw(EnsEMBL::Web::Component);
use POSIX qw(floor ceil);

use strict;
use warnings;
no warnings "uninitialized";

# Stuff from former parent module ###########################################

sub karyotype_image {
  my( $panel, $object ) = @_;
  return 1 unless @{$object->species_defs->ENSEMBL_CHROMOSOMES};

  my $species = $object->species;

  my $wuc = $object->get_userconfig( 'Vkaryotype' );
  my $image    = $object->new_karyotype_image();
  $image->cacheable  = 'yes';
  $image->image_type = "family";
  $image->image_name = "$species-".$object->stable_id;
  $image->imagemap = 'yes';
  unless( $image->exists ) {
    my $genes   = $object->get_all_genes;
    return unless( @$genes );
    my %high = ( 'style' => 'arrow' );
    foreach my $gene (@$genes){
      my $stable_id = $gene->stable_id;
      my $chr       = $gene->seq_region_name;
      my $point = {
        'start' => $gene->seq_region_start,
        'end'   => $gene->seq_region_end,
        'col'   => 'red',
        'zmenu' => {
          'caption'               => 'Genes',
          "00:$stable_id"         => "/$species/geneview?gene=$stable_id",
          '01:Jump to contigview' => "/$species/contigview?geneid=$stable_id"
        }
      };
      if(exists $high{$chr}) {
        push @{$high{$chr}}, $point;
      } else {
        $high{$chr} = [ $point ];
      }
    }
    my $ret = $image->karyotype( $object, [ \%high ] ); 
    if( $ret ) {
      warn $ret;
      return;
    }
  }
  $panel->add_row(
    'Ensembl genes containing peptides in family '.$object->stable_id, $image->render
  );
  return 1;
}

sub stable_id {
  my( $panel, $object ) = @_;
  $panel->add_row( 'Family ID', "<p>@{[ $object->stable_id ]}</p>" );
  return 1;
}

sub consensus {
  my( $panel, $object ) = @_;
  $panel->add_row( 'Consensus annotation', "<p>@{[ $object->description ]}</p>" );
  return 1;
}

sub prediction {
  my( $panel, $object ) = @_;
  my $label  = shift || 'Prediction method';
  $panel->add_row( 'Prediction method', qq(
  <p>
    Protein families were generated using the MCL (Markov CLustering)
    package available at <a href="http://micans.org/mcl/">http://micans.org/mcl/</a>.
    The application of MCL to biological graphs was initially proposed by Enright A.J.,
    Van Dongen S. and Ouzounis C.A. (2002) "An efficient algorithm for large-scale 
    detection of protein families." Nucl. Acids. Res. 30, 1575-1584.
  </p>) );
}

sub alignments {
  my ($panel, $object ) = @_;
  my $ensembl_members   = $object->member_by_source("ENSEMBLPEP");
  my @all_pep_members;
  push @all_pep_members, @$ensembl_members;
  push @all_pep_members, @{$object->member_by_source('Uniprot/SPTREMBL')};
  push @all_pep_members, @{$object->member_by_source('Uniprot/SWISSPROT')};

  my $HTML = jalview_link_for( 'Ensembl', $ensembl_members, $object ) .
             jalview_link_for( '', \@all_pep_members, $object );
  if( $HTML ) {
    $HTML = "<table>$HTML</table>";
  }
  else {
    $HTML = "<p>No alignment has been produced for this family.</p>";
  }
  $panel->add_row( 'Multiple alignments', $HTML );
}

sub jalview_link_for {
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
  <tr>
    <td>Click to view multiple alignments of the $count $type members of this family.</td>
    <td>
      <applet archive="$BASE/jalview/jalview.jar"
        code="jalview.ButtonAlignApplet.class" width="100" height="35" style="border:0"
        alt = "[Java must be enabled to view alignments]">
      <param name="input" value="$BASE/$URL" />
      <param name="type" value="URL" />
      <param name=format value="FASTA" />
      <param name="fontsize" value="10" />
      <param name="Consensus" value="*" />
      <param name="srsServer" value="srs.sanger.ac.uk/srsbin/cgi-bin/" />
      <param name="database" value="ensemblpep" />
      <strong>Java must be enabled to view alignments</strong>
    </applet>
    </td>
  </tr>);
}

# General info table #########################################################

sub other_peptides {
  my ($panel, $object ) = @_;
  my %rows = (
    'UniProt/Swiss-Prot' => 'Uniprot/SWISSPROT',
    'UniProt/TrEMBL'     => 'Uniprot/SPTREMBL'
  ); 
  foreach my $key ( keys %rows ) {
    my $HTML = '<dl class="short_id_list">';
    my @data = map { $_->[0]->stable_id } @{$object->member_by_source( $rows{$key} )};
    my $URL_KEY = uc($rows{$key});
    foreach ( sort @data ) {
      $HTML .= '<dt>'.$object->get_ExtURL_link($_,$URL_KEY,$_).'</dt>';
    }
    $HTML .= '</dl>';
    $panel->add_row( $key , $HTML );
  }
}

sub ensembl_peptides {
  my ($panel, $object ) = @_;
  my $current_taxon = $object->taxonomy_id;
  my @taxa = @{ $object->taxa($object->Obj) };
  my @peptides;
  foreach my $species (sort {$a->binomial cmp $b->binomial} @taxa ){
    my $display_species = $species->binomial;
    (my $species_key = $display_species) =~ s/\s+/_/;
    my $id   = $species->ncbi_taxid;
    next if $id == $current_taxon;
    my $HTML = '<dl class="long_id_list">';
    my @data = map { $_->[0]->stable_id } @{ $object->source_taxon( 'ENSEMBLPEP', $id ) };
    next unless @data;
    foreach ( sort @data ) {
      $HTML .= sprintf '<dt><a href="/%s/protview?peptide=%s">%s</a>
        [<a href="/%s/contigview?peptide=%s">C</a>]</dt>', $species_key, $_, $_, $species_key, $_;
    }
    $HTML .= '</dl>';
    $panel->add_row( $display_species, $HTML );
  }
}

1;
