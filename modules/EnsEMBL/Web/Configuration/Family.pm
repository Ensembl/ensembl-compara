package EnsEMBL::Web::Configuration::Family;

use strict;
use EnsEMBL::Web::Document::Panel::SpreadSheet;
use EnsEMBL::Web::Document::Panel::Information;
use EnsEMBL::Web::Configuration;

our @ISA = qw(EnsEMBL::Web::Configuration);

sub familyview {
  my $self   = shift;
  my $stable_id = $self->{'object'}->stable_id;
  my $species   = $self->{'object'}->species;
  my @common = (
    'object'  => $self->{object},
    'params'  => { 'family' => $stable_id }
  );
  my $panel1 = new EnsEMBL::Web::Document::Panel::Information(
    'code'    => "info$self->{flag}",
    'caption' => "Ensembl Family $stable_id",
    'object'  => $self->{'object'}
  );
  $panel1->add_components(qw(
    stable_id  EnsEMBL::Web::Component::Family::stable_id
    consensus  EnsEMBL::Web::Component::Family::consensus
    prediction EnsEMBL::Web::Component::Family::prediction
    alignments EnsEMBL::Web::Component::Family::alignments
    karyotype_image EnsEMBL::Web::Component::Family::karyotype_image
  ));
  $self->initialize_zmenu_javascript;
  $self->{page}->set_title( "Ensembl protein family $stable_id" );
  $self->{page}->content->add_panel( $panel1 );

  my $panel2 = new EnsEMBL::Web::Document::Panel::SpreadSheet(
    'code'    => "loc$self->{flag}",
    'caption' => "Location of Ensembl genes containing family $stable_id",
    'cacheable' => 'yes',
    'cache_type' => 'familytable',
    'cache_filename' => "gene-$species-$stable_id.table",
    'status'  => 'panel_table',
    @common,
    'null_data' => '<p>There are no Ensembl genes with this family</p>'
  );
  $panel2->add_components( qw(genes EnsEMBL::Web::Component::Domain::spreadsheet_geneTable) );
  $self->{page}->content->add_panel( $panel2 );

  my $panel3 = new EnsEMBL::Web::Document::Panel::Information(
    'code'    => "peptides$self->{flag}",
    'caption' => "Other peptides in Family $stable_id",
    'cacheable' => 'yes',
    'cache_type' => 'familytable',
    'cache_filename' => "other-$species-$stable_id.table",
    'status'  => 'panel_other',
    @common
  );
  $panel3->add_components(qw(
    name     EnsEMBL::Web::Component::Family::other_peptides
  ));
  $self->{page}->content->add_panel( $panel3 );

  my $panel4 = new EnsEMBL::Web::Document::Panel::Information(
    'code'    => "peptides$self->{flag}",
    'caption' => "Ensembl peptides in Family $stable_id",
    'cacheable' => 'yes',
    'cache_type' => 'familytable',
    'cache_filename' => "ensembl-$species-$stable_id.table",
    'status'  => 'panel_ensembl',
    @common
  );
  $panel4->add_components(qw(
    name     EnsEMBL::Web::Component::Family::ensembl_peptides
  ));
  $self->{page}->content->add_panel( $panel4 );

}

sub context_menu {
  my $self = shift;
  $self->{page}->menu->add_block( "family$self->{flag}", 'bulleted',
                                  $self->{object}->stable_id );
  $self->{page}->menu->add_entry( "family$self->{flag}", 'text' => "Family info.",
                                  'href' => "/@{[$self->{object}->species]}/familyview?family=".$self->{object}->stable_id );
  $self->add_entry( "family$self->{flag}", 'icon' => '/img/biomarticon.gif' ,
                    'text' => 'Gene List', 'title' => 'BioMart: Gene list',
        'href' => "/@{[$self->{object}->species]}/martlink?type=family;family_id=".$self->{object}->stable_id );

#  $self->add_entry( "family$self->{flag}", 'icon' => '/img/biomarticon.gif' ,
#                    'text' => 'Peptide sequences (FASTA)', 'title' => 'BioMart: Peptide sequences FASTA',
#        'href' => "/@{[$self->{object}->species]}/martlink?type=familyseq;family_id=".$self->{object}->stable_id );
  $self->{page}->menu->add_entry( "family$self->{flag}", 'text' => 'Export alignments',
    'href' => sprintf( '/%s/alignview?class=Family;family_stable_id=%s', $self->{object}->species, $self->{object}->stable_id ),
    'options' => [
       map { { 'href'=> sprintf( '/%s/alignview?class=Family;family_stable_id=%s;format=%s',
         $self->{object}->species, $self->{object}->stable_id, lc($_) ), 'text' => "Export as $_ format" } }
       qw(FASTA MSF ClustalW Selex Pfam Mega Nexus Phylip PSI)
    ]
  );
}

1;
