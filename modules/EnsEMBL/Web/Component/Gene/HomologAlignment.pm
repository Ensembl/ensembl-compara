package EnsEMBL::Web::Component::Gene::HomologAlignment;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use Bio::AlignIO;
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::Document::HTML::TwoCol;
use EnsEMBL::Web::Constants;
use POSIX;

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub caption {
  return undef;
}

sub content {
  my $self         = shift;
  my $cdb          = shift || $self->object->param('cdb') || 'compara';  
  my $object       = $self->object;
  my $species      = $object->species;
  my $species_defs = $object->species_defs;
  my $gene_id      = $object->stable_id;
  my $input        = $object->input;
  my $second_gene  = $object->param('g1');
  my $seq          = $object->param('seq');
  my $text_format  = $object->param('text_format');
  my $databases    = $object->database($cdb);
  my $ma           = $databases->get_MemberAdaptor;
  my $qm           = $ma->fetch_by_source_stable_id('ENSEMBLGENE', $gene_id);
  my ($homologies, $html, %skipped);
  
  eval {
    my $ha = $databases->get_HomologyAdaptor;
    $homologies = $ha->fetch_by_Member($qm);
  };
  
  my %desc_mapping = (
    'ortholog_one2one'          => '1 to 1 orthologue',
    'apparent_ortholog_one2one' => '1 to 1 orthologue (apparent)',
    'ortholog_one2many'         => '1 to many orthologue',
    'between_species_paralog'   => 'paralogue (between species)',
    'ortholog_many2many'        => 'many to many orthologue',
    'within_species_paralog'    => 'paralogue (within species)',
  );
  
  foreach my $homology (@{$homologies}) {
    my $sa;
    eval { $sa = $homology->get_SimpleAlign($seq eq 'cDNA' ? 'cdna' : undef); };
    
    if ($sa) {
      my $data = [];
      my $flag = !$second_gene;
      
      foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
        my ($member, $attribute) = @{$member_attribute};
        
        $flag = 1 if $member->stable_id eq $second_gene;
        
        my $peptide        = $member->{'_adaptor'}->db->get_MemberAdaptor->fetch_by_dbID($attribute->peptide_member_id);
        my $member_species = ucfirst $member->genome_db->name;
        my $location       = sprintf '%s:%d-%d', $member->chr_name, $member->chr_start, $member->chr_end;
        
        if (!$second_gene && $member_species ne $species && $object->param('species_' . lc $member_species) eq 'off') {
          $flag = 0;
          $skipped{$species_defs->species_label($member_species)}++;
          next;
        }
        
        if ($member->stable_id eq $gene_id) {
          push @$data, [
            $species_defs->get_config($member_species, 'SPECIES_SCIENTIFIC_NAME'),
            $member->stable_id,
            $peptide->stable_id,
            sprintf('%d aa', $peptide->seq_length),
            $location,
          ]; 
        } else {
          push @$data, [
            $species_defs->get_config($member_species, 'SPECIES_SCIENTIFIC_NAME'),
            sprintf('<a href="%s">%s</a>',
              $object->_url({ species => $member_species, type => 'Gene', action => 'Summary', g => $member->stable_id, r => undef }),
              $member->stable_id
            ),
            sprintf('<a href="%s">%s</a>',
              $object->_url({ species => $member_species, type => 'Transcript', action => 'ProteinSummary', peptide => $peptide->stable_id, __clear => 1 }),
              $peptide->stable_id
            ),
            sprintf('%d aa', $peptide->seq_length),
            sprintf('<a href="%s">%s</a>',
              $object->_url({ species => $member_species, type => 'Location', action => 'View', g => $member->stable_id, r => $location, t => undef }),
              $location
            )
          ];
        }
      }
      
      next unless $flag;
      
      my $homology_types = EnsEMBL::Web::Constants::HOMOLOGY_TYPES;
      my $homology_desc  = $homology_types->{$homology->{'_description'}} || $homology->{'_description'};
      
      next if $homology_desc eq 'between_species_paralog'; # filter out the between species paralogs
      
      my $homology_desc_mapped = $desc_mapping{$homology_desc} ? $desc_mapping{$homology_desc} : 
                                 $homology_desc ? $homology_desc : 'no description';

      $html .= "<h2>Ortholog type: $homology_desc_mapped</h2>";
      
      my $ss = EnsEMBL::Web::Document::SpreadSheet->new([
          { 'title' => 'Species',          'width' => '20%' },
          { 'title' => 'Gene ID',          'width' => '20%' },
          { 'title' => 'Peptide ID',       'width' => '20%' },
          { 'title' => 'Peptide length',   'width' => '20%' },
          { 'title' => 'Genomic location', 'width' => '20%' }
        ],
        $data
      );
      
      $html .= $ss->render;

      my $alignio = Bio::AlignIO->newFh(
        -fh     => IO::String->new(my $var),
        -format => $self->renderer_type($text_format)
      );
      
      print $alignio $sa;
      
      $html .= "<pre>$var</pre>";
    }
  }
  
  if (scalar keys %skipped) {
    my $count;
    $count += $_ for values %skipped;
    
    $html .= '<br />' . $self->_info(
      'Orthologues hidden by configuration',
      sprintf(
        '<p>%d orthologues not shown in the table above from the following species. Use the "<strong>Configure this page</strong>" on the left to show them.<ul><li>%s</li></ul></p>',
        $count,
        join "</li>\n<li>", map "$_ ($skipped{$_})", sort keys %skipped
      )
    );
  }
  
  return $html;
}        

sub renderer_type {
  my $self = shift;
  my $K = shift;
  my %T = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;
  return $T{$K} ? $K : EnsEMBL::Web::Constants::SIMPLEALIGN_DEFAULT;
}

1;

