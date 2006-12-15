package EnsEMBL::Web::Document::DropDown::Menu::Export;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;

our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-exportas',
    'image_width' => 58,
    'alt'         => 'Export data'
  );
  my $location = $self->{'location'};
  my $exportURL = sprintf "/%s/exportview?l=%s:%s-%s", $self->{'species'}, $location->seq_region_name, $location->seq_region_start, $location->seq_region_end;
  my $martURL   = sprintf "/biomart/martview?stage_initialised=start&stage_initialised=region&stage_initialised=filter&stage=output&species=%s&chromosome_lots=1&chromosome_name=%s&chromosome_lots_fromfilt=%s&chromosome_lots_tofilt=%s&chromosome_lots_fromval=%s&chromosome_lots_toval=%s", $self->{'species'}, $location->seq_region_name, 'chrom_start', 'chrom_end', int( $location->seq_region_start), int( $location->seq_region_end );
  my $martFlag = 0; #  $self->{'config'}->{'species_defs'}->ENSEMBL_NO_MART == 1 ? 0 : 1;
  my $exports = { embl   => { text  => 'Flat file',
                           url   => "$exportURL;format=embl;action=format",
                           avail => 1 },

               fasta  => { text  => 'FASTA',
                           url   => "$exportURL;format=fasta;action=format",
                           avail => 1 },

               gene   => { text  => 'Ensembl Gene List',
                           url   => "$martURL&focus=gene",
                           avail => $martFlag },

               sanger => { text  => 'Vega Gene List',
                           url   => "$martURL&focus=vega_gene",
                           avail => $martFlag && $self->{'config'}->is_available_artefact( 'databases ENSEMBL_VEGA' ) },


               estgene=> { text  => 'EST Gene List',
                           url   => "$martURL&focus=est_gene",
                           avail => $martFlag && $self->{'config'}->is_available_artefact( 'databases ENSEMBL_OTHERFEATURES' ) },

               snp    => { text  => 'SNP List',
                           url   => "$martURL&focus=snp",
                           avail => $martFlag && $self->{'config'}->is_available_artefact( 'databases ENSEMBL_VARIATION' ) },
  };
  foreach( qw(pdf svg postscript) ) {
    $self->add_checkbox( "format_$_", "Include @{[uc($_)]} links" );
  }
#  foreach( keys %{$exports} ){
#    if( $exports->{$_}->{avail} ){
#      $self->add_link( $exports->{$_}->{'text'}, $exports->{$_}->{'url'} );
#    }
#  }
  return $self;
}

1;
