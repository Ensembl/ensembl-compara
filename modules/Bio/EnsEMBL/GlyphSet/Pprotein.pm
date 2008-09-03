package Bio::EnsEMBL::GlyphSet::Pprotein;
use strict;
use vars qw(@ISA $SPECIES_DEFS);
use Bio::EnsEMBL::GlyphSet;
#use EnsEMBL::Web::GeneTrans::support;

@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
    my ($self) = @_;
    my $db;
    my $protein = $self->{'container'};	
    my $Config  = $self->{'config'};
    my $pep_splice = $protein->{'image_splice'};

    my $prot_id = $protein->stable_id;
    my $gene_adapt = $protein->adaptor->db->get_GeneAdaptor();
    my $gene = ( $gene_adapt ? 
                 $gene_adapt->fetch_by_translation_stable_id($prot_id) : 
                 undef );
    my $type = ( $gene ?
                 $gene->analysis->logic_name :
                 '' );
    $type = lc( $type );

    my $authority = lc($self->species_defs->AUTHORITY);

    ## hack to fix flybase db type definition
    my $db = $protein->adaptor->{'dbc'}->{_dbname} =~ /_(vega|otherfeatures|cdna)_/ ? $1 : 'core';

    my $x = 0;
    my $y = 0;
    my $h = 4; 
    my $flip = 0;
    my @colours  = ($Config->get('Pprotein','col1'), $Config->get('Pprotein','col2'));
    my $start_phase = 1;
    if ($pep_splice){
      for my $exon_offset (sort { $a <=> $b } keys %$pep_splice){
        my $colour = $colours[$flip];
        my $exon_id = $pep_splice->{$exon_offset}{'exon'};
        next unless $exon_id;
        my $exonview_link = '';
        if( $prot_id ){
          $exonview_link = sprintf( "/%s/exonview?peptide=%s;exon=%s;db=%s", 
          $self->{container}{web_species}, $prot_id, $exon_id, $db );
        }

        my $rect = $self->Rect({
          'x'        => $x,
          'y'        => $y,
          'width'    => $exon_offset - $x,
          'height'   => $h,
          'colour'   => $colour,
          'zmenu' => {
          'caption' => "Splice Information",
          "00:Exon: $exon_id" => $exonview_link,
          "01:Start Phase: $start_phase" => "",
          '02:End Phase: '. ($pep_splice->{$exon_offset}{'phase'} +1) => "",
          '03:Length: '.($exon_offset - $x)  => "", },
        });
        $self->push($rect);
        $x = $exon_offset ;
        $start_phase = ($pep_splice->{$exon_offset}{'phase'} +1) ;
        $flip = 1-$flip;
      }
    } else {
      my $rect = $self->Rect({
        'x'        => 0,
        'y'        => $y,
        'width'    => $protein->length(),
        'height'   => $h,
                'colour'   => $colours[0],
                });

        $self->push($rect);
    }
}
1;


