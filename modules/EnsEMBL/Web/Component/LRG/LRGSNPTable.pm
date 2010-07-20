#$Id$
package EnsEMBL::Web::Component::LRG::LRGSNPTable;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::LRG);
use base qw(EnsEMBL::Web::Component::LRG EnsEMBL::Web::Component::Gene::GeneSNPTable);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return;
}


sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $lrg         = $self->configure($object->param('context') || 'FULL', $object->get_imageconfig('lrgsnpview_transcript'));
  my @transcripts = sort { $a->stable_id cmp $b->stable_id } @{$lrg->get_all_transcripts};
  my $lrg_slice   = $lrg->Obj->feature_Slice;
  my $tables      = {};
  
  foreach my $transcript (@transcripts) {
    my $table_rows = $self->variation_table($transcript, $lrg_slice);
    
    $tables->{$transcript->stable_id} = $self->make_table($table_rows) if $table_rows; 
  }

  return $self->render_content($tables);
}

sub variation_table {
  my ($self, $transcript, $lrg_slice) = @_;
  
  my $rows = shift->SUPER::variation_table($transcript);
  
  if ($rows) {
    my $i = 0;
    $rows->[$i++]->{'HGVS'} = $self->get_hgvs($_->[0], $transcript->Obj, $lrg_slice) || '-' for @{$transcript->__data->{'transformed'}{'gene_snps'}};
  }
  
  return $rows;
}

sub configure_lrg{
  my $object = shift;

#  my $context      = $object->param( 'context' ) || 100;
  my $context      = $object->param( 'context' ) || 'FULL';
  my $extent       = $context eq 'FULL' ? 1000 : $context;

  my $master_config = $object->get_imageconfig( "lrgsnpview_transcript" );
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

  my @snps2 = map {
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

sub get_hgvs {
  my ($self, $snp, $transcript, $lrg_slice) = @_;
  
  my @hgvs  = values %{$snp->get_all_hgvs_notations($transcript, 'c')};
  push @hgvs, values %{$snp->get_all_hgvs_notations($lrg_slice, 'g', $snp->seq_region_name)};
  
  s/ENS(...)?[TG]\d+\://g for @hgvs;
  
  return join ', ', @hgvs;
}
1;
