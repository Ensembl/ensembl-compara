package EnsEMBL::Web::Component::Gene::FamilyAlignments;

### Displays embedded JalView link for a protein family

use strict;
use warnings;
no warnings "uninitialized";

use CGI qw(escapeHTML);

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;
  my $html;

  my $fam_obj = $object->create_family($object->param('family'));
  my $ensembl_members   = $object->member_by_source($fam_obj, 'ENSEMBLPEP');
  my @all_pep_members;
  push @all_pep_members, @$ensembl_members;
  push @all_pep_members, @{$object->member_by_source($fam_obj, 'Uniprot/SPTREMBL')};
  push @all_pep_members, @{$object->member_by_source($fam_obj, 'Uniprot/SWISSPROT')};

  $html .= $self->_embed_jalview('Ensembl', $ensembl_members);
  $html .= $self->_embed_jalview('', \@all_pep_members);
  return $html;
}

sub _embed_jalview {
  my( $self, $type, $refs ) = @_;
  my $object   = $self->object;
  my $count    = @$refs;
  my $outcount = 0;
  return unless $count;
  
  my $BASE = $object->species_defs->ENSEMBL_BASE_URL;
  my $file = new EnsEMBL::Web::TmpFile::Text(extension => 'fa', prefix => 'family_alignment');
  my $URL  = $file->URL;

  foreach my $member_attribute (@$refs) {
    my ($member, $attribute) = @$member_attribute;
    my $align;
    eval { $align = $attribute->alignment_string($member); };
    unless ($@) {
      if($attribute->alignment_string($member)) {
        $file->print(">".$member->stable_id."\n");
        $file->print($attribute->alignment_string($member)."\n");;
        $outcount++;
      }
    }
  }
  
  return unless $outcount;

  return qq(
  <p class="space-below">$count $type members of this family:
    <applet archive="$BASE/jalview/jalview.jar"
        code="jalview.ButtonAlignApplet.class" width="100" height="35" style="border:0"
        alt = "[Java must be enabled to view alignments]">
      <param name="input" value="$BASE$URL" />
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
