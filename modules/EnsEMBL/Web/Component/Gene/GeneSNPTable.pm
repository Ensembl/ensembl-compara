package EnsEMBL::Web::Component::Gene::GeneSNPTable;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return;
}


sub content {
  my $self = shift;
  my $object = $self->object;
  my $gene = configure_gene($object);
  my %var_tables;

  my @transcripts = sort{ $a->stable_id cmp $b->stable_id } @{ $gene->get_all_transcripts };
  my $I = 0;
  foreach my $transcript ( @transcripts ) {
    my $tsid = $transcript->stable_id;
    my $table_rows = variationTable($transcript);    
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px' } );

    $table->add_columns (
      { 'key' => 'ID', },
      { 'key' => 'snptype', 'title' => 'Type', },
      { 'key' => 'chr' , 'title' => 'Chr: bp',  },
      { 'key' => 'Alleles', 'align' => 'center' },
      { 'key' => 'Ambiguity', 'align' => 'center', },
      { 'key' => 'aachange', 'title' => 'AA', 'align' => 'center' },
      { 'key' => 'aacoord',  'title' => 'AA co-ordinate', 'align' => 'center' },
      { 'key' => 'class', 'title' => 'Class', 'align' => 'center' },
      { 'key' => 'Source', },
      { 'key' => 'status', 'title' => 'Validation', 'align' => 'center' }, 
   );
 
    if ($table_rows){
      foreach my $row (@$table_rows){
        $table->add_row($row);
      }  
      $var_tables{$tsid} = $table->render;
    }  
  }

  my $html;
  foreach (keys %var_tables){
  $html .= "<p><h2>Variations in $_: </h2><p> $var_tables{$_}";
  }
  return $html;
}

sub variationTable {
  my( $object ) = @_;
  my %snps = %{$object->__data->{'transformed'}{'snps'}||[]};
  my @gene_snps = @{$object->__data->{'transformed'}{'gene_snps'}||[]};
  my $tr_start = $object->__data->{'transformed'}{'start'};
  my $tr_end   = $object->__data->{'transformed'}{'end'};
  my $extent   = $object->__data->{'transformed'}{'extent'};
  my $cdna_coding_start = $object->Obj->cdna_coding_start;
  return unless %snps;

  my @rows;
  foreach my $gs ( @gene_snps ) {
    my $raw_id = $gs->[2]->dbID;
    my $transcript_variation  = $snps{$raw_id};
    my @validation =  @{ $gs->[2]->get_all_validation_states || [] };
    if( $transcript_variation && $gs->[5] >= $tr_start-$extent && $gs->[4] <= $tr_end+$extent ) {
      my $url = $object->_url({'type' => 'Variation', 'action' =>'Summary', 'v' => @{[$gs->[2]->variation_name]}, 'vf' => @{[$gs->[2]->dbID]}, 'source' => @{[$gs->[2]->source]} });   
      my $row = {
        'ID'        => qq(<a href="$url">@{[$gs->[2]->variation_name]}</a>),
        'class'     => $gs->[2]->var_class() eq 'in-del' ? ( $gs->[4] > $gs->[5] ? 'insertion' : 'deletion' ) : $gs->[2]->var_class(),
        'Alleles'   => $gs->[2]->allele_string(),
        'Ambiguity' => $gs->[2]->ambig_code(),
        'status'    => (join( ', ',  @validation ) || "-"),
        'chr'       => $gs->[3].": ".
                        ($gs->[4]==$gs->[5] ? $gs->[4] :  "$gs->[4]-$gs->[5]"),
        'snptype'   => (join ", ", @{ $transcript_variation->consequence_type || []}), $transcript_variation->translation_start ? (
        'aachange' => $transcript_variation->pep_allele_string,
        'aacoord'   => $transcript_variation->translation_start.' ('.(($transcript_variation->cdna_start - $cdna_coding_start )%3+1).')'
        ) : ( 'aachange' => '-', 'aacoord' => '-' ),
        'Source'      => (join ", ", @{$gs->[2]->get_all_sources ||[] } )|| "-",
      };

      push (@rows, $row);
    }
  }

  return \@rows;
}

sub configure_gene{
  my $object = shift;

  my $context      = $object->param( 'context' ) || 100;
  my $extent       = $context eq 'FULL' ? 1000 : $context;

  my $master_config = $object->get_imageconfig( "genesnpview_transcript" );
  $master_config->set_parameters( {
    'image_width' =>  800,
    'container_width' => 100,
    'slice_number' => '1|1',
    'context'      => $context,
  });


  $object->get_gene_slices( ## Written...
    $master_config,
    [ 'context',     'normal', '100%'  ],
    [ 'gene',        'normal', '33%'  ],
    [ 'transcripts', 'munged', $extent ]
  );

  my $transcript_slice = $object->__data->{'slices'}{'transcripts'}[1];
  my $sub_slices       =  $object->__data->{'slices'}{'transcripts'}[2];
  my ($count_snps, $snps, $context_count) = $object->getVariationsOnSlice( $transcript_slice, $sub_slices  );


  $object->store_TransformedTranscripts();        ## Stores in $transcript_object->__data->{'transformed'}{'exons'|'coding_start'|'coding_end'
  $object->store_TransformedSNPS();               ## Stores in $transcript_object->__data->{'transformed'}{'snps'

## -- Map SNPs for the last SNP display --------------------------------- ##
  my $SNP_REL     = 5; ## relative length of snp to gap in bottom display...
  my $fake_length = -1; ## end of last drawn snp on bottom display...
  my $slice_trans = $transcript_slice;

  my @snps2;
    @snps2 = map {
    $fake_length+=$SNP_REL+1;
      [ $fake_length-$SNP_REL+1 ,$fake_length,$_->[2], $slice_trans->seq_region_name,
        $slice_trans->strand > 0 ?
          ( $slice_trans->start + $_->[2]->start - 1,
            $slice_trans->start + $_->[2]->end   - 1 ) :
          ( $slice_trans->end - $_->[2]->end     + 1,
            $slice_trans->end - $_->[2]->start   + 1 )
      ]
  } sort { $a->[0] <=> $b->[0] } @{ $snps };

  foreach my $trans_obj ( @{$object->get_all_transcripts} ) {
    $trans_obj->__data->{'transformed'}{'extent'} = $extent;
    $trans_obj->__data->{'transformed'}{'gene_snps'} = \@snps2;
  }

  return $object;
}

1;


