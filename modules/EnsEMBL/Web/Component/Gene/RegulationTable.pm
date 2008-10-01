package EnsEMBL::Web::Component::Gene::RegulationTable;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  my $self = shift;
  my $object = $self->object; 
  my $gene_id = $object->Obj->stable_id;
  my $cap = 'Regulatory Regions linked to '. $gene_id;

 return $cap;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my @factors =  @{$object->reg_factors};
  my @reg_feats = @{$object->reg_features};
  my $object_slice = $object->Obj->feature_Slice;
  my $offset = $object_slice->start -1;
  my $object_strand = $object_slice->strand;
  my $str = "positive";
  if ($object_strand  <1 ){$str = "negative"; }
 
  ## return if no regulatory factors ##
  my $size = @factors;
  my $size2 = @reg_feats; 
  
  if ($size < 1 && $size2 <1) {
    my $html = "<p><strong>There are no regulatory factors linked to this gene</strong></p>";
    return $html;
  }
 
  ## If there are factors to display ##
  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' =>'1em 0px'});
  $table->add_columns(
   {'key' => 'feature', 'title' => 'Reg. region', 'width' => '22%', 'align' => 'left'},
   {'key' => 'analysis', 'title' => 'Analysis', 'width' => '16%', 'align' => 'left'},
   {'key' => 'type', 'title' => 'Type', 'width' => '18%', 'align' => 'left'},
   {'key' => 'location', 'title' => 'Location', 'width' => '20%', 'align' => 'left'},
   {'key' => 'length', 'title' => 'Length', 'width' => '4%', 'align' => 'left'},
   {'key' => 'seq', 'title' => 'Sequence ('. $str .' strand)', 'width' => '20%', 'align' => 'left'},
  ); 

  ## First process Ensembl Funcgen Reg. Factors ##
  foreach my $feature_obj (@reg_feats){
   my $row = {};
   my ($position, $feature_link, $length, $type);

   my $seq_name = $feature_obj->slice->seq_region_name;
   $position = $object->thousandify($feature_obj->start) ."-" . $object->thousandify($feature_obj->end) ;
   $position = qq(<a href="/@{[$object->species]}/Location/Summary?db=core;r=$seq_name:).$feature_obj->start . qq(-).$feature_obj->end .qq(">$seq_name:$position</a>);

   $length = ($feature_obj->end - $feature_obj->start) +1;
   $length = $object->thousandify( $length ). "bp";
 
   my $feature_name = $feature_obj->stable_id;
    $type = $feature_obj->feature_type->name;
   $feature_link = $feature_name ? qq(<a href="/@{[$object->species]}/featureview?id=$feature_name;type=RegulatoryFactor;name=$type">$feature_name</a>) : "unknown";
 
   $type = $feature_obj->feature_type->name;

   $feature_obj->{'strand'} = $object_strand;
   my $seq = $feature_obj->seq();
   $seq =~ s/([\.\w]{60})/$1<br \/>/g;
  
   my $analysis  = qq(<a rel="external" href="http://www.ensembl.org/@{[$object->species]}/helpview?se=1&kw=contigview#fg_regulatory_features">Ensembl Regulatory Build</a>);
   $row = {
     'location'  => $position,
     'length'    => $length,
     'seq'       => qq(<span class="sequence">$seq</span>),
     'feature'    => $feature_link,
     'type'   => $type,
     'analysis'  => $analysis
   };

   $table->add_row($row);
  }

  ## Now process external factors ##
  foreach my $feature_obj (@factors){
   my $row = {};
   my ($position, $seq, $feature_link, $feature, $desc, $length);
   $feature = $feature_obj->feature_type->name;
   my $seq_name = $feature_obj->slice->seq_region_name;
    
   $position = $object->thousandify($feature_obj->start) ."-" . $object->thousandify($feature_obj->end) ;
   $position = qq(<a href="/@{[$object->species]}/Location/Summary?db=core;r=$seq_name:).$feature_obj->start . qq(-).$feature_obj->end .qq(">$seq_name:$position</a>);   

   my $region = $seq_name .":" .$feature_obj->start ."-".$feature_obj->end;
   my $feature_name = $feature_obj->display_label;
   #my $analysis = $feature_obj->analysis->logic_name;
   $feature_link = $feature_name ? qq(<a href="/@{[$object->species]}/featureview?r=$region;id=$feature_name;type=RegulatoryFactor;name=$feature">$feature_name</a>) : "unknown";

   $desc = $feature_obj->analysis->description;
   if ($feature  =~/cisRED\sSearch\sRegion/){$desc =~s/cisRED\smotif\ssearch/cisRED Search Region/;}
    # hack to get around problem with source data file for release 50
   if ($feature_name  =~/cra.*/){
         $desc =~s/cisRED\smotif\ssearch/cisRED atomic motifs/;
         $feature  = "cisRED atomic motifs";
   }
     
   if  ($desc =~/\(http/){ $desc =~ s/\(http/#http/;} 
   elsif($desc =~/\(www/){ $desc =~ s/www/#http:\/\/www/;} 
   $desc =~ s/\(#/#/;
   $desc =~s/\)//;
   my @temp = split(/#/, $desc);
   my $description = qq(<a rel="external" href="$temp[1]">).$temp[0]."</a>"; 
 
   $seq = $feature_obj->seq();
   $seq =~ s/([\.\w]{60})/$1<br \/>/g;
   $length = $object->thousandify( length ($seq) ). "bp";

   $row = {
     'location'  => $position,
     'length'    => $length,
     'seq'       => qq(<span class="sequence">$seq</span>),
     'feature'   => $feature_link,
     'type'      => $feature,
     'analysis'  => $description
   };

   $table->add_row($row);
 }

 
return $table->render;
}

1;
