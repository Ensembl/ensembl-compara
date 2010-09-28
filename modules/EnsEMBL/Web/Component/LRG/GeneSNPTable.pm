package EnsEMBL::Web::Component::LRG::GeneSNPTable;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use Bio::EnsEMBL::Registry;
use Data::Dumper;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::Proxy::Factory;
use EnsEMBL::Web::CoreObjects;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::RegObj;
use SiteDefs;

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


  #added for lrg BOF
  my $slice_orig = $object->Obj; 
  my $gene_s  =  shift @{$slice_orig->get_all_Genes}; #Bio::EnsEMBL::Gene
  my $stable_id = $object->stable_id;
  my $lrg = $slice_orig;
  
  my $input = new CGI; 
  my $db_connection = new EnsEMBL::Web::DBSQL::DBConnection($ENV{'ENSEMBL_SPECIES'}, $ENSEMBL_WEB_REGISTRY->species_defs) if $ENV{'ENSEMBL_SPECIES'} ne 'common';
 
  my $core_objects = new EnsEMBL::Web::CoreObjects($input, $db_connection, undef);
  my $factory = new EnsEMBL::Web::Proxy::Factory('Gene', {
    _input         => $input,
    _apache_handle => undef,
    _core_objects  => $core_objects,
    _databases     => $db_connection,
    _referer       => undef
  });

#  warn "GS: $gene_s
  my $newObj = new EnsEMBL::Web::Proxy::Object('Gene', $gene_s, $factory->__data);
  #added for lrg EOF

  my %var_tables;

  my $slice = $lrg->feature_Slice;
  my $all_snps = $slice->get_all_VariationFeatures;
  my $count_snps = scalar(@{$all_snps});
  warn "SNPS : ", join ' * ', $slice->name, $slice->start, $slice->end, $count_snps;
  
  warn "First: ", $all_snps->[0];

  my @transcripts = sort{ $a->stable_id cmp $b->stable_id } @{ $object->get_all_transcripts };
  
  my $I = 0;
  foreach my $transcript ( @transcripts ) {
 
      my $tsid = $transcript->stable_id;
      warn "TID: $tsid : $transcript";
      
      my $table_rows = $self->variationTable($transcript, $all_snps);
      my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px' } );

      $table->add_columns (
      { 'key' => 'ID', },
      { 'key' => 'snptype', 'title' => 'Type', },
      { 'key' => 'chr' , 'title' => 'Chr: bp',  },
      { 'key' => 'Alleles', 'align' => 'center' },
      { 'key' => 'Ambiguity', 'align' => 'center', },
      { 'key' => 'aachange', 'title' => 'Amino Acid', 'align' => 'center' },
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
    my( $self, $t, $snps ) = @_;


    my $cdna_coding_start = $t->Obj->cdna_coding_start;
    warn "SSNOS  : $snps \n";

    my @rows;
    foreach my $gs ( @$snps ) {
	warn "GS: $gs";
	my $transcript_variation  = $gs;
	my @validation =  @{ $gs->get_all_validation_states || [] };
#	if( $transcript_variation && $gs->[5] >= $tr_start-$extent && $gs->[4] <= $tr_end+$extent ) {
	my $url = $t->_url({'type' => 'Variation', 'action' =>'Summary', 'v' => @{[$gs->variation_name]}, 'vf' => @{[$gs->dbID]}, 'source' => @{[$gs->source]} });   
	my $row = {
	    'ID'        => qq(<a href="$url">@{[$gs->variation_name]}</a>),
	    'class'     => $gs->var_class(),
	    'Alleles'   => $gs->allele_string(),
	    'Ambiguity' => $gs->ambig_code(),
	    'status'    => (join( ', ',  @validation ) || "-"),
	    'chr' => 'LRG!',

	    'snptype'   => (join ", ", @{ $transcript_variation->consequence_type || []}), $transcript_variation->translation_start ? (
																       'aachange' => $transcript_variation->pep_allele_string,
																       'aacoord'   => $transcript_variation->translation_start.' ('.(($transcript_variation->cdna_start - $cdna_coding_start )%3+1).')'
																       ) : ( 'aachange' => '-', 'aacoord' => '-' ),
            'Source'      => (join ", ", @{$gs->[2]->get_all_sources ||[] } )|| "-",
	};    
	push (@rows, $row);
#	}
    }
    
    return \@rows;
}

sub configure_gene{

  my $object = shift;
  my $slice_orig = shift;

  my $res_get_transcript_slices = shift;

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

 my $transcript_slice =  $object->__data->{'slices'}{'transcripts'}[1];    #NOT OK 
 my $sub_slices       =  $object->__data->{'slices'}{'transcripts'}[2];   #OK



  #my ($count_snps, $snps, $context_count) = $object->getVariationsOnSlice( $transcript_slice, $sub_slices  );
  
  # added for lrg BOF
  my $all_snps = $slice_orig->get_all_VariationFeatures;
  my $count_snps = scalar(@{$all_snps});
  my $context_count = scalar(@{$all_snps});
  my $snps = [];
  #map {my $snp = $_->transfer($slice_orig);push @{$snps},[$snp->start,$snp->end,$snp]} @{$all_snps};
  map {push @{$snps},[$_->start,$_->end,$_]} @{$all_snps};
  # added for lrg EOF

 
  $object->store_TransformedTranscripts();        ## Stores in $transcript_object->__data->{'transformed'}{'exons'|'coding_start'|'coding_end'
  #$object->store_TransformedSNPS();               ## Stores in $transcript_object->__data->{'transformed'}{'snps'

## -- Map SNPs for the last SNP display --------------------------------- ##
  my $SNP_REL     = 5; ## relative length of snp to gap in bottom display...
  my $fake_length = -1; ## end of last drawn snp on bottom display...
  my $slice_trans = $transcript_slice;

#  print Dumper($slice_trans->start);

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

  my $valids = $object->valids;
  foreach my $trans_obj ( @{$object->get_all_transcripts} ) {
    
    $trans_obj->__data->{'transformed'}{'extent'} = $extent;
    $trans_obj->__data->{'transformed'}{'gene_snps'} =  \@snps2;

    #added for lrg BOF
    my $T = $trans_obj->stable_id;
    my $transformed_snps = {};

      foreach my $S ( @{$snps} ) {
         foreach( @{$S->[2]->get_all_TranscriptVariations||[]} ) {
	     next unless  $T eq $_->transcript->stable_id;
	     foreach my $type ( @{ $_->consequence_type || []} ) {
		 #next unless $valids->{'opt_'.lc($type)};
		 $transformed_snps->{ $S->[2]->dbID } = $_;
      
		 last;
	     }
         }
      }
   $trans_obj->__data->{'transformed'}{'snps'} = $transformed_snps;
   #added for lrg EOF   

  }

  return $object;
}



sub configure_lrg{
  my $object = shift;

  my $slice = $object->Obj->feature_Slice;

  warn "S: ", $slice->name;

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

  my $transcript_slice =  $object->__data->{'slices'}{'transcripts'}[1];    #NOT OK 
  my $sub_slices       =  $object->__data->{'slices'}{'transcripts'}[2];   #OK

  
  # added for lrg BOF
  my $all_snps = $slice->get_all_VariationFeatures;
  my $count_snps = scalar(@{$all_snps});
  warn "SNPS : $count_snps";

  my $context_count = scalar(@{$all_snps});

  my $snps = [];
  map {push @{$snps},[$_->start,$_->end,$_]} @{$all_snps};
  # added for lrg EOF

 
  $object->store_TransformedTranscripts();        ## Stores in $transcript_object->__data->{'transformed'}{'exons'|'coding_start'|'coding_end'
  #$object->store_TransformedSNPS();               ## Stores in $transcript_object->__data->{'transformed'}{'snps'

## -- Map SNPs for the last SNP display --------------------------------- ##
  my $SNP_REL     = 5; ## relative length of snp to gap in bottom display...
  my $fake_length = -1; ## end of last drawn snp on bottom display...
  my $slice_trans = $transcript_slice;

#  print Dumper($slice_trans->start);

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

  my $valids = $object->valids;
  foreach my $trans_obj ( @{$object->get_all_transcripts} ) {
    
    $trans_obj->__data->{'transformed'}{'extent'} = $extent;
    $trans_obj->__data->{'transformed'}{'gene_snps'} =  \@snps2;

    #added for lrg BOF
    my $T = $trans_obj->stable_id;
    my $transformed_snps = {};

      foreach my $S ( @{$snps} ) {
         foreach( @{$S->[2]->get_all_TranscriptVariations||[]} ) {
	     next unless  $T eq $_->transcript->stable_id;
	     foreach my $type ( @{ $_->consequence_type || []} ) {
		 #next unless $valids->{'opt_'.lc($type)};
		 $transformed_snps->{ $S->[2]->dbID } = $_;
      
		 last;
	     }
         }
      }
   $trans_obj->__data->{'transformed'}{'snps'} = $transformed_snps;
   #added for lrg EOF   

  }

  return $object;
}

1;


