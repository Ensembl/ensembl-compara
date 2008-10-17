package EnsEMBL::Web::Component::Gene::HomologAlignment;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::Document::HTML::TwoCol;

use POSIX;


#use Data::Dumper;
#$Data::Dumper::Maxdepth = 3;

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $gene = $object->Obj;
  my $input = $object->input;
  my $second_gene = $input->{'g1'}->[0];
  my $html = '';

  my $databases = $object->database('compara') ;
  my $ma = $databases->get_MemberAdaptor;
  my $qm    = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$gene->stable_id);
  my $homologies;
  eval {
    my $ha = $databases->get_HomologyAdaptor;
    $homologies = $ha->fetch_by_Member($qm);
  };

  my %desc_mapping= ('ortholog_one2one' => '1 to 1 orthologue', 'apparent_ortholog_one2one' => '1 to 1 orthologue (apparent)', 'ortholog_one2many' => '1 to many orthologue', 'between_species_paralog' => 'paralogue (between species)', 'ortholog_many2many' => 'many to many orthologue', 'within_species_paralog' => 'paralogue (within species)');

  foreach my $homology (@{$homologies}) {
    my $sa;
    eval { $sa = $homology->get_SimpleAlign( $object->param('seq') eq 'cDNA' ? 'cdna' : undef ); };
    if( $sa ) {
      my $DATA = [];
      my $FLAG = ! $second_gene;
      foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
        my ($member, $attribute) = @{$member_attribute};
        $FLAG = 1 if $member->stable_id eq $second_gene;
        my $peptide = $member->{'_adaptor'}->db->get_MemberAdaptor()->fetch_by_dbID( $attribute->peptide_member_id );
        my $species = $member->genome_db->name;
        (my $species2 = $species ) =~s/ /_/g;
        my $location = sprintf('%s:%d-%d',$member->chr_name, $member->chr_start, $member->chr_end);
        if ($member->stable_id eq $gene->stable_id) {
          push @$DATA, [
            $species,
            sprintf( $member->stable_id ),
            sprintf( $peptide->stable_id ),
            sprintf( '%d aa', $peptide->seq_length ),
            sprintf( $location),
          ]; 
        }
        else {
          push @$DATA, [
            $species,
            sprintf( '<a href="%s">%s</a>',
              $object->_url({'species'=>$species2,'type'=>'Gene','action'=>'Summary','g'=>$member->stable_id,'r'=>undef}),
              $member->stable_id
            ),
            sprintf( '<a href="%s">%s</a>',
              $object->_url({'species'=>$species2,'type'=>'Transcript','action'=>'ProteinSummary',
                'peptide'=>$peptide->stable_id,'__clear'=>1 }),
              $peptide->stable_id
            ),
            sprintf( '%d aa', $peptide->seq_length ),
            sprintf( '<a href="%s">%s</a>',
              $object->_url({'species'=>$species2,'type'=>'Location','action'=>'View',
                'g'=>$member->stable_id,'r'=>$location,'t'=>undef}),
              $location
            )
          ];
        }
      }
      next unless $FLAG;
      my $homology_types = $self->HOMOLOGY_TYPES;

      my $homology_desc= $homology_types->{$homology->{_description}} || $homology->{_description};

      # filter out the between species paralogs
      next if($homology_desc eq 'between_species_paralog');

      my $homology_desc_mapped= $desc_mapping{$homology_desc};
      $homology_desc_mapped= 'no description' unless (defined $homology_desc_mapped);
      $html .= sprintf '<h2>Ortholog type: %s</h2>',$homology_desc_mapped;

      my $ss = EnsEMBL::Web::Document::SpreadSheet->new(
        [ { 'title' => 'Species', 'width'=>'20%' },
          { 'title' => 'Gene ID', 'width'=>'20%' },
          { 'title' => 'Peptide ID', 'width'=>'20%' },
          { 'title' => 'Peptide length', 'width'=>'20%' },
          { 'title' => 'Genomic location', 'width'=>'20%' } ],
        $DATA
      );
      $html .= $ss->render;

      my $alignio = Bio::AlignIO->newFh(
        -fh   => IO::String->new(my $var),
        -format => $self->renderer_type($object->param('text_format'))
      );
      print $alignio $sa;
      $html .= qq(<pre>$var</pre>);
    }
  }
  return $html;
}        



1;

